local PayloadValidator = require("./PayloadValidator")

local RateLimiter = {}

-- Sliding-window limiter: prunes timestamps outside the window, then accepts `now` only if the
-- pruned count is still under maxCount. Pure/functional (never mutates `timestamps`) so callers
-- (runtime-only rate-limit state) decide when to persist the returned list.
function RateLimiter.tryConsume(
	timestamps: { number },
	now: number,
	maxCount: number,
	windowSeconds: number
): (boolean, { number })
	assert(PayloadValidator.IsFiniteNumber(now), "now must be a finite number")

	local pruned = {}
	for _, timestamp in timestamps do
		if now - timestamp < windowSeconds then
			table.insert(pruned, timestamp)
		end
	end

	if #pruned >= maxCount then
		return false, pruned
	end

	table.insert(pruned, now)
	return true, pruned
end

return RateLimiter
