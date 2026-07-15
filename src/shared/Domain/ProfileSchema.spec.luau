local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local ProfileSchema = require("./ProfileSchema")

local passed = Check.runAll({
	{
		name = "default profile uses the given starting gold and empty inventory",
		run = function()
			local profile = ProfileSchema.default(50)
			Check.equal(profile.gold, 50)
			Check.equal(next(profile.inventory), nil)
			Check.equal(profile.meta.schemaVersion, ProfileSchema.CURRENT_SCHEMA_VERSION)
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
})

process.exit(if passed then 0 else 1)
