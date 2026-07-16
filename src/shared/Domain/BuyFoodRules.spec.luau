local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local BuyFoodRules = require("./BuyFoodRules")
local TransactionCode = require("./TransactionCode")

local FOOD_SHOP_CONFIG = { ChiliPepper = 10, Fish = 15 }
local ECONOMY_CONFIG = { startingGold = 0, maxGold = 1000000, maxInventoryStack = 999999 }

local function freshProfile(gold: number, inventory: { [string]: number }?)
	return {
		gold = gold,
		inventory = inventory or {},
		meta = { schemaVersion = 1, session = { jobId = nil, updatedAt = 0 } },
	}
end

local function runFullTransaction(profile, payload)
	local validateOk, validateCode = BuyFoodRules.Validate(FOOD_SHOP_CONFIG, payload)
	if not validateOk then
		return false, validateCode
	end

	local stageOk, staged, stageCode = BuyFoodRules.Stage(FOOD_SHOP_CONFIG, ECONOMY_CONFIG, profile, payload)
	if not stageOk then
		return false, stageCode
	end

	local resultData = BuyFoodRules.Commit(profile, staged)
	return true, resultData
end

local passed = Check.runAll({
	{
		name = "a successful purchase deducts gold and grants food atomically",
		run = function()
			local profile = freshProfile(100)
			local ok, resultData = runFullTransaction(profile, { ItemId = "ChiliPepper", Amount = 3 })

			Check.isTrue(ok)
			Check.equal(profile.gold, 70)
			Check.equal(profile.inventory.ChiliPepper, 3)
			Check.equal(resultData.TotalPrice, 30)
			Check.equal(resultData.RemainingGold, 70)
			Check.equal(resultData.NewFoodAmount, 3)
		end,
	},
	{
		name = "buying into an existing stack adds to it instead of creating a second one",
		run = function()
			local profile = freshProfile(100, { ChiliPepper = 2 })
			local ok = runFullTransaction(profile, { ItemId = "ChiliPepper", Amount = 1 })

			Check.isTrue(ok)
			Check.equal(profile.inventory.ChiliPepper, 3)
		end,
	},
	{
		name = "different food items price independently",
		run = function()
			local profile = freshProfile(100)
			local ok, resultData = runFullTransaction(profile, { ItemId = "Fish", Amount = 2 })

			Check.isTrue(ok)
			Check.equal(resultData.TotalPrice, 30)
			Check.equal(profile.inventory.Fish, 2)
		end,
	},
	{
		name = "insufficient gold rejects and leaves gold/inventory untouched",
		run = function()
			local profile = freshProfile(5)
			local ok, code = runFullTransaction(profile, { ItemId = "ChiliPepper", Amount = 1 })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.NotEnoughCurrency)
			Check.equal(profile.gold, 5)
			Check.equal(next(profile.inventory), nil)
		end,
	},
	{
		name = "rejects an unknown ItemId with InvalidFoodType, and does not touch gold",
		run = function()
			local profile = freshProfile(100)
			local ok, code = runFullTransaction(profile, { ItemId = "NotARealFood", Amount = 1 })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.InvalidFoodType)
			Check.equal(profile.gold, 100)
		end,
	},
	{
		name = "rejects a malformed payload (missing/invalid ItemId or Amount)",
		run = function()
			local cases = {
				{ ItemId = "", Amount = 1 },
				{ Amount = 1 },
				{ ItemId = "ChiliPepper" },
				{ ItemId = "ChiliPepper", Amount = -1 },
				{ ItemId = "ChiliPepper", Amount = 1.5 },
				{ ItemId = "ChiliPepper", Amount = "2" },
			}

			for _, payload in cases do
				local profile = freshProfile(100)
				local ok = runFullTransaction(profile, payload)
				Check.isFalse(ok)
				Check.equal(profile.gold, 100)
			end
		end,
	},
	{
		name = "Stage does not mutate the profile even though it computes new values",
		run = function()
			local profile = freshProfile(100)
			local ok, staged =
				BuyFoodRules.Stage(FOOD_SHOP_CONFIG, ECONOMY_CONFIG, profile, { ItemId = "ChiliPepper", Amount = 2 })

			Check.isTrue(ok)
			Check.equal(profile.gold, 100) -- unchanged until Commit
			Check.equal(next(profile.inventory), nil) -- unchanged until Commit
			Check.equal(staged.NewGold, 80)
		end,
	},
})

process.exit(if passed then 0 else 1)
