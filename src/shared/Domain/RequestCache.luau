-- Bounded requestId -> result cache for duplicate-request protection (AGENTS.md transaction
-- model). Runtime-only, never persisted. Oldest entry is evicted once the cache exceeds maxSize.
local RequestCache = {}
RequestCache.__index = RequestCache

export type RequestCacheInstance = typeof(setmetatable(
	{} :: { _maxSize: number, _byId: { [number]: any }, _order: { number } },
	RequestCache
))

function RequestCache.new(maxSize: number): RequestCacheInstance
	return setmetatable({
		_maxSize = maxSize,
		_byId = {},
		_order = {},
	}, RequestCache)
end

function RequestCache.Get(self: RequestCacheInstance, requestId: number): any?
	return self._byId[requestId]
end

function RequestCache.Put(self: RequestCacheInstance, requestId: number, result: any)
	if self._byId[requestId] == nil then
		table.insert(self._order, requestId)
		if #self._order > self._maxSize then
			local oldestId = table.remove(self._order, 1)
			if oldestId ~= nil then
				self._byId[oldestId] = nil
			end
		end
	end

	self._byId[requestId] = result
end

return RequestCache
