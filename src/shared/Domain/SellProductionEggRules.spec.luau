local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local SellProductionEggRules = require("./SellProductionEggRules")
local TransactionCode = require("./TransactionCode")

local EGG_CONFIG = {
	productionVariants = {
		Normal = { goldMultiplier = 1.0, baseSellValue = 2 },
		Mini = { goldMultiplier = 0.7, baseSellValue = 1 },
		Heavy = { goldMultiplier = 2.0, baseSellValue = 4 },
		Giant = { goldMultiplier = 3.0, baseSellValue = 6 },
		Golden = { goldMultiplier = 5.0, baseSellValue = 10 },
	},
}

local DRAGON_CONFIG = {
	rarities = {
		Common = { productionMultiplier = 1 },
		Rare = { productionMultiplier = 3 },
		Epic = { productionMultiplier = 8 },
		Legendary = { productionMultiplier = 25 },
		Mythic = { productionMultiplier = 100 },
	},
}

local ECONOMY_CONFIG = { startingGold = 0, maxGold = 1000000, maxInventoryStack = 999999 }

local function zeroInventory()
	return {
		Common = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 },
		Rare = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 },
		Epic = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 },
		Legendary = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 },
		Mythic = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 },
	}
end

local function profileWithInventory(gold: number, overrides: { [string]: any }?)
	local inventory = zeroInventory()
	if overrides then
		for rarity, bucket in overrides do
			for variant, count in bucket do
				inventory[rarity][variant] = count
			end
		end
	end
	return {
		gold = gold,
		inventory = {},
		productionEggInventory = inventory,
		meta = { schemaVersion = 1, session = { jobId = nil, updatedAt = 0 } },
	}
end

local function runFullTransaction(profile, payload)
	local validateOk, validateCode = SellProductionEggRules.Validate(payload)
	if not validateOk then
		return false, validateCode
	end

	local stageOk, staged, stageCode = SellProductionEggRules.Stage(EGG_CONFIG, DRAGON_CONFIG, ECONOMY_CONFIG, profile)
	if not stageOk then
		return false, stageCode
	end

	local resultData = SellProductionEggRules.Commit(profile, staged)
	return true, resultData
end

local passed = Check.runAll({
	{
		name = "a Normal egg from a Common dragon sells for the 2-gold GDD baseline",
		run = function()
			local profile = profileWithInventory(0, { Common = { Normal = 1 } })
			local ok, resultData = runFullTransaction(profile, {})

			Check.isTrue(ok)
			Check.equal(resultData.TotalGold, 2)
			Check.equal(profile.gold, 2)
		end,
	},
	{
		name = "a Golden egg from a Mythic dragon sells for the 1,000-gold GDD jackpot number",
		run = function()
			local profile = profileWithInventory(0, { Mythic = { Golden = 1 } })
			local ok, resultData = runFullTransaction(profile, {})

			Check.isTrue(ok)
			Check.equal(resultData.TotalGold, 1000)
		end,
	},
	{
		name = "the same variant from different-rarity dragons is valued independently, not merged at one price",
		run = function()
			local profile = profileWithInventory(0, {
				Common = { Normal = 1 }, -- 2 gold
				Rare = { Normal = 1 }, -- 6 gold (2 x 3x)
			})
			local ok, resultData = runFullTransaction(profile, {})

			Check.isTrue(ok)
			Check.equal(resultData.TotalGold, 8)
			Check.equal(#resultData.SoldLineItems, 2)
		end,
	},
	{
		name = "sells the entire inventory at once and clears every bucket back to zero",
		run = function()
			local profile = profileWithInventory(50, {
				Common = { Normal = 3, Golden = 1 }, -- 3*2 + 1*10 = 16
				Epic = { Heavy = 2 }, -- 2*4*8 = 64
			})
			local ok, resultData = runFullTransaction(profile, {})

			Check.isTrue(ok)
			Check.equal(resultData.TotalGold, 80)
			Check.equal(profile.gold, 130)
			Check.equal(profile.productionEggInventory.Common.Normal, 0)
			Check.equal(profile.productionEggInventory.Common.Golden, 0)
			Check.equal(profile.productionEggInventory.Epic.Heavy, 0)
		end,
	},
	{
		name = "rejects selling an entirely empty inventory with NothingToSell, and does not touch gold",
		run = function()
			local profile = profileWithInventory(50)
			local ok, code = runFullTransaction(profile, {})

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.NothingToSell)
			Check.equal(profile.gold, 50)
		end,
	},
	{
		name = "caps the granted gold at maxGold rather than overflowing",
		run = function()
			local profile = profileWithInventory(0, { Mythic = { Golden = 1 } }) -- 1000 gold
			profile.gold = 999999999
			local ok, resultData = runFullTransaction(profile, {})

			Check.isTrue(ok)
			Check.equal(profile.gold, ECONOMY_CONFIG.maxGold)
			Check.equal(resultData.RemainingGold, ECONOMY_CONFIG.maxGold)
		end,
	},
	{
		name = "rejects a non-table payload with InvalidRequest",
		run = function()
			local ok, code = runFullTransaction(profileWithInventory(0), "not a table")

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.InvalidRequest)
		end,
	},
	{
		name = "Stage does not mutate the profile even though it computes new values",
		run = function()
			local profile = profileWithInventory(0, { Common = { Normal = 1 } })
			local ok, staged = SellProductionEggRules.Stage(EGG_CONFIG, DRAGON_CONFIG, ECONOMY_CONFIG, profile)

			Check.isTrue(ok)
			Check.equal(profile.gold, 0) -- unchanged until Commit
			Check.equal(profile.productionEggInventory.Common.Normal, 1) -- unchanged until Commit
			Check.equal(staged.TotalGold, 2)
		end,
	},
})

process.exit(if passed then 0 else 1)
