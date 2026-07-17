local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local SendToStorageRules = require("./SendToStorageRules")
local TransactionCode = require("./TransactionCode")

local function baseProfile(dragonOverrides: { [string]: any }?, slotOverrides: { [string]: any }?)
	local dragon = {
		Id = "1",
		Rarity = "Common",
		Element = "Fire",
		GrowthStage = "Adult",
		FeedCount = 4,
		HatchedAt = 0,
		AssignedSlotId = 1,
	}
	if dragonOverrides then
		for k, v in dragonOverrides do
			dragon[k] = v
		end
	end

	local slot = {
		SlotId = 1,
		AssignedDragonUID = "1",
		ProductionStartedAt = 500,
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

local function runFullTransaction(profile, payload)
	local validateOk, validateCode = SendToStorageRules.Validate(payload)
	if not validateOk then
		return false, validateCode
	end

	local stageOk, staged, stageCode = SendToStorageRules.Stage(profile, payload, 1000)
	if not stageOk then
		return false, stageCode
	end

	local resultData = SendToStorageRules.Commit(profile, staged)
	return true, resultData
end

local passed = Check.runAll({
	{
		name = "sends the slot's dragon back to Storage and clears the slot",
		run = function()
			local profile = baseProfile()
			local ok, resultData = runFullTransaction(profile, { SlotId = 1 })

			Check.isTrue(ok)
			Check.equal(resultData.DragonUID, "1")
			Check.equal(resultData.SlotId, 1)
			Check.equal(profile.dragons["1"].AssignedSlotId, nil)
			Check.equal(profile.farmSlots[1].AssignedDragonUID, nil)
			Check.equal(profile.farmSlots[1].ProductionStartedAt, nil)
			Check.isFalse(profile.farmSlots[1].IsProductionPaused)
		end,
	},
	{
		name = "the dragon is not deleted, only unassigned",
		run = function()
			local profile = baseProfile()
			runFullTransaction(profile, { SlotId = 1 })

			Check.isTrue(profile.dragons["1"] ~= nil)
			Check.equal(profile.dragons["1"].Rarity, "Common")
		end,
	},
	{
		name = "rejects an unknown SlotId with SlotNotFound",
		run = function()
			local profile = baseProfile()
			local ok, code = runFullTransaction(profile, { SlotId = 99 })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.SlotNotFound)
		end,
	},
	{
		name = "rejects an already-empty slot with NoDragonInSlot",
		run = function()
			-- Table-literal overrides can't express "set this key to nil" (an absent key
			-- leaves the base value unchanged, see baseProfile's merge loop), so this one
			-- case builds the empty-slot profile directly instead of via slotOverrides.
			local profile = baseProfile()
			profile.farmSlots[1] = {
				SlotId = 1,
				AssignedDragonUID = nil,
				ProductionStartedAt = nil,
				UncollectedEggCount = 0,
				IsProductionPaused = false,
			}
			local ok, code = runFullTransaction(profile, { SlotId = 1 })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.NoDragonInSlot)
		end,
	},
	{
		name = "rejects while the Nest still has uncollected eggs (would strand them) with NestNotEmpty",
		run = function()
			local profile = baseProfile(nil, { UncollectedEggCount = 3 })
			local ok, code = runFullTransaction(profile, { SlotId = 1 })

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.NestNotEmpty)
			-- and the dragon/slot pointers are untouched -- no eggs get stranded
			Check.equal(profile.dragons["1"].AssignedSlotId, 1)
			Check.equal(profile.farmSlots[1].AssignedDragonUID, "1")
		end,
	},
	{
		name = "rejects a malformed payload (missing/wrong-type SlotId)",
		run = function()
			local profile = baseProfile()
			local ok1, code1 = runFullTransaction(profile, {})
			local ok2, code2 = runFullTransaction(profile, { SlotId = "1" })

			Check.isFalse(ok1)
			Check.equal(code1, TransactionCode.InvalidRequest)
			Check.isFalse(ok2)
			Check.equal(code2, TransactionCode.InvalidRequest)
		end,
	},
	{
		name = "a duplicated SendToStorage request applied twice rejects the second with NoDragonInSlot",
		run = function()
			local profile = baseProfile()
			local ok1 = runFullTransaction(profile, { SlotId = 1 })
			local ok2, code2 = runFullTransaction(profile, { SlotId = 1 })

			Check.isTrue(ok1)
			Check.isFalse(ok2)
			Check.equal(code2, TransactionCode.NoDragonInSlot)
		end,
	},
	{
		name = "Stage does not mutate the profile even though it computes new values",
		run = function()
			local profile = baseProfile()
			local ok, staged = SendToStorageRules.Stage(profile, { SlotId = 1 }, 1000)

			Check.isTrue(ok)
			Check.equal(profile.dragons["1"].AssignedSlotId, 1) -- unchanged until Commit
			Check.equal(profile.farmSlots[1].AssignedDragonUID, "1") -- unchanged until Commit
			Check.equal(staged.DragonUID, "1")
		end,
	},
})

process.exit(if passed then 0 else 1)
