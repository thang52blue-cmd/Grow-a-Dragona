-- Pure Validate/Stage/Commit rules for SendToStorageTransaction (Storage feature, see docs/prd/
-- storage-and-farm-slot-management.md). No engine globals or IO (AGENTS.md hard rule). The
-- client sends `SlotId` only -- the "Manage Dragon" prompt is anchored to a specific slot, and
-- deriving the dragon from the slot (rather than trusting a client-supplied DragonUID) means a
-- client can never claim to remove a dragon that isn't actually sitting in that slot.
local Types = require("../Types/Types")
local TransactionCode = require("./TransactionCode")

local SendToStorageRules = {}

export type StagedSendToStorage = {
	DragonUID: string,
	SlotId: number,
	NewDragons: { [string]: Types.DragonRecord },
	NewFarmSlots: { [number]: Types.FarmSlot },
}

function SendToStorageRules.Validate(payload: unknown): (boolean, number?)
	if type(payload) ~= "table" then
		return false, TransactionCode.InvalidRequest
	end
	local rawPayload = payload :: { [string]: any }

	if type(rawPayload.SlotId) ~= "number" or rawPayload.SlotId % 1 ~= 0 then
		return false, TransactionCode.InvalidRequest
	end

	return true, nil
end

-- Stage: computes the full write set as new values, never mutating `profile`. Rejects an
-- already-empty slot (NoDragonInSlot) and, critically, rejects while the slot's Nest still has
-- uncollected eggs (NestNotEmpty) -- ProductionRules.Advance leaves a slot with
-- AssignedDragonUID = nil untouched, so removing the dragon first would strand those eggs behind
-- a dragon lookup that can never succeed again (permanent, silent value loss). The player must
-- Collect first.
function SendToStorageRules.Stage(
	profile: Types.Profile,
	payload: { [string]: any },
	_now: number
): (boolean, StagedSendToStorage?, number?)
	local slotId = payload.SlotId :: number

	local slot = profile.farmSlots[slotId]
	if not slot then
		return false, nil, TransactionCode.SlotNotFound
	end

	local dragonUID = slot.AssignedDragonUID
	if dragonUID == nil then
		return false, nil, TransactionCode.NoDragonInSlot
	end

	if slot.UncollectedEggCount > 0 then
		return false, nil, TransactionCode.NestNotEmpty
	end

	local dragon = profile.dragons[dragonUID]
	if not dragon then
		return false, nil, TransactionCode.DragonNotFound
	end

	local newDragons = table.clone(profile.dragons)
	newDragons[dragonUID] = {
		Id = dragon.Id,
		Rarity = dragon.Rarity,
		Element = dragon.Element,
		GrowthStage = dragon.GrowthStage,
		FeedCount = dragon.FeedCount,
		HatchedAt = dragon.HatchedAt,
		AssignedSlotId = nil,
	}

	local newFarmSlots = table.clone(profile.farmSlots)
	newFarmSlots[slotId] = {
		SlotId = slotId,
		AssignedDragonUID = nil,
		ProductionStartedAt = nil,
		UncollectedEggCount = 0,
		IsProductionPaused = false,
	}

	return true,
		{
			DragonUID = dragonUID,
			SlotId = slotId,
			NewDragons = newDragons,
			NewFarmSlots = newFarmSlots,
		},
		nil
end

-- Commit: the only step allowed to mutate `profile`. Clears the dragon's and the slot's pointers
-- in the same shot so neither can ever point at the other once one side is cleared.
function SendToStorageRules.Commit(profile: Types.Profile, staged: StagedSendToStorage): { [string]: any }
	profile.dragons = staged.NewDragons
	profile.farmSlots = staged.NewFarmSlots

	return {
		DragonUID = staged.DragonUID,
		SlotId = staged.SlotId,
	}
end

return SendToStorageRules
