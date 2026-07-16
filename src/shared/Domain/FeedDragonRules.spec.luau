local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local FeedDragonRules = require("./FeedDragonRules")
local TransactionCode = require("./TransactionCode")

local FOOD_CONFIG = {
	Fire = { "ChiliPepper", "HotSauce", "FireBerry" },
	Water = { "Fish", "Seaweed", "PearlClam" },
	Earth = { "Mushroom", "Root", "MagicalHerb" },
	Light = { "MagicalCandy", "Honey", "StarSugar" },
	Dark = { "Lemon", "VinegarBerry", "DarkCrystal" },
}

local function profileWithDragon(dragonUID: string, overrides: { [string]: any }?, inventory: { [string]: number }?)
	local dragon = {
		Id = dragonUID,
		Rarity = "Common",
		Element = "Fire",
		GrowthStage = "Baby_0",
		FeedCount = 0,
		HatchedAt = 0,
	}
	if overrides then
		for k, v in overrides do
			dragon[k] = v
		end
	end

	return {
		gold = 0,
		inventory = inventory or {},
		pendingHatches = {},
		dragons = { [dragonUID] = dragon },
		meta = { schemaVersion = 1, session = { jobId = nil, updatedAt = 0 }, nextEntityId = 2 },
	}
end

local function runFullTransaction(profile, payload)
	local validateOk, validateCode = FeedDragonRules.Validate(payload)
	if not validateOk then
		return false, validateCode
	end

	local stageOk, staged, stageCode = FeedDragonRules.Stage(FOOD_CONFIG, profile, payload)
	if not stageOk then
		return false, stageCode
	end

	local resultData = FeedDragonRules.Commit(profile, staged)
	return true, resultData
end

local passed = Check.runAll({
	{
		name = "a correct-element Feed consumes exactly one food and advances Baby_0 to Baby_1",
		run = function()
			local profile = profileWithDragon("1", nil, { ChiliPepper = 3 })
			local ok, resultData = runFullTransaction(profile, { DragonUID = "1" })

			Check.isTrue(ok)
			Check.equal(resultData.GrowthStage, "Baby_1")
			Check.equal(resultData.FeedCount, 1)
			Check.isFalse(resultData.BecameAdult)
			Check.equal(profile.dragons["1"].GrowthStage, "Baby_1")
			Check.equal(profile.dragons["1"].FeedCount, 1)
			Check.equal(profile.inventory.ChiliPepper, 2) -- exactly one consumed
		end,
	},
	{
		name = "consumes whichever owned element-matching food comes first in config order",
		run = function()
			local profile = profileWithDragon("1", nil, { FireBerry = 1 })
			local ok, resultData = runFullTransaction(profile, { DragonUID = "1" })

			Check.isTrue(ok)
			Check.equal(resultData.FeedCount, 1)
			Check.equal(profile.inventory.FireBerry, nil) -- fully consumed, removed not zeroed
		end,
	},
	{
		name = "the 4th Feed transforms the dragon to Adult exactly once",
		run = function()
			local profile = profileWithDragon("1", { GrowthStage = "Baby_3", FeedCount = 3 }, { ChiliPepper = 1 })
			local ok, resultData = runFullTransaction(profile, { DragonUID = "1" })

			Check.isTrue(ok)
			Check.equal(resultData.GrowthStage, "Adult")
			Check.equal(resultData.FeedCount, 4)
			Check.isTrue(resultData.BecameAdult)
			Check.equal(profile.dragons["1"].GrowthStage, "Adult")
		end,
	},
	{
		name = "rejects with MissingFood when the player owns no matching-element food",
		run = function()
			local profile = profileWithDragon("1", nil, { Fish = 5 }) -- wrong element (Water, dragon is Fire)
			local ok, code = runFullTransaction(profile, { DragonUID = "1" })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.MissingFood)
			Check.equal(profile.dragons["1"].FeedCount, 0) -- untouched
		end,
	},
	{
		name = "rejects with MissingFood when the player owns no food at all",
		run = function()
			local profile = profileWithDragon("1", nil, {})
			local ok, code = runFullTransaction(profile, { DragonUID = "1" })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.MissingFood)
		end,
	},
	{
		name = "rejects with DragonAlreadyAdult when feeding an Adult dragon, and does not consume food",
		run = function()
			local profile = profileWithDragon("1", { GrowthStage = "Adult", FeedCount = 4 }, { ChiliPepper = 5 })
			local ok, code = runFullTransaction(profile, { DragonUID = "1" })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.DragonAlreadyAdult)
			Check.equal(profile.inventory.ChiliPepper, 5) -- untouched
		end,
	},
	{
		name = "rejects with DragonNotFound for an unknown DragonUID",
		run = function()
			local profile = profileWithDragon("1", nil, { ChiliPepper = 5 })
			local ok, code = runFullTransaction(profile, { DragonUID = "does-not-exist" })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.DragonNotFound)
		end,
	},
	{
		name = "rejects a malformed payload (missing/empty DragonUID) without touching the profile",
		run = function()
			local profile = profileWithDragon("1", nil, { ChiliPepper = 5 })
			local ok1, code1 = runFullTransaction(profile, {})
			local ok2, code2 = runFullTransaction(profile, { DragonUID = "" })

			Check.isFalse(ok1)
			Check.equal(code1, TransactionCode.InvalidRequest)
			Check.isFalse(ok2)
			Check.equal(code2, TransactionCode.InvalidRequest)
			Check.equal(profile.dragons["1"].FeedCount, 0)
		end,
	},
	{
		name = "a duplicated Feed request applied twice never advances FeedCount past 4",
		run = function()
			local profile = profileWithDragon("1", { GrowthStage = "Baby_3", FeedCount = 3 }, { ChiliPepper = 5 })
			local ok1 = runFullTransaction(profile, { DragonUID = "1" })
			local ok2, code2 = runFullTransaction(profile, { DragonUID = "1" })

			Check.isTrue(ok1)
			Check.isFalse(ok2)
			Check.equal(code2, TransactionCode.DragonAlreadyAdult)
			Check.equal(profile.dragons["1"].FeedCount, 4)
		end,
	},
	{
		name = "Stage does not mutate the profile even though it computes new values",
		run = function()
			local profile = profileWithDragon("1", nil, { ChiliPepper = 3 })
			local ok, staged = FeedDragonRules.Stage(FOOD_CONFIG, profile, { DragonUID = "1" })

			Check.isTrue(ok)
			Check.equal(profile.dragons["1"].FeedCount, 0) -- unchanged until Commit
			Check.equal(profile.inventory.ChiliPepper, 3) -- unchanged until Commit
			Check.equal(staged.NewFeedCount, 1)
		end,
	},
})

process.exit(if passed then 0 else 1)
