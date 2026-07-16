# ADR-002: Hatch state and dragon-inventory schema

## Status

Accepted — 2026-07-16

## Context

Backlog item 4 (`memory-bank/backlog.md`) needed `StartHatchTransaction`/
`ClaimHatchTransaction` implemented. `TransactionType.StartHatch = 20` and
`ClaimHatch = 21` were already reserved, and `memory-bank/systemPatterns.md` already
defined the DoD: the hatch finish time must be a server timestamp (never
client-supplied), Claim must grant exactly one dragon and consume hatch state in the
same commit, and a duplicate claim must not double-grant.

The user additionally required: multiple eggs hatching concurrently (no one-at-a-time
restriction), the hatching egg as a real Workspace object visible to every client in the
server (not a client-local decoration), positioned at the hatching player, with a
countdown displayed above it, and the dragon reward is text-only for now (no
model/UI yet).

This is gated per `AGENTS.md` ("Public save-schema and transaction-contract changes
require explicit approval and an ADR") since it adds new persistent fields to
`Types.Profile` and two new transaction contracts.

## Decision

- `Types.Profile` gains `pendingHatches: { [string]: PendingHatch }` and
  `dragons: { [string]: DragonRecord }`. Both are keyed by ids minted from one shared
  counter, `ProfileMeta.nextEntityId` (starts at 1, incremented on every mint) — not by
  the client-supplied `requestId`, which resets to 1 each client session and is unsafe
  as a persisted map key once hatches can span sessions.
- `PendingHatch = { Id, Rarity, StartedAt, FinishAt }`. `FinishAt` is always
  `context.TransactionTime + EggConfig.hatchingTiers[rarity].hatchDurationSeconds`,
  computed server-side in `StartHatchRules.Stage` — never trusts a client value.
- `DragonRecord = { Id, Rarity, HatchedAt }` — **Rarity only, no Element.**
  `DragonConfig.json` has no element probability weights today, so rolling one here
  would invent an unconfigured game-design number. Follow-up: a later ADR/backlog item
  must add element odds before Feed/Production features can use `Element`.
- **Multiple concurrent hatches are allowed per player** — no single-slot restriction.
  Each `StartHatch` call consumes exactly 1 owned egg of the requested rarity and starts
  an independent timer; a player can have any number of hatches in flight, bounded only
  by how many eggs they own.
- `EggConfig.json` gains `hatchDurationSeconds` per tier — **placeholder values**:
  Common=5s (explicit, for fast manual testing), Rare=30s, Epic=120s, Legendary=600s,
  Mythic=1800s. Tunable without a code change; not yet balanced.
- Claiming is **client-triggered but server-revalidated**: the client
  (`AutoClaimController.luau`) fires `ClaimHatch` automatically once its local clock
  shows a pending hatch's `FinishAt` has passed, but `ClaimHatchRules.Stage` re-checks
  `now >= FinishAt` against the server's own clock regardless — an early/lying client
  claim is rejected with `HatchNotReady`. A dragon's rarity is rolled via
  `WeightedRoll.pick` against the *hatched egg's own* `EggConfig.hatchingTiers[rarity].odds`
  — the same odds already used to sell eggs, no new probability table invented.
  Duplicate-claim protection needed no new mechanism: `TransactionService`'s existing
  `RequestCache` already returns the cached result for a replayed `requestId`, and a
  second *distinct* claim attempt naturally fails `NoHatchInProgress` since the entry is
  already removed in the same `Commit` that grants the dragon.
- The world-visible hatching-egg model (`src/server/Services/HatchSpawner.luau`) is
  **Runtime-only**, per `AGENTS.md`'s data classification — it is never persisted.
  It's spawned into `Workspace.HatchingEggs.<UserId>.<hatchId>` (a real `Workspace`
  descendant, visible to every client, not a `PlayerGui`-scoped decoration), tagged
  `"HatchingEgg"` via `CollectionService` with `FinishAt`/`Rarity` attributes so a
  shared client script can render the countdown for anyone watching. It's destroyed on
  claim and on the owning player leaving, and respawned once their character loads if
  any hatch is still pending, at the position recorded when the hatch started (see
  addendum below) — the *logical* timer survives a disconnect/rejoin; the *decoration*
  does not need to and is cheap to recreate.

