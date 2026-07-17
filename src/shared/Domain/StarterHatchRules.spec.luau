local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local StarterHatchRules = require("./StarterHatchRules")

local EGG_CONFIG = {
	hatchingTiers = {
		Common = {
			goldPrice = 10,
			odds = { Common = 0.99, Rare = 0.01, Epic = 0, Legendary = 0, Mythic = 0 },
			enabled = true,
			maxPurchaseAmount = 50,
			hatchDurationSeconds = 0,
		},
	},
	productionVariants = {},
}

local POSITION = { X = 1, Y = 2, Z = 3 }

local function profileWithStarterGranted(granted: boolean, nextEntityId: number?)
	return {
		gold = 0,
		inventory = {},
		pendingHatches = {},
		dragons = {},
		farmSlots = {},
		meta = {
			schemaVersion = 1,
			session = { jobId = nil, updatedAt = 0 },
			nextEntityId = nextEntityId or 1,
			starterHatchGranted = granted,
		},
	}
end

local passed = Check.runAll({
	{
		name = "ShouldGrant is true for a fresh profile and false once already granted",
		run = function()
			Check.isTrue(StarterHatchRules.ShouldGrant(profileWithStarterGranted(false)))
			Check.isFalse(StarterHatchRules.ShouldGrant(profileWithStarterGranted(true)))
		end,
	},
	{
		name = "Stage rolls the rarity from the Common tier's own odds and computes FinishAt from its duration",
		run = function()
			local profile = profileWithStarterGranted(false)
			local staged = StarterHatchRules.Stage(EGG_CONFIG, profile, 1000, POSITION, 0)

			Check.equal(staged.Rarity, "Common") -- rollValue 0 lands in Common's bucket
			Check.equal(staged.StartedAt, 1000)
			Check.equal(staged.FinishAt, 1000) -- hatchDurationSeconds is 0
			Check.equal(staged.Position.X, 1)
			Check.equal(staged.NewNextEntityId, 2)
			-- unchanged until Commit
			Check.equal(next(profile.pendingHatches), nil)
			Check.isFalse(profile.meta.starterHatchGranted)
		end,
	},
	{
		name = "a high rollValue can still roll Rare from the Common tier's own odds (not scripted to Common)",
		run = function()
			local profile = profileWithStarterGranted(false)
			-- rollValue 0.999 is past Common's [0, .99) bucket -> lands in Rare
			local staged = StarterHatchRules.Stage(EGG_CONFIG, profile, 1000, POSITION, 0.999)

			Check.equal(staged.Rarity, "Rare")
		end,
	},
	{
		name = "Commit records the pending hatch, advances nextEntityId, and flips starterHatchGranted",
		run = function()
			local profile = profileWithStarterGranted(false, 5)
			local staged = StarterHatchRules.Stage(EGG_CONFIG, profile, 1000, POSITION, 0)
			local resultData = StarterHatchRules.Commit(profile, staged)

			Check.equal(resultData.HatchId, "5")
			Check.equal(resultData.Rarity, "Common")
			Check.equal(profile.pendingHatches["5"].Rarity, "Common")
			Check.equal(profile.pendingHatches["5"].Position.Z, 3)
			Check.equal(profile.meta.nextEntityId, 6)
			Check.isTrue(profile.meta.starterHatchGranted)
		end,
	},
})

process.exit(if passed then 0 else 1)
