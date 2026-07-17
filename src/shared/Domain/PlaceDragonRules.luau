-- Pure Validate/Stage/Commit rules for PlaceDragonTransaction (Storage feature, see docs/prd/
-- storage-and-farm-slot-management.md). No engine globals or IO (AGENTS.md hard rule). The
-- client sends `DragonUID` and `SlotId` only -- production start time is always the server's own
-- clock.
--
-- Formerly "AssignProducerRules"/Adult-only (backlog item 6) -- renamed and generalized because
-- this is now the general "place any Storage dragon (Baby or Adult) into an empty Farm Slot"
-- operation the Storage Picker uses, not just a production-assignment action. It had zero client
-- callers under its old name/gate, so nothing depended on the Adult-only restriction.
local Types = require("../Types/Types")
local TransactionCode = require("./TransactionCode")

local PlaceDragonRules = {}

export type StagedPlaceDragon = {
	DragonUID: string,
	SlotId: number,
	NewDragons: { [string]: Types.DragonRecord },
	NewFarmSlots: { [number]: Types.FarmSlot },
}

-- Validate: read-only, payload shape only. Ownership/state is checked in Stage against the live
-- profile.
function PlaceDragonRules.Validate(payload: unknown): (boolean, number?)
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

-- Stage: computes the full write set as new values, never mutating `profile`. Checks: owns
-- Dragon (implicit -- dragons only ever live in the caller's own profile.dragons, same "not
-- found == not owned" precedent as FeedDragonRules), Dragon is currently in Storage (not already
-- assigned), Slot exists (implicit ownership, same precedent), Slot is empty. Unlike the old
-- Adult-only AssignProducerRules, any GrowthStage is accepted -- a placed Baby just sits there
-- producing nothing until it's fed to Adult, same as the existing hatch-time auto-placement path
-- (ClaimHatchRules); ProductionStartedAt is therefore only set for an Adult.
function PlaceDragonRules.Stage(
	profile: Types.Profile,
	payload: { [string]: any },
	now: number
): (boolean, StagedPlaceDragon?, number?)
	local dragonUID = payload.DragonUID :: string
	local slotId = payload.SlotId :: number

	local dragon = profile.dragons[dragonUID]
	if not dragon then
		return false, nil, TransactionCode.DragonNotFound
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
		ProductionStartedAt = if dragon.GrowthStage == "Adult" then now else nil,
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
function PlaceDragonRules.Commit(profile: Types.Profile, staged: StagedPlaceDragon): { [string]: any }
	profile.dragons = staged.NewDragons
	profile.farmSlots = staged.NewFarmSlots

	return {
		DragonUID = staged.DragonUID,
		SlotId = staged.SlotId,
	}
end

return PlaceDragonRules
