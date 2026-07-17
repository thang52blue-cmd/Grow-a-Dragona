-- Pure Validate/Stage/Commit rules for ClaimHatchTransaction (backlog item 4). No engine
-- globals or IO (AGENTS.md hard rule) -- `now` and `rollValue` are explicit parameters (the
-- caller passes context.TransactionTime and math.random()) so the finish-time check is
-- always against a server timestamp and specs can assert an exact rolled outcome.
local Types = require("../Types/Types")
local TransactionCode = require("./TransactionCode")
local WeightedRoll = require("./WeightedRoll")
local Rarities = require("./Rarities")
local Elements = require("./Elements")

local ClaimHatchRules = {}

export type StagedClaimHatch = {
	DragonId: string,
	DragonRarity: string,
	AssignedSlotId: number?,
	NewPendingHatches: { [string]: Types.PendingHatch },
	NewDragons: { [string]: Types.DragonRecord },
	NewFarmSlots: { [number]: Types.FarmSlot },
	NewNextEntityId: number,
	HatchedAt: number,
}

-- Lowest-numbered farmSlots entry with no dragon in it yet, or nil if every slot is
-- occupied. Deterministic order (not dict iteration order) so which slot a freshly-hatched
-- dragon lands in never depends on Luau's unspecified table-iteration order.
local function firstOpenSlotId(farmSlots: { [number]: Types.FarmSlot }): number?
	local slotIds = {}
	for slotId in farmSlots do
		table.insert(slotIds, slotId)
	end
	table.sort(slotIds)
	for _, slotId in slotIds do
		if farmSlots[slotId].AssignedDragonUID == nil then
			return slotId
		end
	end
	return nil
end

-- Validate: read-only. Only checks the payload shape -- whether the hatch exists/is ready
-- is checked in Stage against the live profile.
function ClaimHatchRules.Validate(payload: unknown): (boolean, number?)
	if type(payload) ~= "table" then
		return false, TransactionCode.InvalidRequest
	end
	local rawPayload = payload :: { [string]: any }

	if type(rawPayload.HatchId) ~= "string" or rawPayload.HatchId == "" then
		return false, TransactionCode.InvalidRequest
	end

	return true, nil
end

-- Stage: computes the full write set as new values, never mutating `profile`. Re-checks
-- `now >= FinishAt` against the server-recorded finish time (never trusts the client's
-- claim that a hatch is ready), rolls the dragon's rarity from the *hatched egg's own*
-- tier odds (the same EggConfig.hatchingTiers[rarity].odds already used to sell eggs --
-- no new probability numbers invented here), and independently rolls an Element from
-- DragonConfig.elementOdds (backlog item 5 -- Feed Dragon needs Element to resolve which
-- food matches; see adr/ADR-003-feed-dragon-schema.md for why this was previously blocked).
-- Every new dragon starts Baby_0/FeedCount=0, per docs/prd/core-game-loop.md.
function ClaimHatchRules.Stage(
	eggConfig: Types.EggConfig,
	dragonConfig: Types.DragonConfig,
	profile: Types.Profile,
	payload: { [string]: any },
	now: number,
	rarityRollValue: number,
	elementRollValue: number
): (boolean, StagedClaimHatch?, number?)
	local hatchId = payload.HatchId :: string
	local pending = profile.pendingHatches[hatchId]
	if not pending then
		return false, nil, TransactionCode.NoHatchInProgress
	end

	if now < pending.FinishAt then
		return false, nil, TransactionCode.HatchNotReady
	end

	local tierConfig = eggConfig.hatchingTiers[pending.Rarity :: any]
	-- `tierConfig.odds` is `Types.EggOdds` ({[Rarity]: number}), WeightedRoll.pick takes the
	-- more general `{[string]: number}` -- cast at the boundary rather than widen the
	-- (deliberately Rarity-agnostic, reusable) WeightedRoll signature.
	local dragonRarity = WeightedRoll.pick(Rarities.List, tierConfig.odds :: any, rarityRollValue)
	local dragonElement = WeightedRoll.pick(Elements.List, dragonConfig.elementOdds :: any, elementRollValue)
	local dragonId = tostring(profile.meta.nextEntityId)

	local newPendingHatches = table.clone(profile.pendingHatches)
	newPendingHatches[hatchId] = nil

	-- Auto-place the new Baby into the first open Farm Slot (GDD §1: "The hatched dragon is
	-- auto-assigned to the first open slot"), not just a manual AssignProducer call, so the
	-- dragon has a physical spot on the plot from the moment it hatches. No production starts
	-- yet -- ProductionStartedAt stays nil until the dragon actually becomes Adult (see
	-- FeedDragonRules). If every slot is already occupied, AssignedSlotId stays nil, same as
	-- the GDD's overflow-to-storage rule (Storage itself isn't built yet, so the dragon simply
	-- has no world slot for now, rather than blocking the hatch).
	local assignedSlotId = firstOpenSlotId(profile.farmSlots)

	local newFarmSlots = profile.farmSlots
	if assignedSlotId then
		local slot = profile.farmSlots[assignedSlotId]
		newFarmSlots = table.clone(profile.farmSlots)
		newFarmSlots[assignedSlotId] = {
			SlotId = assignedSlotId,
			AssignedDragonUID = dragonId,
			ProductionStartedAt = nil,
			UncollectedEggCount = slot.UncollectedEggCount,
			IsProductionPaused = slot.IsProductionPaused,
		}
	end

	-- Plain `string`, not `Types.Rarity`/`Types.Element`: same luau-lsp widening quirk
	-- documented in BuyEggRules.luau -- both rolled values are already known-valid members
	-- of their respective fixed-order lists.
	local newDragons = table.clone(profile.dragons)
	newDragons[dragonId] = {
		Id = dragonId,
		Rarity = dragonRarity :: any,
		Element = dragonElement :: any,
		GrowthStage = "Baby_0",
		FeedCount = 0,
		HatchedAt = now,
		AssignedSlotId = assignedSlotId,
	}

	return true,
		{
			DragonId = dragonId,
			DragonRarity = dragonRarity,
			AssignedSlotId = assignedSlotId,
			NewPendingHatches = newPendingHatches,
			NewDragons = newDragons,
			NewFarmSlots = newFarmSlots,
			NewNextEntityId = profile.meta.nextEntityId + 1,
			HatchedAt = now,
		},
		nil
end

-- Commit: the only step allowed to mutate `profile`. Consumes the pending hatch and grants
-- the dragon in the same shot so a claim can never do one without the other, and a second
-- claim attempt for the same HatchId always finds it already gone (NoHatchInProgress) --
-- the duplicate-request cache in TransactionService additionally short-circuits an exact
-- requestId replay before Commit ever runs again.
function ClaimHatchRules.Commit(profile: Types.Profile, staged: StagedClaimHatch): { [string]: any }
	profile.pendingHatches = staged.NewPendingHatches
	profile.dragons = staged.NewDragons
	profile.farmSlots = staged.NewFarmSlots
	profile.meta.nextEntityId = staged.NewNextEntityId

	return {
		DragonId = staged.DragonId,
		Rarity = staged.DragonRarity,
		AssignedSlotId = staged.AssignedSlotId,
	}
end

return ClaimHatchRules
