-- Pure Validate/Stage/Commit rules for CollectNestTransaction (backlog item 6). No engine
-- globals or IO (AGENTS.md hard rule); see adr/ADR-004-farm-slot-and-nest-schema.md for the
-- schema this relies on and adr/ADR-006-production-egg-rarity-inventory.md for the variant-roll
-- addition. The client sends `SlotId` only (docs/prd/core-game-loop.md) -- the number of Eggs
-- produced is always computed server-side via ProductionRules from timestamps, and which
-- variant each one becomes is always rolled server-side too (`variantRollValues`, one per
-- possible egg -- see ClaimHatchRules' identical externally-supplied-rollValue precedent).
local Types = require("../Types/Types")
local TransactionCode = require("./TransactionCode")
local ProductionRules = require("./ProductionRules")
local WeightedRoll = require("./WeightedRoll")
local Variants = require("./Variants")

local CollectNestRules = {}

export type StagedCollectNest = {
	SlotId: number,
	EggsCollected: number,
	VariantCounts: { [string]: number },
	NewFarmSlots: { [number]: Types.FarmSlot },
	NewProductionEggInventory: Types.ProductionEggInventoryByRarity,
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
-- write), then rolls each newly-produced egg's variant against the *laying* dragon's own Rarity
-- odds (GDD §2, `productionConfig.variantOddsByRarity`) and moves them into
-- ProductionEggInventory[dragonRarity] in one shot. `variantRollValues` must have at least as
-- many entries as could possibly be produced in one Advance (bounded by `nestCapacity`, since
-- ProductionRules.Advance never creates more eggs than the Nest's capacity) -- the caller
-- (CollectNestTransaction) always supplies `nestCapacity` fresh math.random() values so it never
-- needs to know `eggsCollected` in advance.
function CollectNestRules.Stage(
	productionConfig: Types.ProductionConfig,
	profile: Types.Profile,
	payload: { [string]: any },
	now: number,
	variantRollValues: { number }
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

	local dragon = profile.dragons[advanced.AssignedDragonUID :: string]
	if not dragon then
		return false, nil, TransactionCode.DragonNotFound
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

	-- `dragon.Rarity` is a known-valid Rarity already stored on the profile -- cast through
	-- `:: any` for the same luau-lsp union-widening quirk documented in Rarities.luau.
	local odds = productionConfig.variantOddsByRarity[dragon.Rarity :: any]
	local variantCounts: { [string]: number } = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 }
	for i = 1, eggsCollected do
		local variant = WeightedRoll.pick(Variants.List, odds :: any, variantRollValues[i])
		variantCounts[variant] += 1
	end

	local newProductionEggInventory = table.clone(profile.productionEggInventory)
	local existingRarityBucket = newProductionEggInventory[dragon.Rarity :: any]
	local newRarityBucket = table.clone(existingRarityBucket)
	for _, variant in Variants.List do
		newRarityBucket[variant] += variantCounts[variant]
	end
	(newProductionEggInventory :: any)[dragon.Rarity] = newRarityBucket

	return true,
		{
			SlotId = slotId,
			EggsCollected = eggsCollected,
			VariantCounts = variantCounts,
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
		VariantCounts = staged.VariantCounts,
	}
end

return CollectNestRules
