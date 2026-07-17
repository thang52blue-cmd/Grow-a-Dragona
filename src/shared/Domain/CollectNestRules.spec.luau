local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local CollectNestRules = require("./CollectNestRules")
local TransactionCode = require("./TransactionCode")

-- Common odds all land on Normal for rollValue = 0 (Normal is first in Variants.List and has a
-- positive weight), so tests that don't care about variant mix can pass an all-zero rolls array
-- and still assert a plain "everything is Normal" outcome, same as the pre-variant-roll behavior.
local ODDS_ALL_NORMAL_AT_ZERO = { Normal = 0.6, Mini = 0.25, Heavy = 0.1, Giant = 0.04, Golden = 0.01 }

local PRODUCTION_CONFIG = {
	productionIntervalSeconds = 180,
	nestCapacity = 12,
	startingFarmSlots = 3,
	variantOddsByRarity = {
		Common = ODDS_ALL_NORMAL_AT_ZERO,
		Rare = ODDS_ALL_NORMAL_AT_ZERO,
		Epic = ODDS_ALL_NORMAL_AT_ZERO,
		Legendary = ODDS_ALL_NORMAL_AT_ZERO,
		Mythic = ODDS_ALL_NORMAL_AT_ZERO,
	},
}

local function zeroInventoryByRarity()
	return {
		Common = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 },
		Rare = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 },
		Epic = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 },
		Legendary = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 },
		Mythic = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 },
	}
end

local function allZeroRolls()
	local rolls = {}
	for _ = 1, PRODUCTION_CONFIG.nestCapacity do
		table.insert(rolls, 0)
	end
	return rolls
end

local function profileWithSlot(
	slotOverrides: { [string]: any }?,
	dragonRarity: string?,
	inventoryOverrides: { [string]: any }?
)
	local slot = {
		SlotId = 1,
		AssignedDragonUID = "dragon-1",
		ProductionStartedAt = 1000,
		UncollectedEggCount = 0,
		IsProductionPaused = false,
	}
	if slotOverrides then
		for k, v in slotOverrides do
			slot[k] = v
		end
	end

	local inventory = zeroInventoryByRarity()
	if inventoryOverrides then
		for rarity, bucket in inventoryOverrides do
			inventory[rarity] = bucket
		end
	end

	return {
		gold = 0,
		inventory = {},
		pendingHatches = {},
		dragons = {
			["dragon-1"] = {
				Id = "dragon-1",
				Rarity = dragonRarity or "Common",
				Element = "Fire",
				GrowthStage = "Adult",
				FeedCount = 4,
				HatchedAt = 0,
				AssignedSlotId = 1,
			},
		},
		farmSlots = { [1] = slot },
		productionEggInventory = inventory,
		meta = { schemaVersion = 1, session = { jobId = nil, updatedAt = 0 }, nextEntityId = 2 },
	}
end

local function runFullTransaction(profile, payload, now: number, rollValues: { number }?)
	local validateOk, validateCode = CollectNestRules.Validate(payload)
	if not validateOk then
		return false, validateCode
	end

	local stageOk, staged, stageCode =
		CollectNestRules.Stage(PRODUCTION_CONFIG, profile, payload, now, rollValues or allZeroRolls())
	if not stageOk then
		return false, stageCode
	end

	local resultData = CollectNestRules.Commit(profile, staged)
	return true, resultData
end

