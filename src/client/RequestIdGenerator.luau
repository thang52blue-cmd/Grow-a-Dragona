-- Shared monotonic RequestId source for every client-issued Transaction call. A single counter
-- keeps the test harness and any UI (e.g. EggShopUI) from handing out the same id, which the
-- server's per-player RequestCache would otherwise treat as a duplicate/idempotent replay.
local RequestIdGenerator = {}

local nextId = 1

function RequestIdGenerator.Next(): number
	local id = nextId
	nextId += 1
	return id
end

return RequestIdGenerator
