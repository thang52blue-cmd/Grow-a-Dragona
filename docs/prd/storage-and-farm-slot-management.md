# Storage and Farm Slot Management

> Spec captured (translated/organized) from a direct user message, 2026-07-17. This is the
> "Specify" step (`AGENTS.md` §Agent workflow) for a non-trivial feature: three new transactions
> (one replacing an existing unused one), a world-presence prompt change, and two new client UI
> panels.

## Core rules

- When the farm is full, the player can still hatch eggs normally. The new dragon is
  automatically sent to **Storage**.
- Storage has no capacity limit and costs nothing.
- A dragon in Storage does not produce eggs and does not contribute to Element Synergy (Synergy
  itself, backlog item 8, is not yet implemented — nothing to change there today).
- When a Farm Slot is open, the player walks to that slot and picks a Dragon from Storage to place
  there.

## Storage display

A list/grid of cards, each showing: Rarity, Element, Baby/Adult status, and a duplicate count.
Sortable by Rarity or newest.

## Opening Storage

- A **Collection** button on the HUD — view-only, browsing the collection.
- Direct interaction with a Farm Slot — to actually place a Dragon, the player must walk to a
  physical slot and interact with it. The HUD button never places a dragon by itself.

## Placing a Dragon from Storage into a Farm Slot

1. Player walks to an **empty** slot. The slot shows a **"Place Dragon"** prompt.
2. Triggering it opens the **Storage Picker**: a grid of cards for every dragon currently in
   Storage (name/label, Rarity, Element, Baby-or-Adult, growth progress if Baby). Only
   Storage dragons appear — a dragon already on another slot is never shown here (no
   double-placement).
3. Picking a card: removes that dragon from Storage, assigns it to the chosen slot, spawns its
   world model there, creates/shows its Nest if it's an Adult, and refreshes
   production/synergy. The picker closes automatically. No drag-and-drop — walk to slot → tap →
   choose dragon.

## When the slot already has a Dragon

The prompt reads **"Manage Dragon"** instead. Triggering it offers two choices:

- **Send to Storage** — the dragon returns to Storage (not deleted); its world model
  disappears; the slot becomes empty; it stops counting toward production/Synergy.
- **Swap Dragon** — opens the Storage Picker again; picking a new dragon atomically returns the
  old one to Storage and places the new one in the same slot in one operation — no state where a
  dragon is briefly lost or duplicated.

## Worked example

Slot 1: Fire Adult. Slot 2: empty. Player walks to Slot 2 → Place Dragon → picks Water Baby →
Water Baby appears on Slot 2. Player then walks to Slot 1 → Manage Dragon → Send to Storage → Fire
Dragon returns to Storage, Slot 1 becomes empty, only the Water dragon is left on the farm.

## Implementation notes (engineering decisions closing gaps the spec didn't cover)

- **"Storage" needs no new schema field.** A dragon with `DragonRecord.AssignedSlotId == nil` is
  already exactly "in Storage" — this is the same state auto-placement overflow already produces
  (backlog item 14 / `adr/ADR-005`). No `adr/` entry needed for this feature: no save-schema field
  changes, and no *existing* transaction's request/response shape changes either (only a new,
  previously-uncalled transaction's *validation rule* is loosened — see below).
- **`AssignProducerTransaction` had zero client callers** (confirmed by search) — it was reserved
  for exactly this "future Storage/swap flow" per its own code comments. Rather than keep two
  overlapping ways to put a dragon in a slot, it's renamed/generalized to
  `PlaceDragonTransaction`/`PlaceDragonRules`: the `GrowthStage == "Adult"` gate is dropped (Baby
  placement is required by this spec), and `ProductionStartedAt` is only set when the placed
  dragon is actually an Adult (a Baby sitting in a slot produces nothing until it's fed to Adult,
  same as the existing auto-placement path).
- **"Must Collect before Send-to-Storage/Swap" is a hard server rule, not just UX.** Tracing
  `ProductionRules.Advance`: a slot with `AssignedDragonUID = nil` but `UncollectedEggCount > 0`
  is a dead state no existing code path recovers from — those eggs become permanently
  uncollectable (silent value loss), since Collect's own Stage would resolve the dragon lookup to
  `DragonNotFound` instead of finding the (already-gone) producer. `SendToStorageRules`/
  `SwapDragonRules` therefore reject with a new `NestNotEmpty` code whenever the slot's
  `UncollectedEggCount > 0`, forcing a Collect first.
- **Atomicity for Swap** falls out of the existing transaction architecture for free: every
  Rules module's `Commit` writes the whole staged `NewDragons`/`NewFarmSlots` table in one shot
  (the project's "one Atomic Write Set" rule), so `SwapDragonRules` moving both dragons in a
  single `Stage`/`Commit` call is naturally atomic — no separate locking needed.
- **New `TransactionType` entries:** `PlaceDragon` (renamed from `AssignProducer`, same numeric
  id `31` — nothing depended on the name since it was never called), `SendToStorage = 32`,
  `SwapDragon = 33`. **New `TransactionCode`:** `NestNotEmpty = 49`.
- **World-presence:** Farm Slot tiles (`FarmPlotSpawner`) get a `ProximityPrompt` for the first
  time — currently bare, untagged `Part`s. `ActionText` toggles between `"Place Dragon"` and
  `"Manage Dragon"` based on `FarmSlot.AssignedDragonUID`, mirroring `NestSpawner.UpdatePileCount`'s
  existing "refresh on every call" pattern. No existing code path destroys a Nest when a slot's
  dragon leaves it (`AssignProducer`'s old branch only ever handled the assign-into-empty-slot
  direction) — the new post-commit handlers add the missing `NestSpawner.Despawn` calls.
- **Client UI:** a new `src/client/Storage/` module family — a shared card-grid renderer (reused by
  both the Storage Picker, which is selectable, and the HUD Collection viewer, which is read-only)
  plus a small two-button Manage-Dragon menu. All driven off the same `ProfileUpdated` snapshot's
  `dragons` map the existing Inventory panel already reads (no new remote/read needed to list
  Storage contents) — the Picker/Viewer just filter to `AssignedSlotId == nil`.
- **Dragon "name"**: same placeholder convention as the hatch reveal feature
  (`docs/prd/hatch-reveal-sequence.md`) — no unique per-dragon name field exists in this MVP, so
  cards label by `{Rarity} {Element} Dragon`.
