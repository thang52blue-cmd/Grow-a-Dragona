-- Pure Validate/Stage/Commit rules for AssignProducerTransaction (backlog item 6). No engine
-- globals or IO (AGENTS.md hard rule); see adr/ADR-004-farm-slot-and-nest-schema.md for the
-- schema this relies on. The client sends `DragonUID` and `SlotId` only
-- (docs/prd/core-game-loop.md) -- production start time is always the server's own clock.
local Types = require("../Types/Types")
local TransactionCode = require("./TransactionCode")

local AssignProducerRules = {}

export type StagedAssignProducer = {
	DragonUID: string,
	SlotId: number,
	NewDragons: { [string]: Types.DragonRecord },
	NewFarmSlots: { [number]: Types.FarmSlot },
}

-- Validate: read-only, payload shape only. Ownership/state is checked in Stage against the live
-- profile.
function AssignProducerRules.Validate(payload: unknown): (boolean, number?)
	if type(payload) ~= "table" then
		return false, TransactionCode.InvalidRequest
	end
	local rawPayload = payload :: { [string]: any }

	if type(rawPayload.DragonUID) ~= "string" or rawPayload.DragonUID == "" then
		return false, TransactionCode.InvalidRequest
	end
	if type(rawPayload.SlotId) ~= "number" or rawPayload.SlotId % 1 ~= 0 then
		return false, TransactionCode.InvalidRequest
	end

	return true, nil
end

-- Stage: computes the full write set as new values, never mutating `profile`. Order of checks
-- follows the PRD's AssignProducerTransaction validation list: owns Dragon (implicit -- dragons
-- only ever live in the caller's own profile.dragons, same "not found == not owned" precedent as
-- FeedDragonRules), Dragon is Adult, Dragon not already assigned, Slot exists (implicit ownership,
-- same precedent), Slot is empty.
function AssignProducerRules.Stage(
	profile: Types.Profile,
	payload: { [string]: any },
	now: number
): (boolean, StagedAssignProducer?, number?)
	local dragonUID = payload.DragonUID :: string
	local slotId = payload.SlotId :: number

	local dragon = profile.dragons[dragonUID]
	if not dragon then
		return false, nil, TransactionCode.DragonNotFound
	end

	if dragon.GrowthStage ~= "Adult" then
		return false, nil, TransactionCode.DragonNotAdult
	end

	if dragon.AssignedSlotId ~= nil then
		return false, nil, TransactionCode.DragonAlreadyAssigned
	end

	local slot = profile.farmSlots[slotId]
	if not slot then
		return false, nil, TransactionCode.SlotNotFound
	end

	if slot.AssignedDragonUID ~= nil then
		return false, nil, TransactionCode.SlotOccupied
	end

	local newDragons = table.clone(profile.dragons)
	newDragons[dragonUID] = {
		Id = dragon.Id,
		Rarity = dragon.Rarity,
		Element = dragon.Element,
		GrowthStage = dragon.GrowthStage,
		FeedCount = dragon.FeedCount,
		HatchedAt = dragon.HatchedAt,
		AssignedSlotId = slotId,
	}

	local newFarmSlots = table.clone(profile.farmSlots)
	newFarmSlots[slotId] = {
		SlotId = slotId,
		AssignedDragonUID = dragonUID,
		ProductionStartedAt = now,
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

-- Commit: the only step allowed to mutate `profile`. Assigns the dragon and the slot in the
-- same shot so a dragon can never point at a slot that doesn't point back (or vice versa).
function AssignProducerRules.Commit(profile: Types.Profile, staged: StagedAssignProducer): { [string]: any }
	profile.dragons = staged.NewDragons
	profile.farmSlots = staged.NewFarmSlots

	return {
		DragonUID = staged.DragonUID,
		SlotId = staged.SlotId,
	}
end

return AssignProducerRules
