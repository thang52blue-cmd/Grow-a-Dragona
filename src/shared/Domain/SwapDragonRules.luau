-- Pure Validate/Stage/Commit rules for SwapDragonTransaction (Storage feature, see docs/prd/
-- storage-and-farm-slot-management.md). No engine globals or IO (AGENTS.md hard rule). The
-- client sends `SlotId` (which slot to swap) and `NewDragonUID` (which Storage dragon to swap
-- in) -- the slot's current occupant is derived server-side, same anti-spoofing rationale as
-- SendToStorageRules.
--
-- Atomicity: both dragons move in the same Stage/Commit call, writing one combined
-- NewDragons/NewFarmSlots table -- there is no intermediate state where the old dragon has left
-- the slot but the new one hasn't arrived yet (or vice versa), satisfying the "no dragon lost or
-- duplicated" requirement without needing any extra locking beyond the transaction system's
-- existing one-Atomic-Write-Set-per-commit rule.
local Types = require("../Types/Types")
local TransactionCode = require("./TransactionCode")

local SwapDragonRules = {}

export type StagedSwapDragon = {
	OldDragonUID: string,
	NewDragonUID: string,
	SlotId: number,
	NewDragons: { [string]: Types.DragonRecord },
	NewFarmSlots: { [number]: Types.FarmSlot },
}

function SwapDragonRules.Validate(payload: unknown): (boolean, number?)
	if type(payload) ~= "table" then
		return false, TransactionCode.InvalidRequest
	end
	local rawPayload = payload :: { [string]: any }

	if type(rawPayload.SlotId) ~= "number" or rawPayload.SlotId % 1 ~= 0 then
		return false, TransactionCode.InvalidRequest
	end
	if type(rawPayload.NewDragonUID) ~= "string" or rawPayload.NewDragonUID == "" then
		return false, TransactionCode.InvalidRequest
	end

	return true, nil
end

-- Stage: computes the full write set as new values, never mutating `profile`. Same NestNotEmpty
-- guard as SendToStorageRules -- swapping out the current occupant would orphan any uncollected
-- eggs the same way removing it outright would. `NewDragonUID` must currently be in Storage
-- (AssignedSlotId == nil); passing the slot's own current occupant as `NewDragonUID` is rejected
-- by that same check (it's assigned to this very slot, not in Storage), so no separate
-- same-dragon guard is needed.
function SwapDragonRules.Stage(
	profile: Types.Profile,
	payload: { [string]: any },
	now: number
): (boolean, StagedSwapDragon?, number?)
	local slotId = payload.SlotId :: number
	local newDragonUID = payload.NewDragonUID :: string

	local slot = profile.farmSlots[slotId]
	if not slot then
		return false, nil, TransactionCode.SlotNotFound
	end

	local oldDragonUID = slot.AssignedDragonUID
	if oldDragonUID == nil then
		return false, nil, TransactionCode.NoDragonInSlot
	end

	if slot.UncollectedEggCount > 0 then
		return false, nil, TransactionCode.NestNotEmpty
	end

	local oldDragon = profile.dragons[oldDragonUID]
	if not oldDragon then
		return false, nil, TransactionCode.DragonNotFound
	end

	local newDragon = profile.dragons[newDragonUID]
	if not newDragon then
		return false, nil, TransactionCode.DragonNotFound
	end

	if newDragon.AssignedSlotId ~= nil then
		return false, nil, TransactionCode.DragonAlreadyAssigned
	end

	local newDragons = table.clone(profile.dragons)
	newDragons[oldDragonUID] = {
		Id = oldDragon.Id,
		Rarity = oldDragon.Rarity,
		Element = oldDragon.Element,
		GrowthStage = oldDragon.GrowthStage,
		FeedCount = oldDragon.FeedCount,
		HatchedAt = oldDragon.HatchedAt,
		AssignedSlotId = nil,
	}
	newDragons[newDragonUID] = {
		Id = newDragon.Id,
		Rarity = newDragon.Rarity,
		Element = newDragon.Element,
		GrowthStage = newDragon.GrowthStage,
		FeedCount = newDragon.FeedCount,
		HatchedAt = newDragon.HatchedAt,
		AssignedSlotId = slotId,
	}

	local newFarmSlots = table.clone(profile.farmSlots)
	newFarmSlots[slotId] = {
		SlotId = slotId,
		AssignedDragonUID = newDragonUID,
		ProductionStartedAt = if newDragon.GrowthStage == "Adult" then now else nil,
		UncollectedEggCount = 0,
		IsProductionPaused = false,
	}

	return true,
		{
			OldDragonUID = oldDragonUID,
			NewDragonUID = newDragonUID,
			SlotId = slotId,
			NewDragons = newDragons,
			NewFarmSlots = newFarmSlots,
		},
		nil
end

-- Commit: the only step allowed to mutate `profile`. Both dragons' pointers and the slot's
-- pointer all flip in the same shot.
function SwapDragonRules.Commit(profile: Types.Profile, staged: StagedSwapDragon): { [string]: any }
	profile.dragons = staged.NewDragons
	profile.farmSlots = staged.NewFarmSlots

	return {
		OldDragonUID = staged.OldDragonUID,
		NewDragonUID = staged.NewDragonUID,
		SlotId = staged.SlotId,
	}
end

return SwapDragonRules
