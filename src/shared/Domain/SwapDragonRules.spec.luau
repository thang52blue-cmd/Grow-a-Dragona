local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local SwapDragonRules = require("./SwapDragonRules")
local TransactionCode = require("./TransactionCode")

local function baseProfile(overrides: { dragons: { [string]: any }?, slot: { [string]: any }? }?)
	local oldDragon = {
		Id = "1",
		Rarity = "Common",
		Element = "Fire",
		GrowthStage = "Adult",
		FeedCount = 4,
		HatchedAt = 0,
		AssignedSlotId = 1,
	}
	local newDragon = {
		Id = "2",
		Rarity = "Rare",
		Element = "Water",
		GrowthStage = "Baby_2",
		FeedCount = 2,
		HatchedAt = 10,
		AssignedSlotId = nil,
	}
	local slot = {
		SlotId = 1,
		AssignedDragonUID = "1",
		ProductionStartedAt = 500,
		UncollectedEggCount = 0,
		IsProductionPaused = false,
	}

	local dragons = { ["1"] = oldDragon, ["2"] = newDragon }
	if overrides and overrides.dragons then
		for uid, dragonOverrides in overrides.dragons do
			for k, v in dragonOverrides do
				dragons[uid][k] = v
			end
		end
	end
	if overrides and overrides.slot then
		for k, v in overrides.slot do
			slot[k] = v
		end
	end

	return {
		gold = 0,
		inventory = {},
		pendingHatches = {},
		dragons = dragons,
		farmSlots = { [1] = slot },
		productionEggInventory = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 },
		meta = { schemaVersion = 1, session = { jobId = nil, updatedAt = 0 }, nextEntityId = 3 },
	}
end

local function runFullTransaction(profile, payload, now: number?)
	local validateOk, validateCode = SwapDragonRules.Validate(payload)
	if not validateOk then
		return false, validateCode
	end

	local stageOk, staged, stageCode = SwapDragonRules.Stage(profile, payload, now or 1000)
	if not stageOk then
		return false, stageCode
	end

	local resultData = SwapDragonRules.Commit(profile, staged)
	return true, resultData
end

local passed = Check.runAll({
	{
		name = "atomically swaps: old dragon returns to Storage, new (Baby) dragon takes the slot with no production",
		run = function()
			local profile = baseProfile()
			local ok, resultData = runFullTransaction(profile, { SlotId = 1, NewDragonUID = "2" }, 5000)

			Check.isTrue(ok)
			Check.equal(resultData.OldDragonUID, "1")
			Check.equal(resultData.NewDragonUID, "2")
			Check.equal(resultData.SlotId, 1)
			Check.equal(profile.dragons["1"].AssignedSlotId, nil)
			Check.equal(profile.dragons["2"].AssignedSlotId, 1)
			Check.equal(profile.farmSlots[1].AssignedDragonUID, "2")
			Check.equal(profile.farmSlots[1].ProductionStartedAt, nil)
		end,
	},
	{
		name = "swapping in an Adult starts production at `now`",
		run = function()
			local profile = baseProfile({ dragons = { ["2"] = { GrowthStage = "Adult" } } })
			local ok = runFullTransaction(profile, { SlotId = 1, NewDragonUID = "2" }, 5000)

			Check.isTrue(ok)
			Check.equal(profile.farmSlots[1].ProductionStartedAt, 5000)
		end,
	},
	{
		name = "neither dragon is lost or duplicated -- both still exist, exactly one assigned to the slot",
		run = function()
			local profile = baseProfile()
			runFullTransaction(profile, { SlotId = 1, NewDragonUID = "2" })

			local assignedCount = 0
			for _, dragon in profile.dragons do
				if dragon.AssignedSlotId == 1 then
					assignedCount += 1
				end
			end
			Check.equal(assignedCount, 1)
			Check.isTrue(profile.dragons["1"] ~= nil)
			Check.isTrue(profile.dragons["2"] ~= nil)
		end,
	},
	{
		name = "rejects an unknown SlotId with SlotNotFound",
		run = function()
			local profile = baseProfile()
			local ok, code = runFullTransaction(profile, { SlotId = 99, NewDragonUID = "2" })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.SlotNotFound)
		end,
	},
	{
		name = "rejects an already-empty slot with NoDragonInSlot",
		run = function()
			local profile = baseProfile()
			profile.farmSlots[1] = {
				SlotId = 1,
				AssignedDragonUID = nil,
				ProductionStartedAt = nil,
				UncollectedEggCount = 0,
				IsProductionPaused = false,
			}
			local ok, code = runFullTransaction(profile, { SlotId = 1, NewDragonUID = "2" })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.NoDragonInSlot)
		end,
	},
	{
		name = "rejects while the Nest still has uncollected eggs with NestNotEmpty",
		run = function()
			local profile = baseProfile({ slot = { UncollectedEggCount = 4 } })
			local ok, code = runFullTransaction(profile, { SlotId = 1, NewDragonUID = "2" })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.NestNotEmpty)
		end,
	},
	{
		name = "rejects an unknown NewDragonUID with DragonNotFound",
		run = function()
			local profile = baseProfile()
			local ok, code = runFullTransaction(profile, { SlotId = 1, NewDragonUID = "does-not-exist" })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.DragonNotFound)
		end,
	},
	{
		name = "rejects a NewDragonUID that isn't in Storage (already assigned elsewhere) with DragonAlreadyAssigned",
		run = function()
			local profile = baseProfile({ dragons = { ["2"] = { AssignedSlotId = 2 } } })
			local ok, code = runFullTransaction(profile, { SlotId = 1, NewDragonUID = "2" })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.DragonAlreadyAssigned)
		end,
	},
	{
		name = "rejects passing the slot's own current occupant as NewDragonUID (not in Storage) with DragonAlreadyAssigned",
		run = function()
			local profile = baseProfile()
			local ok, code = runFullTransaction(profile, { SlotId = 1, NewDragonUID = "1" })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.DragonAlreadyAssigned)
		end,
	},
	{
		name = "rejects a malformed payload (missing/wrong-type SlotId or NewDragonUID)",
		run = function()
			local profile = baseProfile()
			local ok1, code1 = runFullTransaction(profile, { NewDragonUID = "2" })
			local ok2, code2 = runFullTransaction(profile, { SlotId = 1 })
			local ok3, code3 = runFullTransaction(profile, { SlotId = "1", NewDragonUID = "2" })

			Check.isFalse(ok1)
			Check.equal(code1, TransactionCode.InvalidRequest)
			Check.isFalse(ok2)
			Check.equal(code2, TransactionCode.InvalidRequest)
			Check.isFalse(ok3)
			Check.equal(code3, TransactionCode.InvalidRequest)
		end,
	},
	{
		name = "Stage does not mutate the profile even though it computes new values",
		run = function()
			local profile = baseProfile()
			local ok, staged = SwapDragonRules.Stage(profile, { SlotId = 1, NewDragonUID = "2" }, 5000)

			Check.isTrue(ok)
			Check.equal(profile.dragons["1"].AssignedSlotId, 1) -- unchanged until Commit
			Check.equal(profile.dragons["2"].AssignedSlotId, nil) -- unchanged until Commit
			Check.equal(staged.NewDragonUID, "2")
		end,
	},
})

process.exit(if passed then 0 else 1)
