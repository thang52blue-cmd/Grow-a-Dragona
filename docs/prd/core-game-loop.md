# Core Game Loop Implementation Plan

> User-supplied plan doc, pasted into chat 2026-07-16. Saved verbatim (formatting only) as the
> reference spec for backlog items 5 (Feed Dragon), 6 (Assign Producer / Collect Nest), and 7
> (Sell Production Egg). See `memory-bank/backlog.md` for DoDs and `adr/` for schema decisions this
> doc requires before implementation — do not assume this doc alone authorizes a save-schema change
> (see AGENTS.md's gated actions).

## Goal

Complete the playable MVP loop:

```text
Buy Hatching Egg
→ Hatch instantly
→ Receive Baby Dragon
→ Feed Baby Dragon 4 times
→ Transform into Adult Dragon
→ Adult produces Production Eggs automatically
→ Collect Production Eggs
→ Sell Production Eggs for Gold
→ Buy another Hatching Egg
```

Already completed:

- Buy Hatching Egg with Gold.
- Hatching Egg inventory.
- Instant Hatch flow.
- Server-side RNG result.
- Add hatched Dragon to the player collection.
- Basic Inventory UI for Eggs and owned Dragons.

## Core Design Rules

### Hatching Eggs

- Hatching Eggs are bought with Gold.
- Pressing `Hatch` consumes one Hatching Egg immediately.
- The server rolls the Dragon result immediately.
- Reveal animation is presentation only; it must not determine RNG or player data.
- The received Dragon is created as a `Baby`.

### Baby Dragons

- A Baby Dragon cannot produce Production Eggs.
- Baby Dragons do not grow over time.
- There is no offline growth, growth timer, cooldown, decay, or penalty.
- A Baby becomes an Adult only after being fed exactly `4` times.
- The player must approach the Baby Dragon and manually use a Feed prompt.
- Each Feed consumes one matching Food item.
- The Baby changes visually after each Feed.
- Feed #4 triggers the full Adult transformation.

### Adult Dragons

- Adult Dragons can be assigned to a farm production slot.
- Once assigned, they automatically produce one Production Egg every configured interval.
- Initial prototype interval: `180 seconds / 3 minutes`.
- Each Adult Dragon has one associated Nest.
- A Nest stores up to `12` uncollected Production Eggs.
- At `12` eggs, production pauses.
- After collecting at least one egg, production resumes.
- Eggs are never deleted because a Nest is full.

### Production Egg Presentation

- Show a maximum of `5` physical egg models inside a Nest.
- Above five eggs, show a count label such as `x8` or `x12`.
- At capacity, show a distinct soft pulsing glow around the Nest.
- The full-Nest glow means "collect eggs"; it must not look like a generic loading/waiting
  indicator.

## Dragon State Machine

```text
Hatching Egg
→ Baby_0
→ Baby_1
→ Baby_2
→ Baby_3
→ Adult_Unassigned
→ Adult_Producing
```

- `Baby_0` is the state immediately after hatch.
- Each successful Feed advances exactly one Baby stage.
- The fourth Feed changes `Baby_3` to `Adult_Unassigned`.
- Only Adult Dragons can be assigned to production slots.
- Removing an Adult from the farm changes it back to `Adult_Unassigned`.

## Persistent Data Model

### Dragon Instance

```lua
DragonInstance = {
    DragonUID = "unique-guid",
    DragonTypeId = 1001,

    Rarity = "Common",
    Element = "Fire",

    GrowthStage = "Baby_0", -- Baby_0, Baby_1, Baby_2, Baby_3, Adult
    FeedCount = 0,           -- 0 to 4

    AssignedSlotId = nil,
    CreatedAt = unixTimestamp,
}
```

Do not store growth timestamps, passive growth timers, or offline growth progress.

### Food Inventory

```lua
FoodInventory = {
    FireFood = 0,
    WaterFood = 0,
    EarthFood = 0,
    LightFood = 0,
    DarkFood = 0,
}
```

Food must match the Dragon element and be validated server-side.

### Farm Slot and Nest State

```lua
FarmSlot = {
    SlotId = 1,
    AssignedDragonUID = nil,

    ProductionStartedAt = nil,
    UncollectedEggCount = 0,
    IsProductionPaused = false,
}
```

- `UncollectedEggCount` is always between `0` and `12`.
- `IsProductionPaused` is true only when the Nest is full.
- Production is calculated on the server from timestamps, not from a client timer.

### Production Egg Inventory

```lua
ProductionEggInventory = {
    Normal = 0,
    Mini = 0,
    Heavy = 0,
    Giant = 0,
    Golden = 0,
}
```

```text
Nest Egg → Collected Production Egg Inventory → Sold → Gold
```

- Only Nest Eggs may be raided later.
- Collected Eggs are safe in inventory.
- Hatching Eggs must never enter this flow.

## Server Services and Transactions

### DragonService

Responsibilities:

- Create Dragon instances after Hatch.
- Store and retrieve owned Dragons.
- Validate ownership and state.
- Assign or remove Adult Dragons from farm slots.

### FeedDragonTransaction

Client input:

```lua
{ DragonUID = "..." }
```

The client must not send Food type, Feed count, or the target Growth Stage.

Server flow:

```text
1. Lock player transaction.
2. Load Dragon by DragonUID.
3. Verify ownership and Baby state.
4. Resolve required Food from Dragon.Element.
5. Verify the player owns one matching Food.
6. Consume one Food.
7. Add one FeedCount and advance GrowthStage.
8. On Feed #4, set Dragon to Adult.
9. Save atomically.
10. Notify client to update the Dragon visual.
11. Unlock transaction.
```

Reject invalid Dragon IDs, non-owned Dragons, Adult Dragons, no Food, wrong Food, and duplicate
requests.

### AssignProducerTransaction

Client input:

```lua
{ DragonUID = "...", SlotId = 1 }
```

Server validation:

- Player owns the Dragon.
- Dragon is Adult.
- Slot belongs to the player and is unlocked.
- Slot is empty.
- Dragon is not already assigned to another slot.

On success, set the Dragon and Slot assignment, initialize production time, and spawn the Adult
Dragon plus its Nest model.

### ProductionService

Responsibilities:

- Calculate completed production cycles from timestamps.
- Add Production Eggs until the Nest reaches capacity.
- Pause at 12 eggs.
- Resume after collection brings the count below 12.
- Update Nest models, count label, and full-Nest effect.

Suggested calculation:

```text
elapsedTime = CurrentTime - ProductionStartedAt
completedCycles = floor(elapsedTime / ProductionInterval)

availableCapacity = 12 - UncollectedEggCount
eggsToCreate = min(completedCycles, availableCapacity)
```

After production:

```text
UncollectedEggCount += eggsToCreate
ProductionStartedAt += eggsToCreate * ProductionInterval

if UncollectedEggCount >= 12 then
    IsProductionPaused = true
end
```

When a Nest is paused, do not bank excess elapsed cycles. Collection should reset the next
production cycle from the collection time.

### CollectNestTransaction

For MVP, collect all Eggs from a selected Nest.

Server flow:

```text
1. Lock player transaction.
2. Validate player ownership of the Slot.
3. Reject if the Nest is empty.
4. Resolve produced Egg variants.
5. Add Eggs to ProductionEggInventory.
6. Set Nest count to zero.
7. Clear pause state and reset ProductionStartedAt.
8. Save atomically.
9. Update Nest UI and models.
10. Unlock transaction.
```

For the first prototype, all collected Eggs may be `Normal`; variant rolling can remain
config-driven and be added afterward.

### SellProductionEggTransaction

Client input:

```lua
{ EggVariant = "Normal", Quantity = 5 }
```

Server flow:

```text
1. Validate quantity and inventory ownership.
2. Read variant sell value from config.
3. Remove Production Eggs.
4. Add calculated Gold.
5. Save atomically.
6. Update Gold and inventory UI.
```

## Runtime World Interaction

### Baby Dragon

- Spawn Baby Dragons in a designated Baby Area / Nursery.
- Attach a Feed interaction prompt.
- If the player lacks Food, keep the prompt visible and show `Need [Food Name]`.
- The interaction sends only `DragonUID` to the server.
- Update Baby visuals after each successful Feed.
- On Feed #4, play Adult transformation feedback and update the model.

### Adult Dragon and Nest

- Spawn the Adult Dragon only when assigned to a valid Farm Slot.
- Spawn its Nest with it.
- Nest has a Collect interaction prompt.

| Nest count | Presentation |
|---:|---|
| 0 | Empty Nest |
| 1–5 | Render the matching number of Egg models |
| 6–12 | Render 5 Egg models and an `xN` label |
| 12 | Full-Nest pulsing glow and `x12` label |

## Implementation Order

### Phase A — Update Hatch Result

- Keep current Buy Egg and Hatch systems.
- Ensure each newly hatched Dragon starts with `GrowthStage = "Baby_0"`, `FeedCount = 0`, and no
  assigned slot.

### Phase B — Baby Dragon World Presence

- Create a temporary Nursery/Baby Area.
- Spawn Baby Dragon models there after Hatch.
- Add the Feed prompt interaction.
- Keep persistent Dragon data separate from runtime models.

### Phase C — Feeding and Transformation

- Implement `FeedDragonTransaction`.
- Implement Food inventory and a temporary Food test source.
- Implement four Feed stages and the Adult transform.
- Persist Feed count and Growth Stage.

### Phase D — Farm Assignment

- Add unlocked production slots.
- Allow only Adult Dragons to be assigned.
- Spawn the Adult and Nest on assignment.
- Prevent duplicate assignment.

### Phase E — Production and Nest

- Implement timestamp-based Egg production.
- Add 12-Egg capacity and pause/resume behavior.
- Implement maximum 5 physical Egg models, count label, and full-Nest glow.

### Phase F — Collection and Selling

- Implement Collect Nest transaction.
- Move Nest Eggs to Production Egg Inventory.
- Implement selling for Gold.
- Verify earned Gold works with the existing Buy Egg flow.

## Acceptance Tests

### Hatch and Growth

- Hatch consumes exactly one Hatching Egg and creates one Baby Dragon.
- Baby starts with `FeedCount = 0`.
- Each Feed consumes exactly one correct Food.
- Wrong Food, no Food, duplicated Feed requests, and feeding an Adult are rejected.
- Feed count never exceeds 4.
- The fourth Feed transforms the Dragon exactly once.
- Rejoin preserves Baby stage, Feed count, and Adult state.

### Farm and Production

- Only Adult Dragons can be assigned to Farm Slots.
- One Dragon cannot occupy two Slots.
- One completed production cycle creates one Egg.
- Production continues while older Eggs remain uncollected.
- Production pauses exactly at 12 Eggs; no Eggs are lost.
- Collection resumes production.
- No Nest renders more than 5 physical Egg models.
- Full-Nest effect appears only at capacity.

### Economy

- Production Eggs and Hatching Eggs remain separate inventories.
- Selling removes the correct quantity and adds server-calculated Gold.
- Earned Gold can buy another Hatching Egg.

## Open Design Item

The updated GDD should explicitly confirm the Baby Dragon location and capacity.

Recommended MVP rule:

```text
Baby Dragons live in a separate Nursery/Baby Area.
They do not occupy Adult Production Slots.
Only Adult Dragons can be assigned to Farm Slots and produce Eggs.
```

This prevents a player from being blocked from hatching and feeding new Dragons when all adult
production slots are occupied.
