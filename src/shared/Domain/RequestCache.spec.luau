local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local RequestCache = require("./RequestCache")

local passed = Check.runAll({
	{
		name = "Get returns nil for a requestId that was never put",
		run = function()
			local cache = RequestCache.new(50)
			Check.equal(cache:Get(101), nil)
		end,
	},
	{
		name = "Put then Get returns the cached result",
		run = function()
			local cache = RequestCache.new(50)
			cache:Put(101, { Success = true })
			Check.equal(cache:Get(101).Success, true)
		end,
	},
	{
		name = "Put with the same requestId again overwrites but doesn't grow past cap early",
		run = function()
			local cache = RequestCache.new(50)
			cache:Put(101, { Success = true })
			cache:Put(101, { Success = false })
			Check.equal(cache:Get(101).Success, false)
		end,
	},
	{
		name = "evicts the oldest requestId once the cache exceeds its max size",
		run = function()
			local cache = RequestCache.new(2)
			cache:Put(1, "a")
			cache:Put(2, "b")
			cache:Put(3, "c")
			Check.equal(cache:Get(1), nil)
			Check.equal(cache:Get(2), "b")
			Check.equal(cache:Get(3), "c")
		end,
	},
})

process.exit(if passed then 0 else 1)
