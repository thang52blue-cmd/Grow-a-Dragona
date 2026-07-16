local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local AssignProducerRules = require("./AssignProducerRules")
local TransactionCode = require("./TransactionCode")

local function baseProfile(dragonOverrides: { [string]: any }?, slotOverrides: { [string]: any }?)
	local dragon = {
		Id = "1",
		Rarity = "Common",
		Element = "Fire",
		GrowthStage = "Adult",
		FeedCount = 4,
		HatchedAt = 0,
		AssignedSlotId = nil,
	}
	if dragonOverrides then
		for k, v in dragonOverrides do
			dragon[k] = v
		end
	end

	local slot = {
		SlotId = 1,
		AssignedDragonUID = nil,
		ProductionStartedAt = nil,
		UncollectedEggCount = 0,
		IsProductionPaused = false,
	}
	if slotOverrides then
		for k, v in slotOverrides do
			slot[k] = v
		end
	end

	return {
		gold = 0,
		inventory = {},
		pendingHatches = {},
		dragons = { ["1"] = dragon },
		farmSlots = { [1] = slot },
		productionEggInventory = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 },
		meta = { schemaVersion = 1, session = { jobId = nil, updatedAt = 0 }, nextEntityId = 2 },
	}
end

local function runFullTransaction(profile, payload, now: number?)
	local validateOk, validateCode = AssignProducerRules.Validate(payload)
	if not validateOk then
		return false, validateCode
	end

	local stageOk, staged, stageCode = AssignProducerRules.Stage(profile, payload, now or 1000)
	if not stageOk then
		return false, stageCode
	end

	local resultData = AssignProducerRules.Commit(profile, staged)
	return true, resultData
end

local passed = Check.runAll({
	{
		name = "assigns an owned Adult dragon to an empty slot and starts production at `now`",
		run = function()
			local profile = baseProfile()
			local ok, resultData = runFullTransaction(profile, { DragonUID = "1", SlotId = 1 }, 5000)

			Check.isTrue(ok)
			Check.equal(resultData.DragonUID, "1")
			Check.equal(resultData.SlotId, 1)
			Check.equal(profile.dragons["1"].AssignedSlotId, 1)
			Check.equal(profile.farmSlots[1].AssignedDragonUID, "1")
			Check.equal(profile.farmSlots[1].ProductionStartedAt, 5000)
			Check.equal(profile.farmSlots[1].UncollectedEggCount, 0)
			Check.isFalse(profile.farmSlots[1].IsProductionPaused)
		end,
	},
	{
		name = "rejects a Baby dragon with DragonNotAdult",
		run = function()
			local profile = baseProfile({ GrowthStage = "Baby_3", FeedCount = 3 })
			local ok, code = runFullTransaction(profile, { DragonUID = "1", SlotId = 1 })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.DragonNotAdult)
			Check.equal(profile.farmSlots[1].AssignedDragonUID, nil)
		end,
	},
	{
		name = "rejects a dragon already assigned to another slot with DragonAlreadyAssigned",
		run = function()
			local profile = baseProfile({ AssignedSlotId = 2 })
			local ok, code = runFullTransaction(profile, { DragonUID = "1", SlotId = 1 })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.DragonAlreadyAssigned)
		end,
	},
	{
		name = "rejects an unknown SlotId with SlotNotFound",
		run = function()
			local profile = baseProfile()
			local ok, code = runFullTransaction(profile, { DragonUID = "1", SlotId = 99 })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.SlotNotFound)
		end,
	},
	{
		name = "rejects an occupied slot with SlotOccupied, and a dragon cannot occupy two slots",
		run = function()
			local profile = baseProfile(nil, { AssignedDragonUID = "other-dragon" })
			local ok, code = runFullTransaction(profile, { DragonUID = "1", SlotId = 1 })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.SlotOccupied)
			Check.equal(profile.dragons["1"].AssignedSlotId, nil)
		end,
	},
	{
		name = "rejects an unknown DragonUID with DragonNotFound",
		run = function()
			local profile = baseProfile()
			local ok, code = runFullTransaction(profile, { DragonUID = "does-not-exist", SlotId = 1 })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.DragonNotFound)
		end,
	},
	{
		name = "rejects a malformed payload (missing/wrong-type DragonUID or SlotId)",
		run = function()
			local profile = baseProfile()
			local ok1, code1 = runFullTransaction(profile, { SlotId = 1 })
			local ok2, code2 = runFullTransaction(profile, { DragonUID = "1" })
			local ok3, code3 = runFullTransaction(profile, { DragonUID = "1", SlotId = "1" })

			Check.isFalse(ok1)
			Check.equal(code1, TransactionCode.InvalidRequest)
			Check.isFalse(ok2)
			Check.equal(code2, TransactionCode.InvalidRequest)
			Check.isFalse(ok3)
			Check.equal(code3, TransactionCode.InvalidRequest)
		end,
	},
	{
		name = "a duplicated Assign request applied twice rejects the second with DragonAlreadyAssigned",
		run = function()
			local profile = baseProfile()
			local ok1 = runFullTransaction(profile, { DragonUID = "1", SlotId = 1 })
			local ok2, code2 = runFullTransaction(profile, { DragonUID = "1", SlotId = 1 })

			Check.isTrue(ok1)
			Check.isFalse(ok2)
			Check.equal(code2, TransactionCode.DragonAlreadyAssigned)
		end,
	},
	{
		name = "Stage does not mutate the profile even though it computes new values",
		run = function()
			local profile = baseProfile()
			local ok, staged = AssignProducerRules.Stage(profile, { DragonUID = "1", SlotId = 1 }, 5000)

			Check.isTrue(ok)
			Check.equal(profile.dragons["1"].AssignedSlotId, nil) -- unchanged until Commit
			Check.equal(profile.farmSlots[1].AssignedDragonUID, nil) -- unchanged until Commit
			Check.equal(staged.SlotId, 1)
		end,
	},
})

process.exit(if passed then 0 else 1)