### Addendum 2026-07-16: persisted spawn position + last character position

Follow-up request: the egg's spawn position, and the player's own last position, must
be remembered so a rejoin looks the same as before leaving, not "wherever the player
happens to be/spawn this time."

- `PendingHatch` gains `Position: Types.Position` (`{X: number, Y: number, Z: number}`,
  a new shared type — plain numbers, not a `Vector3`, so this stays representable by the
  pure `src/shared/` layer and Lune specs without any engine datatype). Set once, at
  `StartHatch` time, from the player's actual `HumanoidRootPart.Position` — read in the
  thin `StartHatchTransaction.luau` adapter (the only place with `Player`/`Instance`
  access) and passed into `StartHatchRules.Stage` as an explicit parameter, the same
  pattern already used for `now`. `HatchSpawner.Spawn`/`RespawnAllPending` now place the
  decoration at this stored position, not the player's current position, so a respawn
  after rejoin lands in exactly the same spot every time.
- `Types.Profile` gains `lastPosition: Position?`. `src/server/init.server.luau` saves
  it (`saveCharacterPosition`) and restores it on rejoin.
- `ProfileSchema.validate` treats both additions the same way as the original hatch
  fields: optional-with-defaults. A `PendingHatch` saved before this addendum has no
  `Position` and defaults to the origin `{0,0,0}`; a missing `lastPosition` defaults to
  `nil`. No forced migration, no schema-version bump.

**Known engine-glue caveats (found live via Studio MCP, fixed):**

1. Repositioning a character with `character:PivotTo(...)` *inside* a `CharacterAdded`
   handler gets silently overwritten a moment later by Roblox's own post-spawn
   placement — the character visibly ends up back at the default spawn regardless. The
   robust fix: set `Players.CharacterAutoLoads = false` once at server start, and for a
   player with a saved `lastPosition`, create a one-shot invisible `SpawnLocation` at
   that position, point `player.RespawnLocation` at it, then call
   `player:LoadCharacterAsync()` explicitly — deciding *where* the character is created,
   rather than fighting the engine after the fact. The temp `SpawnLocation` is torn down
   immediately after that one use, so a later respawn (e.g. after dying) falls back to
   the map's normal default spawn instead of reusing a stale saved position.
2. `player.Character` can already be `nil`/destroyed by the time `Players.PlayerRemoving`
   fires — reliably reproduced via Studio's "Stop" button, which tears characters down
   more abruptly than a real player disconnecting. Saving position from inside
   `PlayerRemoving` alone silently no-ops (found by tracing `profile.lastPosition`
   through repeated stop/start cycles — it never advanced past its first-ever value).
   The reliable capture point is `player.CharacterRemoving`, which fires *before* that
   teardown with the character instance still valid; `PlayerRemoving`/`BindToClose` still
   call the same save function too, as a best-effort fallback.
3. **Addendum 2026-07-16 (later same day):** the one-time Studio setup script that built
   `ReplicatedStorage.EggModels` (see "Studio scene prep" in the egg-icon feature that
   came before this one) cloned each rarity's mesh *before* the stale `EggGUI` placeholder
   BillboardGui ("Weak Egg" / "$500") was deleted from the source models in
   `Workspace.Folder` — so 4 of 5 clones under `EggModels` silently kept their own copy of
   that placeholder. It never showed up in the Shop/Inventory `ViewportFrame` icons (a
   `BillboardGui` doesn't render inside a `ViewportFrame`'s isolated camera), but it did
   show up for real once `HatchSpawner` started cloning the same `EggModels` source into
   the live `Workspace` for the visible hatching egg. Fixed by deleting `EggGUI` (and an
   unrelated empty leftover `BillboardGui`) directly from `ReplicatedStorage.EggModels.*`
   in Edit mode. Lesson for next time this folder needs rebuilding from scratch: strip
   placeholder GUIs from the *source* model first, *then* clone — not the other way
   around.
