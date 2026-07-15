-- Per-player transaction serialization (AGENTS.md §3.6): only one queued job runs at a time per
-- runtime; the next one starts only after the previous finishes, even if it errors. Runs on
-- Roblox's task scheduler, so this is engine glue and isn't covered by a Lune spec -- verify via
-- Studio (see memory-bank/progress.md's engine-glue lane).
local MAX_QUEUE_SIZE = 20

local TransactionQueue = {}
TransactionQueue.MAX_QUEUE_SIZE = MAX_QUEUE_SIZE

local function processNext(runtime)
	local job = table.remove(runtime.Queue.Pending, 1)
	if not job then
		runtime.Queue.Running = false
		return
	end

	runtime.Queue.Running = true
	-- job() itself resumes the waiting caller thread synchronously (task.spawn(thread, ...)); by
	-- the time that happens Run has already reached coroutine.yield() below (see the task.defer
	-- kick), so this direct call -- not another task.spawn wrapper -- is what keeps "next job only
	-- starts once the previous one is fully done" true even through that nested resume.
	job()
	processNext(runtime)
end

-- Runs `fn` exclusively for this runtime and returns its result once it's this job's turn.
-- Returns (accepted: boolean, ok: boolean?, resultOrErr: any?) -- `accepted` is false only when
-- the queue is already at MAX_QUEUE_SIZE; `ok` is false only if `fn` itself errored.
function TransactionQueue.Run(runtime, fn: () -> any): (boolean, boolean?, any?)
	if #runtime.Queue.Pending >= MAX_QUEUE_SIZE then
		return false, nil, nil
	end

	local thread = coroutine.running()
	table.insert(runtime.Queue.Pending, function()
		local ok, resultOrErr = pcall(fn)
		task.spawn(thread, ok, resultOrErr)
	end)

	if not runtime.Queue.Running then
		-- task.defer (not task.spawn/a direct call) so this thread reaches coroutine.yield()
		-- below before processNext can try to resume it -- task.spawn would run the whole chain
		-- synchronously right now, before this thread has actually suspended, and Roblox errors
		-- with "cannot spawn non-suspended coroutine with arguments" (caught live via Studio MCP).
		task.defer(processNext, runtime)
	end

	local ok, resultOrErr = coroutine.yield()
	return true, ok, resultOrErr
end

return TransactionQueue
