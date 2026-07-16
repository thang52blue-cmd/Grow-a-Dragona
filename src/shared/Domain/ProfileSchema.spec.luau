local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local ProfileSchema = require("./ProfileSchema")

local passed = Check.runAll({
	{
		name = "default profile uses the given starting gold and empty inventory",
		run = function()
			local profile = ProfileSchema.default(50, 3)
			Check.equal(profile.gold, 50)
			Check.equal(next(profile.inventory), nil)
			Check.equal(profile.meta.schemaVersion, ProfileSchema.CURRENT_SCHEMA_VERSION)
		end,
	},
	{
		name = "default profile pre-populates the given number of empty farm slots and zero production eggs",
		run = function()
			local profile = ProfileSchema.default(50, 3)
			Check.equal(profile.farmSlots[1].SlotId, 1)
			Check.equal(profile.farmSlots[1].AssignedDragonUID, nil)
			Check.equal(profile.farmSlots[1].UncollectedEggCount, 0)
			Check.equal(profile.farmSlots[1].IsProductionPaused, false)
			Check.equal(profile.farmSlots[3].SlotId, 3)
			Check.equal(profile.farmSlots[4], nil)
			Check.equal(profile.productionEggInventory.Normal, 0)
			Check.equal(profile.productionEggInventory.Golden, 0)
		end,
	},
	{
		name = "validate accepts a well-formed profile",
		run = function()
			local ok, profile = ProfileSchema.validate({
				gold = 10,
				inventory = { Fish = 2 },
				meta = { schemaVersion = 1, session = { jobId = "abc", updatedAt = 123 } },
			})
			Check.isTrue(ok)
			Check.equal(profile.gold, 10)
			Check.equal(profile.inventory.Fish, 2)
			Check.equal(profile.meta.session.jobId, "abc")
		end,
	},
	{
		name = "validate rejects a non-table value",
		run = function()
			local ok = ProfileSchema.validate("not a profile")
			Check.isFalse(ok)
		end,
	},
	{
		name = "validate rejects negative gold",
		run = function()
			local ok = ProfileSchema.validate({
				gold = -5,
				inventory = {},
				meta = { schemaVersion = 1, session = {} },
			})
			Check.isFalse(ok)
		end,
	},
	{
		name = "validate rejects a malformed inventory entry",
		run = function()
			local ok = ProfileSchema.validate({
				gold = 0,
				inventory = { Fish = "not a number" },
				meta = { schemaVersion = 1, session = {} },
			})
			Check.isFalse(ok)
		end,
	},
	{
		name = "validate rejects missing meta",
		run = function()
			local ok = ProfileSchema.validate({ gold = 0, inventory = {} })
			Check.isFalse(ok)
		end,
	},
	{
		name = "validate defaults a missing session to a safe empty session",
		run = function()
			local ok, profile = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				meta = { schemaVersion = 1 },
			})
			Check.isTrue(ok)
			Check.equal(profile.meta.session.jobId, nil)
			Check.equal(profile.meta.session.updatedAt, 0)
		end,
	},
	{
		name = "validate defaults missing pendingHatches/dragons/nextEntityId (pre-hatch-feature saves)",
		run = function()
			local ok, profile = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				meta = { schemaVersion = 1, session = {} },
			})
			Check.isTrue(ok)
			Check.equal(next(profile.pendingHatches), nil)
			Check.equal(next(profile.dragons), nil)
			Check.equal(profile.meta.nextEntityId, 1)
		end,
	},
	{
		name = "validate accepts well-formed pendingHatches and dragons and preserves nextEntityId",
		run = function()
			local ok, profile = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				pendingHatches = { ["1"] = { Id = "1", Rarity = "Common", StartedAt = 100, FinishAt = 105 } },
				dragons = { ["2"] = { Id = "2", Rarity = "Rare", HatchedAt = 90 } },
				meta = { schemaVersion = 1, session = {}, nextEntityId = 3 },
			})
			Check.isTrue(ok)
			Check.equal(profile.pendingHatches["1"].Rarity, "Common")
			Check.equal(profile.pendingHatches["1"].FinishAt, 105)
			Check.equal(profile.dragons["2"].Rarity, "Rare")
			Check.equal(profile.meta.nextEntityId, 3)
			-- pre-Feed-Dragon-feature save: Element/GrowthStage/FeedCount absent -> defaults
			Check.equal(profile.dragons["2"].Element, "Fire")
			Check.equal(profile.dragons["2"].GrowthStage, "Baby_0")
			Check.equal(profile.dragons["2"].FeedCount, 0)
		end,
	},
	{
		name = "validate rejects a pendingHatches entry with an invalid rarity",
		run = function()
			local ok = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				pendingHatches = { ["1"] = { Id = "1", Rarity = "NotARarity", StartedAt = 100, FinishAt = 105 } },
				meta = { schemaVersion = 1, session = {} },
			})
			Check.isFalse(ok)
		end,
	},
	{
		name = "validate rejects a malformed dragons entry",
		run = function()
			local ok = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				dragons = { ["1"] = { Id = "1", Rarity = "Common" } }, -- missing HatchedAt
				meta = { schemaVersion = 1, session = {} },
			})
			Check.isFalse(ok)
		end,
	},
	{
		name = "validate rejects a dragons entry with an invalid Element or GrowthStage or negative FeedCount",
		run = function()
			local base = { Id = "1", Rarity = "Common", HatchedAt = 90 }
			local function withDragon(overrides)
				local entry = table.clone(base)
				for k, v in overrides do
					entry[k] = v
				end
				return ProfileSchema.validate({
					gold = 0,
					inventory = {},
					dragons = { ["1"] = entry },
					meta = { schemaVersion = 1, session = {} },
				})
			end

			Check.isFalse(withDragon({ Element = "NotAnElement" }))
			Check.isFalse(withDragon({ GrowthStage = "NotAStage" }))
			Check.isFalse(withDragon({ FeedCount = -1 }))
			Check.isFalse(withDragon({ FeedCount = 1.5 }))
			Check.isFalse(withDragon({ AssignedSlotId = "1" }))
		end,
	},
	{
		name = "validate defaults missing farmSlots/productionEggInventory to N fresh slots and zero eggs",
		run = function()
			local ok, profile = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				meta = { schemaVersion = 1, session = {} },
			}, 3)
			Check.isTrue(ok)
			Check.equal(profile.farmSlots[1].SlotId, 1)
			Check.equal(profile.farmSlots[3].SlotId, 3)
			Check.equal(profile.farmSlots[4], nil)
			Check.equal(profile.productionEggInventory.Normal, 0)
		end,
	},
	{
		name = "validate accepts well-formed farmSlots/productionEggInventory and preserves an assigned dragon",
		run = function()
			local ok, profile = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				dragons = { ["1"] = { Id = "1", Rarity = "Common", HatchedAt = 90, AssignedSlotId = 1 } },
				farmSlots = {
					[1] = {
						SlotId = 1,
						AssignedDragonUID = "1",
						ProductionStartedAt = 500,
						UncollectedEggCount = 4,
						IsProductionPaused = false,
					},
				},
				productionEggInventory = { Normal = 7, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 },
				meta = { schemaVersion = 1, session = {} },
			})
			Check.isTrue(ok)
			Check.equal(profile.dragons["1"].AssignedSlotId, 1)
			Check.equal(profile.farmSlots[1].AssignedDragonUID, "1")
			Check.equal(profile.farmSlots[1].UncollectedEggCount, 4)
			Check.equal(profile.productionEggInventory.Normal, 7)
		end,
	},
	{
		name = "validate rejects a malformed farmSlots or productionEggInventory entry",
		run = function()
			local badSlot = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				farmSlots = { [1] = { SlotId = 1, UncollectedEggCount = -1, IsProductionPaused = false } },
				meta = { schemaVersion = 1, session = {} },
			})
			Check.isFalse(badSlot)

			local badInventory = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				productionEggInventory = { Normal = "not a number" },
				meta = { schemaVersion = 1, session = {} },
			})
			Check.isFalse(badInventory)
		end,
	},
	{
		name = "validate defaults a missing pendingHatches.Position to the origin (pre-position-feature saves)",
		run = function()
			local ok, profile = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				pendingHatches = { ["1"] = { Id = "1", Rarity = "Common", StartedAt = 100, FinishAt = 105 } },
				meta = { schemaVersion = 1, session = {} },
			})
			Check.isTrue(ok)
			Check.equal(profile.pendingHatches["1"].Position.X, 0)
			Check.equal(profile.pendingHatches["1"].Position.Y, 0)
			Check.equal(profile.pendingHatches["1"].Position.Z, 0)
		end,
	},
	{
		name = "validate preserves a well-formed pendingHatches.Position",
		run = function()
			local ok, profile = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				pendingHatches = {
					["1"] = {
						Id = "1",
						Rarity = "Common",
						StartedAt = 100,
						FinishAt = 105,
						Position = { X = 10, Y = 20, Z = 30 },
					},
				},
				meta = { schemaVersion = 1, session = {} },
			})
			Check.isTrue(ok)
			Check.equal(profile.pendingHatches["1"].Position.X, 10)
			Check.equal(profile.pendingHatches["1"].Position.Y, 20)
			Check.equal(profile.pendingHatches["1"].Position.Z, 30)
		end,
	},
	{
		name = "validate rejects a pendingHatches entry with a malformed Position",
		run = function()
			local ok = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				pendingHatches = {
					["1"] = { Id = "1", Rarity = "Common", StartedAt = 100, FinishAt = 105, Position = { X = 1 } },
				},
				meta = { schemaVersion = 1, session = {} },
			})
			Check.isFalse(ok)
		end,
	},
	{
		name = "default profile has no lastPosition, and validate defaults a missing lastPosition to nil",
		run = function()
			Check.equal(ProfileSchema.default(0, 3).lastPosition, nil)

			local ok, profile = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				meta = { schemaVersion = 1, session = {} },
			})
			Check.isTrue(ok)
			Check.equal(profile.lastPosition, nil)
		end,
	},
	{
		name = "validate accepts a well-formed lastPosition and rejects a malformed one",
		run = function()
			local ok, profile = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				lastPosition = { X = 5, Y = 6, Z = 7 },
				meta = { schemaVersion = 1, session = {} },
			})
			Check.isTrue(ok)
			Check.equal(profile.lastPosition.X, 5)
			Check.equal(profile.lastPosition.Y, 6)
			Check.equal(profile.lastPosition.Z, 7)

			local badOk = ProfileSchema.validate({
				gold = 0,
				inventory = {},
				lastPosition = { X = 5, Y = "not a number", Z = 7 },
				meta = { schemaVersion = 1, session = {} },
			})
			Check.isFalse(badOk)
		end,
	},
})

process.exit(if passed then 0 else 1)
