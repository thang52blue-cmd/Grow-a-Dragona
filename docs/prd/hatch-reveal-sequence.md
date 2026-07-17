# Hatch Reveal Sequence

> Spec captured verbatim from two direct user messages, 2026-07-17. This is the "Specify" step
> (`AGENTS.md` §Agent workflow) for the hatch reveal cinematic — a non-trivial client-only
> presentation feature layered on top of the already-shipped `ClaimHatchTransaction`
> (backlog item 4). Per `docs/prd/core-game-loop.md`: **"Reveal animation is presentation only; it
> must not determine RNG or player data."** Nothing in this doc changes the save schema or the
> transaction contract — `ClaimHatchTransaction`'s existing result (`DragonId`, `Rarity`,
> `AssignedSlotId`) already carries everything this sequence needs.

## Universal 4-beat structure

Every hatching egg, regardless of tier or the rarity it resolves to, plays the same four beats:
shake in place → crack with a color-hinting flash → dragon reveal → a short, non-blocking summary.
What changes between rarities is how much each beat is dressed up — never the underlying
structure.

## Camera behavior

The moment a player's egg reaches its auto-claim moment, camera and movement control are briefly
locked for a directed shot: the camera pushes in toward the egg instead of leaving it at whatever
angle the player happened to be standing at. Control returns to the player immediately once the
reveal beat finishes. How dramatic the push-in gets scales with rarity.

## Escalation by rarity

Every tier gets its own distinct treatment, not just a bigger version of the same effect. Numbers
below are first-pass timing targets, meant to be tuned once the team can see them in motion.

| Rarity | Camera | Crack | Reveal | Total (skip) | Roar | Screen flash |
|---|---|---|---|---|---|---|
| Common | Light zoom, almost static | 0.5s | 1.0s | ~1.8s | No | No |
| Rare | Slightly tighter zoom, small push-in | 0.5s | 1.2s | ~2.0s | No | No |
| Epic | Tighter zoom, brief hitch right on the crack frame | 0.7s | 1.3s | ~2.3s | No | No |
| Legendary | Full directed zoom, slow-motion hitch on the crack | 0.9s | 1.5s | ~2.7s | Yes, short | No |
| Mythic | Full cinematic zoom, longest slow-motion hitch, reveal held close | 1.1s | 1.8s | ~3.2s | Yes, longer | Yes, brief rainbow flash + vignette pulse |

## Sound identity by rarity

Building on a general satisfying-pop direction, each rarity adds its own distinct layer rather
than simply playing louder:

| Rarity | Shake | Crack | Reveal |
|---|---|---|---|
| Common | Soft, quick rattle | Clean crack-pop | Bright pop + light sparkle chime |
| Rare | Soft rattle, slightly richer tone | Crack-pop + a short blue-tinted chime tail | Pop + brighter sparkle chime, small reverb tail |
| Epic | Rattle with a faint building hum underneath | Crack-pop + a rising chime | Pop + a harmonic layer and soft shimmer, medium reverb tail |
| Legendary | Deeper, slower rattle, hum grows audibly | Crack-pop + rising chime + a brief brass stab | Pop + full harmonic swell + a short dragon roar layered right after it |
| Mythic | Deepest, slowest rattle, hum swells into a shimmering drone | Crack-pop + rising chime + brass stab + a prismatic shimmer sweep | Pop + full swelling harmonic/choir touch + a longer, more resonant roar + a bright sparkle-cascade tail that lingers briefly after everything else stops |

## Particles and light by rarity

| Rarity | Effect |
|---|---|
| Common | Small white/grey sparkle burst on reveal |
| Rare | Blue sparkle burst, slightly larger |
| Epic | Purple sparkle burst plus a faint radial shockwave ring |
| Legendary | Gold sparkle burst, radial shockwave ring, and brief golden light rays from the dragon |
| Mythic | Full rainbow sparkle cascade, radial shockwave ring, prismatic light rays, and the brief screen-wide color flash noted above |

## Haptic feedback

Mobile devices only reliably distinguish a few impact strengths, so haptics deliberately bucket
into three levels instead of five — there's no meaningful device-level difference between an Epic
and a Rare buzz, so splitting them further would be a distinction the player's phone can't
actually render.

