-- Pure escalation-shape validation for the hatch-reveal rarity dressing table
-- (`src/shared/Data/HatchVisualConfig.json` holds the actual authored numbers/colors/sound
-- layer names -- see `docs/prd/hatch-reveal-sequence.md`). Lune's `require` can't resolve a
-- bare `.json` module the way Rojo's Studio sync does (confirmed empirically: it only walks
-- `.luau` children), so this module takes a config table as an explicit parameter, the same
-- pattern every other Rules module (BuyEggRules, ClaimHatchRules, ...) already uses for its
-- Config argument rather than requiring the JSON directly. The real JSON is exercised by the
-- client controllers at runtime and by the live Studio MCP pass, not by this spec.
local Types = require("../Types/Types")
local Rarities = require("./Rarities")

local HatchVisualConfig = {}

local HAPTIC_ORDER: { [string]: number } = { Light = 1, Medium = 2, Strong = 3 }

-- Returns true, nil when every escalating field is monotonically non-decreasing across
-- Rarities.List (Common -> Mythic never gets *less* dramatic than a lower tier), or
-- false, reason on the first violation found. Booleans (hasHitch/hasRoar/hasScreenFlash) may
-- only turn on once and stay on -- they may never flip back off at a higher rarity.
function HatchVisualConfig.ValidateEscalation(config: Types.HatchVisualConfig): (boolean, string?)
	local previous: Types.HatchVisualTierConfig? = nil

	for _, rarity in Rarities.List do
		local tier = (config :: any)[rarity]
		if not tier then
			return false, `missing entry for {rarity}`
		end

		if previous then
			if tier.shakeMagnitudeStuds < previous.shakeMagnitudeStuds then
				return false, `{rarity} shakeMagnitudeStuds regressed`
			end
			if tier.crackDurationSeconds < previous.crackDurationSeconds then
				return false, `{rarity} crackDurationSeconds regressed`
			end
			if tier.revealDurationSeconds < previous.revealDurationSeconds then
				return false, `{rarity} revealDurationSeconds regressed`
			end
			if tier.cameraPushInStuds < previous.cameraPushInStuds then
				return false, `{rarity} cameraPushInStuds regressed`
			end
			if tier.cameraFovDelta < previous.cameraFovDelta then
				return false, `{rarity} cameraFovDelta regressed`
			end
			if tier.particleSizeScale < previous.particleSizeScale then
				return false, `{rarity} particleSizeScale regressed`
			end
			if previous.hasHitch and not tier.hasHitch then
				return false, `{rarity} lost hasHitch`
			end
			if previous.hasRoar and not tier.hasRoar then
				return false, `{rarity} lost hasRoar`
			end
			if previous.hasScreenFlash and not tier.hasScreenFlash then
				return false, `{rarity} lost hasScreenFlash`
			end
			if HAPTIC_ORDER[tier.hapticBucket] < HAPTIC_ORDER[previous.hapticBucket] then
				return false, `{rarity} hapticBucket regressed`
			end
		end

		previous = tier
	end

	return true, nil
end

return HatchVisualConfig
