local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local ClaimHatchRules = require("./ClaimHatchRules")
local TransactionCode = require("./TransactionCode")

local EGG_CONFIG = {
	hatchingTiers = {
		Common = {
			goldPrice = 10,
			odds = { Common = 0.99, Rare = 0.01, Epic = 0, Legendary = 0, Mythic = 0 },
			enabled = true,
			maxPurchaseAmount = 50,
			hatchDurationSeconds = 5,
		},
	},
	productionVariants = {},
}

local DRAGON_CONFIG = {
	elements = {},
	elementOdds = { Fire = 0.2, Water = 0.2, Earth = 0.2, Light = 0.2, Dark = 0.2 },
	rarities = {},
}

local function emptyFarmSlots(count: number)
	local slots = {}
	for slotId = 1, count do
		slots[slotId] = {
			SlotId = slotId,
			AssignedDragonUID = nil,
			ProductionStartedAt = nil,
			UncollectedEggCount = 0,
			IsProductionPaused = false,
		}
	end
	return slots
end

-- Defaults to 2 open farm slots (today's real starter-plot size) so every existing test
-- that doesn't care about slot assignment still has somewhere for the auto-assign logic to
-- place the new dragon; pass farmSlots explicitly to test slot-assignment behavior itself.
local function profileWithPendingHatch(
	hatchId: string,
	rarity: string,
	finishAt: number,
	nextEntityId: number?,
	farmSlots: { [number]: any }?
)
	return {
		gold = 0,
		inventory = {},
		pendingHatches = {
			[hatchId] = { Id = hatchId, Rarity = rarity, StartedAt = finishAt - 5, FinishAt = finishAt },
		},
		dragons = {},
		farmSlots = farmSlots or emptyFarmSlots(2),
		meta = { schemaVersion = 1, session = { jobId = nil, updatedAt = 0 }, nextEntityId = nextEntityId or 1 },
	}
end

local function runFullTransaction(profile, payload, now, rarityRollValue, elementRollValue)
	local validateOk, validateCode = ClaimHatchRules.Validate(payload)
	if not validateOk then
		return false, validateCode
	end

	local stageOk, staged, stageCode =
		ClaimHatchRules.Stage(EGG_CONFIG, DRAGON_CONFIG, profile, payload, now, rarityRollValue, elementRollValue or 0)
	if not stageOk then
		return false, stageCode
	end

	local resultData = ClaimHatchRules.Commit(profile, staged)
	return true, resultData
end

local passed = Check.runAll({
	{
		name = "claiming a ready hatch grants exactly one dragon and consumes the pending hatch atomically",
		run = function()
			local profile = profileWithPendingHatch("1", "Common", 1005)
			local ok, resultData = runFullTransaction(profile, { HatchId = "1" }, 1005, 0)

			Check.isTrue(ok)
			Check.equal(resultData.DragonId, "1")
			Check.equal(resultData.Rarity, "Common") -- rollValue 0 lands in Common's bucket
			Check.equal(profile.dragons["1"].Rarity, "Common")
			Check.equal(profile.dragons["1"].Element, "Fire") -- elementRollValue 0 lands in Fire's bucket
			Check.equal(profile.dragons["1"].GrowthStage, "Baby_0")
			Check.equal(profile.dragons["1"].FeedCount, 0)
			Check.equal(next(profile.pendingHatches), nil)
			Check.equal(profile.meta.nextEntityId, 2)
		end,
	},
	{
		name = "the rolled dragon rarity comes from the hatched egg tier's own odds",
		run = function()
			local profile = profileWithPendingHatch("1", "Common", 1005)
			-- rollValue 0.999 is past Common's [0, .99) bucket -> lands in Rare
			local ok, resultData = runFullTransaction(profile, { HatchId = "1" }, 1005, 0.999)

			Check.isTrue(ok)
			Check.equal(resultData.Rarity, "Rare")
		end,
	},
	{
		name = "rejects with HatchNotReady when claimed before the server FinishAt, and leaves state untouched",
		run = function()
			local profile = profileWithPendingHatch("1", "Common", 1005)
			local ok, code = runFullTransaction(profile, { HatchId = "1" }, 1004, 0)

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.HatchNotReady)
			Check.equal(profile.pendingHatches["1"].Rarity, "Common")
			Check.equal(next(profile.dragons), nil)
		end,
	},
	{
		name = "rejects with NoHatchInProgress for an unknown HatchId",
		run = function()
			local profile = profileWithPendingHatch("1", "Common", 1005)
			local ok, code = runFullTransaction(profile, { HatchId = "does-not-exist" }, 1005, 0)

			Check.isFalse(ok)
			Check.equal(code, TransactionCode.NoHatchInProgress)
		end,
	},
	{
		name = "a second claim of the same HatchId after a successful claim cannot double-grant",
		run = function()
			local profile = profileWithPendingHatch("1", "Common", 1005)
			local ok1 = runFullTransaction(profile, { HatchId = "1" }, 1005, 0)
			local ok2, code2 = runFullTransaction(profile, { HatchId = "1" }, 1005, 0)

			Check.isTrue(ok1)
			Check.isFalse(ok2)
			Check.equal(code2, TransactionCode.NoHatchInProgress)
			Check.equal(next(profile.dragons, next(profile.dragons)), nil) -- still exactly one dragon
		end,
	},
	{
		name = "rejects a malformed payload (missing/empty HatchId) without touching the profile",
		run = function()
			local profile = profileWithPendingHatch("1", "Common", 1005)
			local ok1, code1 = runFullTransaction(profile, {}, 1005, 0)
			local ok2, code2 = runFullTransaction(profile, { HatchId = "" }, 1005, 0)

			Check.isFalse(ok1)
			Check.equal(code1, TransactionCode.InvalidRequest)
			Check.isFalse(ok2)
			Check.equal(code2, TransactionCode.InvalidRequest)
			Check.equal(profile.pendingHatches["1"].Rarity, "Common")
		end,
	},
	{
		name = "Stage does not mutate the profile even though it computes new values",
		run = function()
			local profile = profileWithPendingHatch("1", "Common", 1005)
			local ok, staged = ClaimHatchRules.Stage(EGG_CONFIG, DRAGON_CONFIG, profile, { HatchId = "1" }, 1005, 0, 0)

			Check.isTrue(ok)
			Check.equal(profile.pendingHatches["1"].Rarity, "Common") -- unchanged until Commit
			Check.equal(next(profile.dragons), nil) -- unchanged until Commit
			Check.equal(staged.DragonRarity, "Common")
		end,
	},
	{
		name = "a freshly-hatched dragon is auto-assigned to the first open Farm Slot, with production not yet started",
		run = function()
			local profile = profileWithPendingHatch("1", "Common", 1005)
			local ok, resultData = runFullTransaction(profile, { HatchId = "1" }, 1005, 0)

			Check.isTrue(ok)
			Check.equal(resultData.AssignedSlotId, 1)
			Check.equal(profile.dragons["1"].AssignedSlotId, 1)
			Check.equal(profile.farmSlots[1].AssignedDragonUID, "1")
			Check.equal(profile.farmSlots[1].ProductionStartedAt, nil)
			Check.equal(profile.farmSlots[2].AssignedDragonUID, nil) -- untouched
		end,
	},
	{
		name = "auto-assignment picks the lowest-numbered open slot, skipping an already-occupied one",
		run = function()
			local farmSlots = emptyFarmSlots(2)
			farmSlots[1].AssignedDragonUID = "existing-dragon"
			local profile = profileWithPendingHatch("1", "Common", 1005, nil, farmSlots)
			local ok, resultData = runFullTransaction(profile, { HatchId = "1" }, 1005, 0)

			Check.isTrue(ok)
			Check.equal(resultData.AssignedSlotId, 2)
			Check.equal(profile.dragons["1"].AssignedSlotId, 2)
			Check.equal(profile.farmSlots[2].AssignedDragonUID, "1")
		end,
	},
	{
		name = "a dragon still hatches successfully with no Farm Slot when every slot is already occupied",
		run = function()
			local farmSlots = emptyFarmSlots(1)
			farmSlots[1].AssignedDragonUID = "existing-dragon"
			local profile = profileWithPendingHatch("1", "Common", 1005, nil, farmSlots)
			local ok, resultData = runFullTransaction(profile, { HatchId = "1" }, 1005, 0)

			Check.isTrue(ok)
			Check.equal(resultData.AssignedSlotId, nil)
			Check.equal(profile.dragons["1"].AssignedSlotId, nil)
			Check.equal(profile.farmSlots[1].AssignedDragonUID, "existing-dragon") -- untouched
		end,
	},
})

process.exit(if passed then 0 else 1)