- Common: light pulse
- Rare and Epic: medium pulse
- Legendary and Mythic: strong pulse, timed with the roar

## After the reveal — placement and confirmation

The new dragon is automatically placed into the next open slot on the player's farm plot — the
player never has to manually choose where it goes right after a hatch. If every slot is already
full, the dragon goes to storage instead, exactly like any dragon that doesn't fit on the plot. A
small summary card (dragon name, rarity, element) appears for about 2 seconds and fades on its own,
or dismisses immediately if the player taps anywhere — it never blocks or requires an action to
proceed.

## Implementation notes (not from the user spec — engineering decisions made to close gaps)

- **Auto-placement already exists.** `ClaimHatchRules.Stage` (backlog item 14 / `adr/ADR-005`)
  already auto-assigns a freshly-hatched dragon to the first open Farm Slot, or leaves
  `AssignedSlotId = nil` (overflow-to-storage) if every slot is full. This spec's "after the
  reveal" placement rule needed no new server-side work.
- **"Dragon name."** No player-naming feature exists in this MVP (confirmed against
  `memory-bank/backlog.md` and `Types.DragonRecord`). The summary card's "name" is a generated
  label in the same `"{Rarity} {Element} Dragon"` style already used elsewhere (e.g.
  `DragonSpawner`'s Nursery billboards), not a stored/unique name. [Inference] this reads as a
  reasonable placeholder until a real naming feature exists, not a claim that this is what the
  original design intended by "name."
- **All of this is Runtime-only presentation** (AGENTS.md data classification): nothing here is
  persisted or added to the save schema. `ClaimHatchTransaction`'s result already exposes
  `DragonId`/`Rarity`/`AssignedSlotId`; `Element` and `GrowthStage` are read client-side off the
  now-replicated dragon world model's existing attributes (`DragonSpawner` already sets
  `Rarity`/`Element`/`GrowthStage` attributes on every spawned model), so no transaction-contract
  change was needed to add a field.
  Per-rarity dressing values (camera timings, colors, sound asset ids, particle tier, haptic
  bucket, toast suffix) live in `src/shared/Data/HatchVisualConfig.json`, following the existing
  `src/shared/Data/*.json` convention for tunables, with a thin `src/shared/Domain/
  HatchVisualConfig.luau` accessor + spec proving every rarity has an entry and the escalation is
  monotonic (Common's numbers are never larger/more elaborate than Mythic's).
- **"Slow-motion hitch"** is implemented as a brief pause + eased resume on the crack-beat tween
  (a client-local timing effect), not an actual `workspace`-wide time-scale change — it never
  affects other players or server state.
- **Haptics** use `HapticService:SetMotor`, gated by `HapticService:IsVibrationSupported` — this
  repo cannot verify real device feedback in Studio, so the live-verification pass only confirms
  the calls fire without erroring, not that a physical phone actually buzzes.
- **Sound assets** are free Creator Store audio inserted via the Roblox Studio MCP's
  `search_asset`/`insert_asset`, staged under `ReplicatedStorage.HatchSounds`, per the user's
  explicit go-ahead to source free assets when something is missing. 10 templates were inserted
  (`EggRattle`, `MagicHum`, `EggCrack`, `MagicChime`, `BrassHit`, `ShimmerSweep`, `RevealPop`,
  `SparkleTwinkle`, `MagicalSwell`, `DragonRoar`) and are reused/layered across rarities with
  per-cue volume/pitch/delay rather than one unique clip per table cell — see
  `src/shared/Data/HatchVisualConfig.json`'s `shakeSounds`/`crackSounds`/`revealSounds` arrays.
  **[Unverified]** these were matched by Creator Store keyword search only — nothing in this
  toolchain can actually play/listen to an audio preview, so fit and quality are not confirmed by
  ear. `EggRattle` ("Locking Wrench 25"), `EggCrack` ("Wood Snap Splinter 2"), and `DragonRoar`
  ("Dragon Roar") are strong semantic matches; `MagicChime` ("Wind Chime"), `MagicalSwell`
  ("Ethereal Drone"), `RevealPop`/`SparkleTwinkle` (gem-pickup SFX repurposed), and `ShimmerSweep`
  ("Effect Cue 6", a generic APM cue) are lower-confidence placeholders a sound pass should
  audition and likely replace before shipping.
