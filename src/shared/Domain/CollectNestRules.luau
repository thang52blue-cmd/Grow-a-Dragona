-- Pure Validate/Stage/Commit rules for CollectNestTransaction (backlog item 6). No engine
-- globals or IO (AGENTS.md hard rule); see adr/ADR-004-farm-slot-and-nest-schema.md for the
-- schema this relies on. The client sends `SlotId` only (docs/prd/core-game-loop.md) -- the
-- number of Eggs produced is always computed server-side via ProductionRules from timestamps.
local Types = require("../Types/Types")
local TransactionCode = require("./TransactionCode")
local ProductionRules = require("./ProductionRules")

local CollectNestRules = {}

export type StagedCollectNest = {
	SlotId: number,
	EggsCollected: number,
	NewFarmSlots: { [number]: Types.FarmSlot },
	NewProductionEggInventory: Types.ProductionEggInventory,
}

-- Validate: read-only, payload shape only. Slot existence/emptiness is checked in Stage against
-- the live profile.
function CollectNestRules.Validate(payload: unknown): (boolean, number?)
	if type(payload) ~= "table" then
		return false, TransactionCode.InvalidRequest
	end
	local rawPayload = payload :: { [string]: any }

	if type(rawPayload.SlotId) ~= "number" or rawPayload.SlotId % 1 ~= 0 then
		return false, TransactionCode.InvalidRequest
	end

	return true, nil
end

-- Stage: computes the full write set as new values, never mutating `profile`. First brings the
-- slot current via ProductionRules.Advance (a slot can accumulate multiple completed cycles
-- between transactions -- collection must never miss eggs that finished producing since the last
-- write), then moves every uncollected Egg into ProductionEggInventory in one shot. For the first
-- prototype all collected Eggs are the `Normal` variant (docs/prd/core-game-loop.md explicitly
-- defers variant rolling) -- see adr/ADR-004-farm-slot-and-nest-schema.md.
function CollectNestRules.Stage(
	productionConfig: Types.ProductionConfig,
	profile: Types.Profile,
	payload: { [string]: any },
	now: number
): (boolean, StagedCollectNest?, number?)
	local slotId = payload.SlotId :: number

	local slot = profile.farmSlots[slotId]
	if not slot then
		return false, nil, TransactionCode.SlotNotFound
	end

	local advanced = ProductionRules.Advance(slot, now, productionConfig)
	if advanced.UncollectedEggCount <= 0 then
		return false, nil, TransactionCode.NestEmpty
	end

	local eggsCollected = advanced.UncollectedEggCount

	local newFarmSlots = table.clone(profile.farmSlots)
	newFarmSlots[slotId] = {
		SlotId = slotId,
		AssignedDragonUID = advanced.AssignedDragonUID,
		ProductionStartedAt = now,
		UncollectedEggCount = 0,
		IsProductionPaused = false,
	}

	local newProductionEggInventory = table.clone(profile.productionEggInventory)
	newProductionEggInventory.Normal += eggsCollected

	return true,
		{
			SlotId = slotId,
			EggsCollected = eggsCollected,
			NewFarmSlots = newFarmSlots,
			NewProductionEggInventory = newProductionEggInventory,
		},
		nil
end

-- Commit: the only step allowed to mutate `profile`. Clears the Nest and grants the Eggs in the
-- same shot so a collect can never empty the Nest without also crediting the inventory (or vice
-- versa); a second collect attempt on the same (now-empty, freshly-timestamped) slot correctly
-- finds `NestEmpty`.
function CollectNestRules.Commit(profile: Types.Profile, staged: StagedCollectNest): { [string]: any }
	profile.farmSlots = staged.NewFarmSlots
	profile.productionEggInventory = staged.NewProductionEggInventory

	return {
		SlotId = staged.SlotId,
		EggsCollected = staged.EggsCollected,
		Variant = "Normal",
	}
end

return CollectNestRules
