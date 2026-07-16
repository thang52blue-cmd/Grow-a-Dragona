local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local CollectNestRules = require("./CollectNestRules")
local TransactionCode = require("./TransactionCode")

local PRODUCTION_CONFIG = { productionIntervalSeconds = 180, nestCapacity = 12, startingFarmSlots = 3 }

local function profileWithSlot(slotOverrides: { [string]: any }?, eggInventoryOverrides: { [string]: any }?)
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

	local inventory = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 }
	if eggInventoryOverrides then
		for k, v in eggInventoryOverrides do
			inventory[k] = v
		end
	end

	return {
		gold = 0,
		inventory = {},
		pendingHatches = {},
		dragons = {},
		farmSlots = { [1] = slot },
		productionEggInventory = inventory,
		meta = { schemaVersion = 1, session = { jobId = nil, updatedAt = 0 }, nextEntityId = 1 },
	}
end

local function runFullTransaction(profile, payload, now: number)
	local validateOk, validateCode = CollectNestRules.Validate(payload)
	if not validateOk then
		return false, validateCode
	end

	local stageOk, staged, stageCode = CollectNestRules.Stage(PRODUCTION_CONFIG, profile, payload, now)
	if not stageOk then
		return false, stageCode
	end

	local resultData = CollectNestRules.Commit(profile, staged)
	return true, resultData
end

local passed = Check.runAll({
	{
		name = "collects all completed cycles' eggs as Normal and resets the Nest",
		run = function()
			local profile = profileWithSlot()
			local ok, resultData = runFullTransaction(profile, { SlotId = 1 }, 1000 + 180 * 3)

			Check.isTrue(ok)
			Check.equal(resultData.EggsCollected, 3)
			Check.equal(resultData.Variant, "Normal")
			Check.equal(profile.productionEggInventory.Normal, 3)
			Check.equal(profile.farmSlots[1].UncollectedEggCount, 0)
			Check.equal(profile.farmSlots[1].ProductionStartedAt, 1000 + 180 * 3)
			Check.isFalse(profile.farmSlots[1].IsProductionPaused)
		end,
	},
	{
		name = "adds to (does not overwrite) an existing Production Egg Inventory balance",
		run = function()
			local profile = profileWithSlot(nil, { Normal = 5 })
			local ok, resultData = runFullTransaction(profile, { SlotId = 1 }, 1000 + 180)

			Check.isTrue(ok)
			Check.equal(resultData.EggsCollected, 1)
			Check.equal(profile.productionEggInventory.Normal, 6)
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
			Check.equal(profile.productionEggInventory.Normal, 0)
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
		name = "a duplicated Collect request applied twice rejects the second with NestEmpty",
		run = function()
			local profile = profileWithSlot()
			local ok1 = runFullTransaction(profile, { SlotId = 1 }, 1000 + 180 * 2)
			local ok2, code2 = runFullTransaction(profile, { SlotId = 1 }, 1000 + 180 * 2)

			Check.isTrue(ok1)
			Check.isFalse(ok2)
			Check.equal(code2, TransactionCode.NestEmpty)
			Check.equal(profile.productionEggInventory.Normal, 2)
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
			local ok, staged = CollectNestRules.Stage(PRODUCTION_CONFIG, profile, { SlotId = 1 }, 1000 + 180)

			Check.isTrue(ok)
			Check.equal(profile.farmSlots[1].UncollectedEggCount, 0) -- read via Advance, not mutated
			Check.equal(profile.productionEggInventory.Normal, 0) -- unchanged until Commit
			Check.equal(staged.EggsCollected, 1)
		end,
	},
})

process.exit(if passed then 0 else 1)
