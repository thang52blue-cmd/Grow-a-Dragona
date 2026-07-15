-- Server-authoritative transaction orchestrator (AGENTS.md transaction model):
-- check profile/runtime -> check closing -> dedupe cache -> rate limit -> enqueue -> build
-- context -> Validate -> Stage -> Commit -> bump Revision -> cache result -> return result.
-- Engine glue (Player, task.spawn via TransactionQueue) -- not Lune-tested directly; the pure
-- Validate/Stage/Commit rules each handler delegates to (e.g. BuyEggRules) carry their own specs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PayloadValidator = require(Shared.Domain.PayloadValidator)
local RateLimiter = require(Shared.Domain.RateLimiter)
local TransactionCode = require(Shared.Domain.TransactionCode)
local Types = require(Shared.Types.Types)

local DataService = require(script.Parent.Parent.Parent.Persistence.DataService)
local PlayerRuntimeStore = require(script.Parent.Parent.Parent.Runtime.PlayerRuntimeStore)
local TransactionQueue = require(script.Parent.TransactionQueue)

local MAX_ID_VALUE = 2 ^ 53
local GLOBAL_RATE_LIMIT = { max = 30, windowSeconds = 5 }

export type TransactionHandler = {
	Validate: (context: any, payload: any) -> (boolean, number?),
	Stage: (context: any, payload: any) -> (boolean, number?),
	Commit: (context: any) -> (),
}

local handlers: { [number]: TransactionHandler } = {}
local typeRateLimits: { [number]: { max: number, windowSeconds: number } } = {}

local TransactionService = {}

function TransactionService.RegisterHandler(typeId: number, handler: TransactionHandler)
	handlers[typeId] = handler
end

function TransactionService.SetTypeRateLimit(typeId: number, maxCount: number, windowSeconds: number)
	typeRateLimits[typeId] = { max = maxCount, windowSeconds = windowSeconds }
end

local function fail(code: number): Types.TransactionResult
	return { Success = false, Code = code }
end

function TransactionService.Submit(
	player: Player,
	requestId: unknown,
	typeId: unknown,
	payload: unknown
): Types.TransactionResult
	if not PayloadValidator.IsPositiveInteger(requestId, MAX_ID_VALUE) then
		return fail(TransactionCode.InvalidRequest)
	end
	if not PayloadValidator.IsPositiveInteger(typeId, MAX_ID_VALUE) then
		return fail(TransactionCode.InvalidRequest)
	end

	local handler = handlers[typeId :: number]
	if not handler then
		return fail(TransactionCode.InvalidRequest)
	end

	local runtime = PlayerRuntimeStore.Get(player)
	if not runtime then
		return fail(TransactionCode.ProfileNotLoaded)
	end

	if runtime.IsClosing then
		return fail(TransactionCode.PlayerClosing)
	end

	local cached = runtime.RequestCache:Get(requestId :: number)
	if cached then
		return cached
	end

	local now = os.time()

	local globalOk, newGlobalTimestamps =
		RateLimiter.tryConsume(runtime.RateGlobal, now, GLOBAL_RATE_LIMIT.max, GLOBAL_RATE_LIMIT.windowSeconds)
	runtime.RateGlobal = newGlobalTimestamps
	if not globalOk then
		return fail(TransactionCode.RateLimited)
	end

	local typeLimit = typeRateLimits[typeId :: number]
	if typeLimit then
		local existing = runtime.RateByType[typeId :: number] or {}
		local typeOk, newTypeTimestamps = RateLimiter.tryConsume(existing, now, typeLimit.max, typeLimit.windowSeconds)
		runtime.RateByType[typeId :: number] = newTypeTimestamps
		if not typeOk then
			return fail(TransactionCode.RateLimited)
		end
	end

	local accepted, ok, resultOrErr = TransactionQueue.Run(runtime, function(): Types.TransactionResult
		local profile = DataService.Get(player.UserId)
		if not profile then
			return fail(TransactionCode.ProfileNotLoaded)
		end
		if runtime.IsClosing then
			return fail(TransactionCode.PlayerClosing)
		end

		local context = {
			Player = player,
			Profile = profile,
			Runtime = runtime,
			RequestId = requestId,
			TypeId = typeId,
			TransactionTime = now,
			Staged = {},
			ResultData = {},
		}

		local validatePcallOk, isValid, validateCode = pcall(handler.Validate, context, payload)
		if not validatePcallOk then
			warn(`[GrowADragona] Validate error (type {typeId}): {tostring(isValid)}`)
			return fail(TransactionCode.InternalError)
		end
		if not isValid then
			return fail(validateCode or TransactionCode.InvalidRequest)
		end

		local stagePcallOk, isStaged, stageCode = pcall(handler.Stage, context, payload)
		if not stagePcallOk then
			warn(`[GrowADragona] Stage error (type {typeId}): {tostring(isStaged)}`)
			return fail(TransactionCode.InternalError)
		end
		if not isStaged then
			return fail(stageCode or TransactionCode.InternalError)
		end

		-- handler.Commit returns 0 values by contract, so pcall here only yields the ok boolean
		-- (no second error-message return to destructure).
		local commitPcallOk = pcall(handler.Commit, context)
		if not commitPcallOk then
			warn(`[GrowADragona] Commit error after staging, profile may be partially applied (type {typeId})`)
			runtime.Revision += 1
			return fail(TransactionCode.InternalError)
		end

		runtime.Revision += 1
		return {
			Success = true,
			Code = TransactionCode.Success,
			Revision = runtime.Revision,
			Data = context.ResultData,
		}
	end)

	if not accepted then
		return fail(TransactionCode.QueueFull)
	end

	local result: Types.TransactionResult
	if not ok then
		warn(`[GrowADragona] transaction queue job errored (type {typeId}): {tostring(resultOrErr)}`)
		result = fail(TransactionCode.InternalError)
	else
		result = resultOrErr :: Types.TransactionResult
	end

	runtime.RequestCache:Put(requestId :: number, result)
	return result
end

return TransactionService
