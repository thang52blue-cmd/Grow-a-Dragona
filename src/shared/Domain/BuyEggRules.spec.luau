local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local BuyEggRules = require("./BuyEggRules")

local EGG_CONFIG = {
	hatchingTiers = {
		Common = { goldPrice = 100, odds = {}, enabled = true, maxPurchaseAmount = 10 },
		Rare = { goldPrice = 500, odds = {}, enabled = true, maxPurchaseAmount = 5 },
		Epic = { goldPrice = 10, odds = {}, enabled = false, maxPurchaseAmount = 10 },
	},
	productionVariants = {},
}

local ECONOMY_CONFIG = { startingGold = 0, maxGold = 1000000, maxInventoryStack = 999999 }

local function freshProfile(gold: number, inventory: { [string]: number }?)
	return {
		gold = gold,
		inventory = inventory or {},
		meta = { schemaVersion = 1, session = { jobId = nil, updatedAt = 0 } },
	}
end

local function runFullTransaction(profile, payload)
	local validateOk, validateCode = BuyEggRules.Validate(EGG_CONFIG, payload)
	if not validateOk then
		return false, validateCode
	end

	local stageOk, staged, stageCode = BuyEggRules.Stage(EGG_CONFIG, ECONOMY_CONFIG, profile, payload)
	if not stageOk then
		return false, stageCode
	end

	local resultData = BuyEggRules.Commit(profile, staged)
	return true, resultData
end

local passed = Check.runAll({
	{
		name = "Test 1: successful purchase deducts gold and grants eggs atomically",
		run = function()
			local profile = freshProfile(1000)
			local ok, resultData = runFullTransaction(profile, { Rarity = "Common", Amount = 2 })

			Check.isTrue(ok)
			Check.equal(profile.gold, 800)
			Check.equal(profile.inventory.HatchEgg_Common, 2)
			Check.equal(resultData.TotalPrice, 200)
			Check.equal(resultData.RemainingGold, 800)
			Check.equal(resultData.NewEggAmount, 2)
		end,
	},
	{
		name = "Test 2: buying into an existing stack adds to it instead of creating a second one",
		run = function()
			local profile = freshProfile(1000, { HatchEgg_Common = 3 })
			local ok = runFullTransaction(profile, { Rarity = "Common", Amount = 2 })

			Check.isTrue(ok)
			Check.equal(profile.inventory.HatchEgg_Common, 5)
			Check.equal(next(profile.inventory, next(profile.inventory)), nil) -- only one key
		end,
	},
	{
		name = "Test 3: insufficient gold rejects and leaves gold/inventory untouched",
		run = function()
			local profile = freshProfile(50)
			local ok, code = runFullTransaction(profile, { Rarity = "Common", Amount = 1 })

			Check.isFalse(ok)
			Check.equal(code, require("./TransactionCode").NotEnoughCurrency)
			Check.equal(profile.gold, 50)
			Check.equal(next(profile.inventory), nil)
		end,
	},
	{
		name = "Test 4: malformed payloads are rejected without touching the profile",
		run = function()
			local TransactionCode = require("./TransactionCode")
			local cases = {
				{ Rarity = "Common", Amount = -1 },
				{ Rarity = "Common", Amount = 0 },
				{ Rarity = "Common", Amount = 1.5 },
				{ Rarity = "Common", Amount = math.huge },
				{ Rarity = "Common", Amount = 0 / 0 },
				{ Rarity = "Common", Amount = 999999 },
				{ Rarity = "NotARarity", Amount = 1 },
				{ Rarity = "Common", Amount = "2" },
			}

			for _, payload in cases do
				local profile = freshProfile(1000)
				local ok, code = runFullTransaction(profile, payload)
				Check.isFalse(ok)
				Check.isTrue(code ~= nil and code ~= TransactionCode.Success)
				Check.equal(profile.gold, 1000)
				Check.equal(next(profile.inventory), nil)
			end
		end,
	},
	{
		name = "a disabled tier is rejected even with a valid amount and enough gold",
		run = function()
			local profile = freshProfile(1000)
			local ok, code = runFullTransaction(profile, { Rarity = "Epic", Amount = 1 })

			Check.isFalse(ok)
			Check.equal(code, require("./TransactionCode").EggDisabled)
			Check.equal(profile.gold, 1000)
		end,
	},
	{
		name = "an amount over the tier's maxPurchaseAmount is rejected",
		run = function()
			local profile = freshProfile(100000)
			local ok, code = runFullTransaction(profile, { Rarity = "Rare", Amount = 6 })

			Check.isFalse(ok)
			Check.equal(code, require("./TransactionCode").InvalidAmount)
		end,
	},
	{
		name = "Stage does not mutate the profile even though it computes new values",
		run = function()
			local profile = freshProfile(1000)
			local ok, staged = BuyEggRules.Stage(EGG_CONFIG, ECONOMY_CONFIG, profile, { Rarity = "Common", Amount = 3 })

			Check.isTrue(ok)
			Check.equal(profile.gold, 1000) -- unchanged until Commit
			Check.equal(next(profile.inventory), nil) -- unchanged until Commit
			Check.equal(staged.NewGold, 700)
		end,
	},
})

process.exit(if passed then 0 else 1)
