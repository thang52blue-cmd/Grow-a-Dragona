local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local SessionLock = require("./SessionLock")

local TIMEOUT = 30

local passed = Check.runAll({
	{
		name = "an empty session (no prior owner) can always be claimed",
		run = function()
			Check.isTrue(SessionLock.canClaim({ jobId = nil, updatedAt = 0 }, "server-a", 1000, TIMEOUT))
		end,
	},
	{
		name = "the same server can reclaim its own session",
		run = function()
			Check.isTrue(SessionLock.canClaim({ jobId = "server-a", updatedAt = 1000 }, "server-a", 1010, TIMEOUT))
		end,
	},
	{
		name = "a different server is blocked while the lock is still fresh",
		run = function()
			Check.isFalse(SessionLock.canClaim({ jobId = "server-a", updatedAt = 1000 }, "server-b", 1010, TIMEOUT))
		end,
	},
	{
		name = "a different server can claim once the lock has expired",
		run = function()
			Check.isTrue(
				SessionLock.canClaim({ jobId = "server-a", updatedAt = 1000 }, "server-b", 1000 + TIMEOUT, TIMEOUT)
			)
		end,
	},
	{
		name = "a different server is blocked at exactly the timeout boundary minus one second",
		run = function()
			Check.isFalse(
				SessionLock.canClaim({ jobId = "server-a", updatedAt = 1000 }, "server-b", 1000 + TIMEOUT - 1, TIMEOUT)
			)
		end,
	},
})

process.exit(if passed then 0 else 1)
