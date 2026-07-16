-- Pure Validate/Stage/Commit rules for FeedDragonTransaction (backlog item 5). No engine
-- globals or IO (AGENTS.md hard rule); see adr/ADR-003-feed-dragon-schema.md for the schema
-- this relies on. The client sends only `DragonUID` (docs/prd/core-game-loop.md) -- Food type,
-- Feed count, and target GrowthStage are all resolved server-side from the dragon's own record.
local Types = require("../Types/Types")
local Inventory = require("./Inventory")
local TransactionCode = require("./TransactionCode")

local FEED_TO_TRANSFORM = 4

local FeedDragonRules = {}

export type StagedFeedDragon = {
	DragonUID: string,
	ConsumedFoodItemId: string,
	NewFeedCount: number,
	NewGrowthStage: Types.GrowthStage,
	BecameAdult: boolean,
	NewDragons: { [string]: Types.DragonRecord },
	NewInventory: Types.Inventory,
}

-- Validate: read-only, payload shape only. Ownership/state is checked in Stage against the
-- live profile (the DragonUID might be well-formed but not exist / not be a Baby).
function FeedDragonRules.Validate(payload: unknown): (boolean, number?)
	if type(payload) ~= "table" then
		return false, TransactionCode.InvalidRequest
	end
	local rawPayload = payload :: { [string]: any }

	if type(rawPayload.DragonUID) ~= "string" or rawPayload.DragonUID == "" then
		return false, TransactionCode.InvalidRequest
	end

	return true, nil
end

-- Stage: computes the full write set as new values, never mutating `profile`. Resolves the
-- required food from `dragon.Element` (rolled at hatch, ADR-003) against `foodConfig`'s fixed
-- 3-item-per-element list, consuming the first one the player owns at least 1 of -- see
-- ADR-003 for why "first owned in config order" was chosen over e.g. cheapest/random.
function FeedDragonRules.Stage(
	foodConfig: Types.FoodConfig,
	profile: Types.Profile,
	payload: { [string]: any }
): (boolean, StagedFeedDragon?, number?)
	local dragonUID = payload.DragonUID :: string
	local dragon = profile.dragons[dragonUID]
	if not dragon then
		return false, nil, TransactionCode.DragonNotFound
	end

	if dragon.GrowthStage == "Adult" then
		return false, nil, TransactionCode.DragonAlreadyAdult
	end

	local candidates = foodConfig[dragon.Element]
	local consumedFoodItemId: string? = nil
	for _, candidate in candidates do
		if Inventory.get(profile.inventory, candidate) > 0 then
			consumedFoodItemId = candidate
			break
		end
	end

	if not consumedFoodItemId then
		return false, nil, TransactionCode.MissingFood
	end

	local removeOk, newInventory = Inventory.remove(profile.inventory, consumedFoodItemId, 1)
	if not removeOk then
		-- Unreachable given the Inventory.get check above (nothing else mutates profile.inventory
		-- between the check and here -- Stage never mutates), kept only so Inventory.remove's
		-- contract isn't silently ignored.
		return false, nil, TransactionCode.MissingFood
	end

	local newFeedCount = dragon.FeedCount + 1
	local becameAdult = newFeedCount >= FEED_TO_TRANSFORM
	local newGrowthStage: Types.GrowthStage = if becameAdult then "Adult" else ("Baby_" .. newFeedCount) :: any

	local newDragons = table.clone(profile.dragons)
	newDragons[dragonUID] = {
		Id = dragon.Id,
		Rarity = dragon.Rarity,
		Element = dragon.Element,
		GrowthStage = newGrowthStage,
		FeedCount = newFeedCount,
		HatchedAt = dragon.HatchedAt,
		AssignedSlotId = dragon.AssignedSlotId,
	}

	return true,
		{
			DragonUID = dragonUID,
			ConsumedFoodItemId = consumedFoodItemId,
			NewFeedCount = newFeedCount,
			NewGrowthStage = newGrowthStage,
			BecameAdult = becameAdult,
			NewDragons = newDragons,
			NewInventory = newInventory,
		},
		nil
end

-- Commit: the only step allowed to mutate `profile`. Applies the food consumption and the
-- dragon's growth advance in one shot so a Feed can never consume food without also advancing
-- growth (or vice versa).
function FeedDragonRules.Commit(profile: Types.Profile, staged: StagedFeedDragon): { [string]: any }
	profile.dragons = staged.NewDragons
	profile.inventory = staged.NewInventory

	return {
		DragonUID = staged.DragonUID,
		GrowthStage = staged.NewGrowthStage,
		FeedCount = staged.NewFeedCount,
		BecameAdult = staged.BecameAdult,
	}
end

return FeedDragonRules