local passed = Check.runAll({
	{
		name = "collects all completed cycles' eggs (rollValue 0 -> Normal) and resets the Nest",
		run = function()
			local profile = profileWithSlot()
			local ok, resultData = runFullTransaction(profile, { SlotId = 1 }, 1000 + 180 * 3)

			Check.isTrue(ok)
			Check.equal(resultData.EggsCollected, 3)
			Check.equal(resultData.VariantCounts.Normal, 3)
			Check.equal(profile.productionEggInventory.Common.Normal, 3)
			Check.equal(profile.farmSlots[1].UncollectedEggCount, 0)
			Check.equal(profile.farmSlots[1].ProductionStartedAt, 1000 + 180 * 3)
			Check.isFalse(profile.farmSlots[1].IsProductionPaused)
		end,
	},
	{
		name = "rolls each egg's variant independently against the laying dragon's rarity odds",
		run = function()
			-- Odds: Normal .6, Mini .25 (cumulative .85), Heavy .1 (cumulative .95), Giant .04
			-- (cumulative .99), Golden .01 (cumulative 1.0). Craft one rollValue per bucket.
			local profile = profileWithSlot()
			local rolls = { 0.1, 0.7, 0.9, 0.96, 0.995 }
			for _ = 6, PRODUCTION_CONFIG.nestCapacity do
				table.insert(rolls, 0)
			end
			local ok, resultData = runFullTransaction(profile, { SlotId = 1 }, 1000 + 180 * 5, rolls)

			Check.isTrue(ok)
			Check.equal(resultData.EggsCollected, 5)
			Check.equal(resultData.VariantCounts.Normal, 1)
			Check.equal(resultData.VariantCounts.Mini, 1)
			Check.equal(resultData.VariantCounts.Heavy, 1)
			Check.equal(resultData.VariantCounts.Giant, 1)
			Check.equal(resultData.VariantCounts.Golden, 1)
			Check.equal(profile.productionEggInventory.Common.Golden, 1)
		end,
	},
	{
		name = "credits the laying dragon's own Rarity bucket, not a flat/shared one",
		run = function()
			local profile = profileWithSlot(nil, "Mythic")
			local ok, resultData = runFullTransaction(profile, { SlotId = 1 }, 1000 + 180)

			Check.isTrue(ok)
			Check.equal(resultData.EggsCollected, 1)
			Check.equal(profile.productionEggInventory.Mythic.Normal, 1)
			Check.equal(profile.productionEggInventory.Common.Normal, 0)
		end,
	},
	{
		name = "adds to (does not overwrite) an existing Production Egg Inventory balance",
		run = function()
			local profile =
				profileWithSlot(nil, nil, { Common = { Normal = 5, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 } })
			local ok, resultData = runFullTransaction(profile, { SlotId = 1 }, 1000 + 180)

			Check.isTrue(ok)
			Check.equal(resultData.EggsCollected, 1)
			Check.equal(profile.productionEggInventory.Common.Normal, 6)
		end,
	},
	{
		name = "clears IsProductionPaused on collection, resuming production",
		run = function()
			local profile = profileWithSlot({ UncollectedEggCount = 12, IsProductionPaused = true })
			local ok = runFullTransaction(profile, { SlotId = 1 }, 1000 + 180)

			Check.isTrue(ok)
			Check.isFalse(profile.farmSlots[1].IsProductionPaused)
			Check.equal(profile.farmSlots[1].UncollectedEggCount, 0)
		end,
	},
	{
		name = "rejects collecting an empty Nest with NestEmpty, and does not touch inventory",
		run = function()
			local profile = profileWithSlot()
			local ok, code = runFullTransaction(profile, { SlotId = 1 }, 1000) -- no time elapsed

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.NestEmpty)
			Check.equal(profile.productionEggInventory.Common.Normal, 0)
		end,
	},
	{
		name = "rejects an unknown SlotId with SlotNotFound",
		run = function()
			local profile = profileWithSlot()
			local ok, code = runFullTransaction(profile, { SlotId = 99 }, 1000 + 180)

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.SlotNotFound)
		end,
	},
	{
		name = "rejects a slot whose AssignedDragonUID no longer exists with DragonNotFound",
		run = function()
			local profile = profileWithSlot()
			profile.dragons["dragon-1"] = nil
			local ok, code = runFullTransaction(profile, { SlotId = 1 }, 1000 + 180)

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.DragonNotFound)
		end,
	},
	{
		name = "a duplicated Collect request applied twice rejects the second with NestEmpty",
		run = function()
			local profile = profileWithSlot()
			local ok1 = runFullTransaction(profile, { SlotId = 1 }, 1000 + 180 * 2)
			local ok2, code2 = runFullTransaction(profile, { SlotId = 1 }, 1000 + 180 * 2)

			Check.isTrue(ok1)
			Check.isFalse(ok2)
			Check.equal(code2, TransactionCode.NestEmpty)
			Check.equal(profile.productionEggInventory.Common.Normal, 2)
		end,
	},
	{
		name = "rejects a malformed payload (missing/wrong-type SlotId)",
		run = function()
			local profile = profileWithSlot()
			local ok1, code1 = runFullTransaction(profile, {}, 1000)
			local ok2, code2 = runFullTransaction(profile, { SlotId = "1" }, 1000)

			Check.isFalse(ok1)
			Check.equal(code1, TransactionCode.InvalidRequest)
			Check.isFalse(ok2)
			Check.equal(code2, TransactionCode.InvalidRequest)
		end,
	},
	{
		name = "Stage does not mutate the profile even though it computes new values",
		run = function()
			local profile = profileWithSlot()
			local ok, staged =
				CollectNestRules.Stage(PRODUCTION_CONFIG, profile, { SlotId = 1 }, 1000 + 180, allZeroRolls())

			Check.isTrue(ok)
			Check.equal(profile.farmSlots[1].UncollectedEggCount, 0) -- read via Advance, not mutated
			Check.equal(profile.productionEggInventory.Common.Normal, 0) -- unchanged until Commit
			Check.equal(staged.EggsCollected, 1)
		end,
	},
})

process.exit(if passed then 0 else 1)
