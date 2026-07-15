local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local StartHatchRules = require("./StartHatchRules")
local TransactionCode = require("./TransactionCode")

local EGG_CONFIG = {
	hatchingTiers = {
		Common = { goldPrice = 10, odds = {}, enabled = true, maxPurchaseAmount = 50, hatchDurationSeconds = 5 },
		Rare = { goldPrice = 50, odds = {}, enabled = true, maxPurchaseAmount = 20, hatchDurationSeconds = 30 },
	},
	productionVariants = {},
}

local TEST_POSITION = { X = 1, Y = 2, Z = 3 }

local function freshProfile(inventory: { [string]: number }?, nextEntityId: number?)
	return {
		gold = 0,
		inventory = inventory or {},
		pendingHatches = {},
		dragons = {},
		meta = { schemaVersion = 1, session = { jobId = nil, updatedAt = 0 }, nextEntityId = nextEntityId or 1 },
	}
end

local function runFullTransaction(profile, payload, now, position)
	local validateOk, validateCode = StartHatchRules.Validate(EGG_CONFIG, payload)
	if not validateOk then
		return false, validateCode
	end

	local stageOk, staged, stageCode = StartHatchRules.Stage(EGG_CONFIG, profile, payload, now, position or TEST_POSITION)
	if not stageOk then
		return false, stageCode
	end

	local resultData = StartHatchRules.Commit(profile, staged)
	return true, resultData
end

local passed = Check.runAll({
	{
		name = "starting a hatch consumes 1 egg and records a pending hatch with a server-derived FinishAt",
		run = function()
			local profile = freshProfile({ HatchEgg_Common = 3 })
			local ok, resultData = runFullTransaction(profile, { Rarity = "Common" }, 1000)

			Check.isTrue(ok)
			Check.equal(profile.inventory.HatchEgg_Common, 2)
			Check.equal(resultData.HatchId, "1")
			Check.equal(resultData.Rarity, "Common")
			Check.equal(resultData.FinishAt, 1005) -- now(1000) + hatchDurationSeconds(5)
			Check.equal(profile.pendingHatches["1"].FinishAt, 1005)
			Check.equal(profile.meta.nextEntityId, 2)
			Check.equal(resultData.Position.X, 1)
			Check.equal(profile.pendingHatches["1"].Position.Z, 3)
		end,
	},
	{
		name = "starting a second hatch mints a distinct id and keeps the first pending hatch intact",
		run = function()
			local profile = freshProfile({ HatchEgg_Common = 2, HatchEgg_Rare = 1 })
			local ok1 = runFullTransaction(profile, { Rarity = "Common" }, 1000)
			local ok2, resultData2 = runFullTransaction(profile, { Rarity = "Rare" }, 1000)

			Check.isTrue(ok1)
			Check.isTrue(ok2)
			Check.equal(resultData2.HatchId, "2")
			Check.equal(profile.pendingHatches["1"].Rarity, "Common")
			Check.equal(profile.pendingHatches["2"].Rarity, "Rare")
			Check.equal(profile.pendingHatches["2"].FinishAt, 1030) -- now(1000) + 30
			Check.equal(profile.meta.nextEntityId, 3)
		end,
	},
	{
		name = "rejects with NoEggToHatch when the player doesn't own the requested rarity",
		run = function()
			local profile = freshProfile({})
			local ok, code = runFullTransaction(profile, { Rarity = "Common" }, 1000)

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.NoEggToHatch)
			Check.equal(next(profile.pendingHatches), nil)
		end,
	},
	{
		name = "rejects an unknown rarity without touching the profile",
		run = function()
			local profile = freshProfile({ HatchEgg_Common = 1 })
			local ok, code = runFullTransaction(profile, { Rarity = "NotARarity" }, 1000)

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.InvalidEggType)
			Check.equal(profile.inventory.HatchEgg_Common, 1)
			Check.equal(next(profile.pendingHatches), nil)
		end,
	},
	{
		name = "Stage does not mutate the profile even though it computes new values",
		run = function()
			local profile = freshProfile({ HatchEgg_Common = 1 })
			local ok, staged = StartHatchRules.Stage(EGG_CONFIG, profile, { Rarity = "Common" }, 1000, TEST_POSITION)

			Check.isTrue(ok)
			Check.equal(profile.inventory.HatchEgg_Common, 1) -- unchanged until Commit
			Check.equal(next(profile.pendingHatches), nil) -- unchanged until Commit
			Check.equal(staged.FinishAt, 1005)
		end,
	},
})

process.exit(if passed then 0 else 1)
