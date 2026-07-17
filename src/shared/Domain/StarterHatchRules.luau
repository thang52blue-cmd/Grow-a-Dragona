-- Pure Stage/Commit rules for the free first-join Hatching Egg (GDD Section 1: "One free
-- egg, already sitting on the plot" / "Free egg odds: Same real odds as a paid starter-tier
-- egg, not scripted"). No engine globals or IO (AGENTS.md hard rule) -- unlike every other
-- transaction in this codebase, this one has no client payload and is never routed through
-- TransactionService: it's a one-time server-initiated grant on a player's very first
-- PlayerAdded, gated by profile.meta.starterHatchGranted (see
-- adr/ADR-005-farm-plot-and-starter-hatch.md). `now`/`position`/`rarityRollValue` are
-- explicit parameters, same rationale as every other Rules module (server clock, engine
-- position, and math.random() all stay outside pure code).
local Types = require("../Types/Types")
local Rarities = require("./Rarities")
local WeightedRoll = require("./WeightedRoll")

local STARTER_HATCH_TIER = "Common"

local StarterHatchRules = {}

export type StagedStarterHatch = {
	Id: string,
	Rarity: string,
	StartedAt: number,
	FinishAt: number,
	Position: Types.Position,
	NewNextEntityId: number,
}

-- Read-only guard: only ever grants once per profile.
function StarterHatchRules.ShouldGrant(profile: Types.Profile): boolean
	return not profile.meta.starterHatchGranted
end

-- Stage: computes the write set as new values, never mutating `profile`. Rolls against the
-- Common tier's own odds table -- the same real odds a paid Common egg uses, per the GDD --
-- rather than a scripted/guaranteed rarity.
function StarterHatchRules.Stage(
	eggConfig: Types.EggConfig,
	profile: Types.Profile,
	now: number,
	position: Types.Position,
	rarityRollValue: number
): StagedStarterHatch
	local tierConfig = eggConfig.hatchingTiers[STARTER_HATCH_TIER :: any]
	local rarity = WeightedRoll.pick(Rarities.List, tierConfig.odds :: any, rarityRollValue)

	return {
		Id = tostring(profile.meta.nextEntityId),
		Rarity = rarity,
		StartedAt = now,
		FinishAt = now + tierConfig.hatchDurationSeconds,
		Position = position,
		NewNextEntityId = profile.meta.nextEntityId + 1,
	}
end

-- Commit: the only step allowed to mutate `profile`. Records the pending hatch and flips
-- starterHatchGranted in the same shot so a later PlayerAdded on the same profile can never
-- grant a second free egg.
function StarterHatchRules.Commit(profile: Types.Profile, staged: StagedStarterHatch): { [string]: any }
	local newPendingHatches = table.clone(profile.pendingHatches)
	-- Plain `string`, not `Types.Rarity`: Stage rolled it via WeightedRoll.pick against
	-- Rarities.List, the same known-valid-membership case documented in BuyEggRules.luau.
	newPendingHatches[staged.Id] = {
		Id = staged.Id,
		Rarity = staged.Rarity :: any,
		StartedAt = staged.StartedAt,
		FinishAt = staged.FinishAt,
		Position = staged.Position,
	}
	profile.pendingHatches = newPendingHatches
	profile.meta.nextEntityId = staged.NewNextEntityId
	profile.meta.starterHatchGranted = true

	return {
		HatchId = staged.Id,
		Rarity = staged.Rarity,
		FinishAt = staged.FinishAt,
		Position = staged.Position,
	}
end

return StarterHatchRules
