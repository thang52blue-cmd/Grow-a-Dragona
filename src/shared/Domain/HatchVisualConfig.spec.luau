local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local HatchVisualConfig = require("./HatchVisualConfig")

-- Mirrors the real src/shared/Data/HatchVisualConfig.json (see docs/prd/hatch-reveal-sequence.md)
-- so this spec proves the actual authored escalation, not just the validator's own logic.
-- Lune can't `require` a bare .json module the way Rojo's sync does, so this fixture is kept
-- in sync by hand -- a change to one without the other is a real drift risk, flagged here.
local REAL_CONFIG = {
	Common = {
		shakeMagnitudeStuds = 0.05,
		crackDurationSeconds = 0.5,
		revealDurationSeconds = 1.0,
		cameraPushInStuds = 2,
		cameraFovDelta = 5,
		hasHitch = false,
		hasRoar = false,
		hasScreenFlash = false,
		particleSizeScale = 1.0,
		hapticBucket = "Light",
		toastSuffix = "",
	},
	Rare = {
		shakeMagnitudeStuds = 0.07,
		crackDurationSeconds = 0.5,
		revealDurationSeconds = 1.2,
		cameraPushInStuds = 3,
		cameraFovDelta = 8,
		hasHitch = false,
		hasRoar = false,
		hasScreenFlash = false,
		particleSizeScale = 1.3,
		hapticBucket = "Medium",
		toastSuffix = "",
	},
	Epic = {
		shakeMagnitudeStuds = 0.09,
		crackDurationSeconds = 0.7,
		revealDurationSeconds = 1.3,
		cameraPushInStuds = 4,
		cameraFovDelta = 12,
		hasHitch = true,
		hasRoar = false,
		hasScreenFlash = false,
		particleSizeScale = 1.6,
		hapticBucket = "Medium",
		toastSuffix = "",
	},
	Legendary = {
		shakeMagnitudeStuds = 0.12,
		crackDurationSeconds = 0.9,
		revealDurationSeconds = 1.5,
		cameraPushInStuds = 6,
		cameraFovDelta = 16,
		hasHitch = true,
		hasRoar = true,
		hasScreenFlash = false,
		particleSizeScale = 2.0,
		hapticBucket = "Strong",
		toastSuffix = "",
	},
	Mythic = {
		shakeMagnitudeStuds = 0.15,
		crackDurationSeconds = 1.1,
		revealDurationSeconds = 1.8,
		cameraPushInStuds = 8,
		cameraFovDelta = 20,
		hasHitch = true,
		hasRoar = true,
		hasScreenFlash = true,
		particleSizeScale = 2.5,
		hapticBucket = "Strong",
		toastSuffix = " (WOW!)",
	},
}

local function cloneConfig()
	local clone = {}
	for rarity, tier in REAL_CONFIG do
		clone[rarity] = table.clone(tier)
	end
	return clone
end

local passed = Check.runAll({
	{
		name = "the real authored config escalates monotonically Common -> Mythic",
		run = function()
			local ok, reason = HatchVisualConfig.ValidateEscalation(REAL_CONFIG :: any)
			Check.isTrue(ok, reason)
		end,
	},
	{
		name = "Common never dresses up more than Mythic (spot checks matching the PRD tables)",
		run = function()
			Check.isFalse(REAL_CONFIG.Common.hasRoar)
			Check.isFalse(REAL_CONFIG.Common.hasScreenFlash)
			Check.isTrue(REAL_CONFIG.Mythic.hasRoar)
			Check.isTrue(REAL_CONFIG.Mythic.hasScreenFlash)
			Check.equal(REAL_CONFIG.Common.toastSuffix, "")
			Check.equal(REAL_CONFIG.Mythic.toastSuffix, " (WOW!)")
		end,
	},
	{
		name = "rejects a missing rarity entry",
		run = function()
			local broken = cloneConfig()
			broken.Epic = nil
			local ok, reason = HatchVisualConfig.ValidateEscalation(broken :: any)
			Check.isFalse(ok)
			Check.equal(reason, "missing entry for Epic")
		end,
	},
	{
		name = "rejects a numeric regression (a higher rarity dressed up less than a lower one)",
		run = function()
			local broken = cloneConfig()
			broken.Rare.crackDurationSeconds = 0.1
			local ok, reason = HatchVisualConfig.ValidateEscalation(broken :: any)
			Check.isFalse(ok)
			Check.equal(reason, "Rare crackDurationSeconds regressed")
		end,
	},
	{
		name = "rejects a boolean regression (hasRoar flipping back off at a higher rarity)",
		run = function()
			local broken = cloneConfig()
			broken.Mythic.hasRoar = false
			local ok, reason = HatchVisualConfig.ValidateEscalation(broken :: any)
			Check.isFalse(ok)
			Check.equal(reason, "Mythic lost hasRoar")
		end,
	},
	{
		name = "rejects a haptic bucket regression",
		run = function()
			local broken = cloneConfig()
			broken.Legendary.hapticBucket = "Light"
			local ok, reason = HatchVisualConfig.ValidateEscalation(broken :: any)
			Check.isFalse(ok)
			Check.equal(reason, "Legendary hapticBucket regressed")
		end,
	},
})

process.exit(if passed then 0 else 1)
