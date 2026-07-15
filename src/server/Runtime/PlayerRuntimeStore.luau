-- Per-player runtime-only state for the transaction system (never persisted -- see AGENTS.md's
-- "Runtime-only" data classification): the transaction queue, rate-limit windows, the recent-
-- request dedupe cache, and a session-scoped Revision counter.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RequestCache = require(Shared.Domain.RequestCache)

local MAX_RECENT_REQUESTS = 50

local store: { [number]: any } = {}

local PlayerRuntimeStore = {}

function PlayerRuntimeStore.Create(player: Player)
	local runtime = {
		IsClosing = false,
		Revision = 0,
		Queue = { Running = false, Pending = {} },
		RequestCache = RequestCache.new(MAX_RECENT_REQUESTS),
		RateGlobal = {},
		RateByType = {},
	}
	store[player.UserId] = runtime
	return runtime
end

function PlayerRuntimeStore.Get(player: Player)
	return store[player.UserId]
end

function PlayerRuntimeStore.SetClosing(player: Player, value: boolean)
	local runtime = store[player.UserId]
	if runtime then
		runtime.IsClosing = value
	end
end

function PlayerRuntimeStore.Remove(player: Player)
	store[player.UserId] = nil
end

return PlayerRuntimeStore
