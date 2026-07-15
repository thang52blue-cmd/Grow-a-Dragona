-- Pure Validate/Stage/Commit rules for ClaimHatchTransaction (backlog item 4). No engine
-- globals or IO (AGENTS.md hard rule) -- `now` and `rollValue` are explicit parameters (the
-- caller passes context.TransactionTime and math.random()) so the finish-time check is
-- always against a server timestamp and specs can assert an exact rolled outcome.
local Types = require("../Types/Types")
local TransactionCode = require("./TransactionCode")
local WeightedRoll = require("./WeightedRoll")

local ClaimHatchRules = {}

export type StagedClaimHatch = {
	DragonId: string,
	DragonRarity: string,
	NewPendingHatches: { [string]: Types.PendingHatch },
	NewDragons: { [string]: Types.DragonRecord },
	NewNextEntityId: number,
	HatchedAt: number,
}

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
-- claim that a hatch is ready) and rolls the dragon's rarity from the *hatched egg's own*
-- tier odds (the same EggConfig.hatchingTiers[rarity].odds already used to sell eggs --
-- no new probability numbers invented here).
function ClaimHatchRules.Stage(
	eggConfig: Types.EggConfig,
	profile: Types.Profile,
	payload: { [string]: any },
	now: number,
	rollValue: number
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
	local dragonRarity = WeightedRoll.pick(tierConfig.odds :: any, rollValue)
	local dragonId = tostring(profile.meta.nextEntityId)

	local newPendingHatches = table.clone(profile.pendingHatches)
	newPendingHatches[hatchId] = nil

	-- Plain `string`, not `Types.Rarity`: same luau-lsp widening quirk documented in
	-- BuyEggRules.luau -- dragonRarity is already a known-valid rarity (WeightedRoll only
	-- ever returns a member of Rarities.List).
	local newDragons = table.clone(profile.dragons)
	newDragons[dragonId] = { Id = dragonId, Rarity = dragonRarity :: any, HatchedAt = now }

	return true,
		{
			DragonId = dragonId,
			DragonRarity = dragonRarity,
			NewPendingHatches = newPendingHatches,
			NewDragons = newDragons,
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
	profile.meta.nextEntityId = staged.NewNextEntityId

	return {
		DragonId = staged.DragonId,
		Rarity = staged.DragonRarity,
	}
end

return ClaimHatchRules
