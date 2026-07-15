-- Pure Validate/Stage/Commit rules for StartHatchTransaction (backlog item 4). No engine
-- globals or IO (AGENTS.md hard rule) -- `now` is an explicit parameter (the caller passes
-- context.TransactionTime, a server os.time() snapshot) rather than read internally, so the
-- finish time is always a server timestamp and specs can assert exact FinishAt values.
local BuyEggRules = require("./BuyEggRules")
local Inventory = require("./Inventory")
local Rarities = require("./Rarities")
local TransactionCode = require("./TransactionCode")
local Types = require("../Types/Types")

local StartHatchRules = {}

export type StagedStartHatch = {
	Id: string,
	Rarity: string,
	StartedAt: number,
	FinishAt: number,
	Position: Types.Position,
	NewInventory: Types.Inventory,
	NewNextEntityId: number,
}

-- Validate: read-only. Only checks the payload shape; ownership/duration come from the
-- (server-only) egg config and the live profile, checked in Stage.
function StartHatchRules.Validate(_eggConfig: Types.EggConfig, payload: unknown): (boolean, number?)
	if type(payload) ~= "table" then
		return false, TransactionCode.InvalidRequest
	end
	local rawPayload = payload :: { [string]: any }

	if not Rarities.IsValid(rawPayload.Rarity) then
		return false, TransactionCode.InvalidEggType
	end

	return true, nil
end

-- Stage: computes the full write set as new values, never mutating `profile`. Consumes
-- exactly 1 owned egg of the requested rarity and mints a new hatch id off the profile's
-- own counter (never a client-supplied requestId -- that resets to 1 every client session
-- and isn't safe as a persisted map key). `position` is an explicit parameter (the caller
-- reads the player's actual HumanoidRootPart.Position, an engine concept this pure module
-- never touches) so the hatch remembers exactly where its egg was spawned.
function StartHatchRules.Stage(
	eggConfig: Types.EggConfig,
	profile: Types.Profile,
	payload: { [string]: any },
	now: number,
	position: Types.Position
): (boolean, StagedStartHatch?, number?)
	local rarity = payload.Rarity :: string
	local itemId = BuyEggRules.HatchEggItemId(rarity)

	local removeOk, newInventory = Inventory.remove(profile.inventory, itemId, 1)
	if not removeOk then
		return false, nil, TransactionCode.NoEggToHatch
	end

	local tierConfig = eggConfig.hatchingTiers[rarity :: any]
	local id = tostring(profile.meta.nextEntityId)
	local finishAt = now + tierConfig.hatchDurationSeconds

	return true,
		{
			Id = id,
			Rarity = rarity,
			StartedAt = now,
			FinishAt = finishAt,
			Position = position,
			NewInventory = newInventory,
			NewNextEntityId = profile.meta.nextEntityId + 1,
		},
		nil
end

-- Commit: the only step allowed to mutate `profile`. Removes the egg and records the
-- pending hatch in the same shot so a successful transaction can never do one without the
-- other.
function StartHatchRules.Commit(profile: Types.Profile, staged: StagedStartHatch): { [string]: any }
	profile.inventory = staged.NewInventory

	-- Plain `string`, not `Types.Rarity`: Validate already confirmed membership via
	-- Rarities.IsValid, same luau-lsp widening quirk documented in BuyEggRules.luau.
	local newPendingHatches = table.clone(profile.pendingHatches)
	newPendingHatches[staged.Id] = {
		Id = staged.Id,
		Rarity = staged.Rarity :: any,
		StartedAt = staged.StartedAt,
		FinishAt = staged.FinishAt,
		Position = staged.Position,
	}
	profile.pendingHatches = newPendingHatches
	profile.meta.nextEntityId = staged.NewNextEntityId

	return {
		HatchId = staged.Id,
		Rarity = staged.Rarity,
		FinishAt = staged.FinishAt,
		Position = staged.Position,
	}
end

return StartHatchRules