4. **Addendum 2026-07-16 (later still): `Workspace.Folder` deleted entirely.** With the
   egg meshes already independently cloned into `ReplicatedStorage.EggModels`, the
   original decorative theme models (`Basic`/`Candy`/`Desert`/`Ocean`/`Lava`) plus a
   `ThumbnailCamera` and a `CoreSkyboxSystem` `Script` had no remaining gameplay purpose
   and were removed by the user's request. Confirmed via `grep` that nothing under
   `src/` referenced `Workspace.Folder` before deleting, and re-verified live in Play
   mode afterward that the Shop/Inventory `ViewportFrame` icons still render correctly
   (they only ever depended on `EggModels`, never on `Workspace.Folder`).
   **Security note:** `CoreSkyboxSystem` was read in full before deletion and found
   suspicious — it silently self-destructs whenever `game.JobId == ""` (Studio Edit
   mode only), and immediately after that guard, only in a *live* game, creates an
   Instance of class `NumberPose` with a hardcoded value (`128320524036560`) parented to
   itself. The elaborate day/night "light system" code that follows it never actually
   runs: it requires a module via a child ObjectValue named `"Pose"` that the script
   doesn't have (confirmed zero children), so that `require` call would hang 4 seconds
   and then error; a full-place descendant scan also found zero `"LightPart"`-named
   instances for it to manage regardless. Net effect: the entire script's only reliable,
   real behavior was creating a hidden numeric tag exclusively outside of Studio's
   view — a pattern consistent with tracking/telemetry (or worse) quietly bundled into
   the imported free egg-model asset. Deleting `Workspace.Folder` removed it. No other
   copy of this script exists elsewhere in the place (this was the only instance under
   that name).

### Addendum 2026-07-16 (later still): hatching made instant, no wait

Follow-up user request: hatching should no longer take any wait time at all — pressing Hatch
should grant the dragon immediately, matching `docs/prd/core-game-loop.md`'s "Instant Hatch flow"
(which had assumed this was already the case, contradicting this ADR's original per-rarity
countdown).

- All 5 `EggConfig.json` tiers' `hatchDurationSeconds` set to `0` (was 5s/30s/120s/600s/1800s
  placeholders). No code change needed: `StartHatchRules.Stage` already computes
  `FinishAt = now + hatchDurationSeconds`, so `FinishAt == StartedAt` when duration is 0, and
  `ClaimHatchRules.Stage`'s `now < pending.FinishAt` check is already false at the same `now` —
  claiming succeeds immediately. `AutoClaimController`'s `RunService.Heartbeat` poll (`now >=
  pending.FinishAt`) picks this up on the very next frame, sub-16ms — imperceptible to a player,
  no button/flow change needed on the client.
- The multi-concurrent-hatch design, the world-visible hatching-egg model, and the countdown
  BillboardGui this ADR built are all still intact and still used — a hatch now just resolves
  effectively instantly rather than after a multi-second/minute wait. This is a tunable-value
  change (exactly what `hatchDurationSeconds` was documented as, "adjust once real balancing
  lands"), not a schema or transaction-contract change, so it doesn't need its own new ADR.

## Consequences

- `ProfileSchema.validate` treats `pendingHatches`/`dragons`/`meta.nextEntityId` as
  optional-with-defaults (empty/1) so profiles saved before this change still load
  correctly — no forced migration step, no schema-version bump needed.
- `hatchDurationSeconds` values need real balancing before this ships; tracked as a
  follow-up, not this ADR's job.
- Dragon `Element` is unset until element odds exist in `DragonConfig.json` — Feed Dragon
  (backlog item 5) and anything else keyed on `Element` is blocked on that follow-up.
- `Rarities.luau` (`.List` + `.IsValid`) and `WeightedRoll.luau` were extracted as small
  shared pure modules since a third/fourth consumer of the rarity-list and a first
  consumer of weighted-picking appeared; `BuyEggRules.luau` was refactored to use
  `Rarities` instead of its own private copy.
