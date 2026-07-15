local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local RateLimiter = require("./RateLimiter")

local passed = Check.runAll({
	{
		name = "allows requests under the cap within the window",
		run = function()
			local timestamps = {}
			local ok1, next1 = RateLimiter.tryConsume(timestamps, 0, 3, 5)
			Check.isTrue(ok1)
			local ok2, next2 = RateLimiter.tryConsume(next1, 1, 3, 5)
			Check.isTrue(ok2)
			local ok3 = RateLimiter.tryConsume(next2, 2, 3, 5)
			Check.isTrue(ok3)
		end,
	},
	{
		name = "rejects the request once the cap is reached within the window",
		run = function()
			local timestamps = { 0, 1, 2 }
			local ok, unchanged = RateLimiter.tryConsume(timestamps, 3, 3, 5)
			Check.isFalse(ok)
			Check.equal(#unchanged, 3)
		end,
	},
	{
		name = "old timestamps outside the window are pruned, freeing capacity",
		run = function()
			local timestamps = { 0, 1, 2 }
			-- now = 10, window = 5 -> all three timestamps (0,1,2) are stale and pruned
			local ok, pruned = RateLimiter.tryConsume(timestamps, 10, 3, 5)
			Check.isTrue(ok)
			Check.equal(#pruned, 1)
			Check.equal(pruned[1], 10)
		end,
	},
	{
		name = "does not mutate the input timestamps table",
		run = function()
			local timestamps = { 0 }
			RateLimiter.tryConsume(timestamps, 1, 1, 5)
			Check.equal(#timestamps, 1)
		end,
	},
})

process.exit(if passed then 0 else 1)
