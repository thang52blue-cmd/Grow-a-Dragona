-- Thin TransactionService handler for claiming a finished hatch. All real logic (and its
-- spec) lives in the pure src/shared/Domain/ClaimHatchRules.luau -- this file only adapts
-- it to the Validate/Stage/Commit contract, supplies the server-only config, and is the
-- one place that calls math.random() (Rules stays pure/deterministic, taking rollValue as
-- an explicit parameter). Despawning the world egg model is a Runtime-only side effect
-- triggered from src/server/init.server.luau after a successful Submit, not this module's
-- job (see AGENTS.md's transaction model).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClaimHatchRules = require(Shared.Domain.ClaimHatchRules)
local Types = require(Shared.Types.Types)
local EggConfig = require(Shared.Data.EggConfig) :: Types.EggConfig
local DragonConfig = require(Shared.Data.DragonConfig) :: Types.DragonConfig

local ClaimHatchTransaction = {}

function ClaimHatchTransaction.Validate(_context, payload): (boolean, number?)
	return ClaimHatchRules.Validate(payload)
end

function ClaimHatchTransaction.Stage(context, payload): (boolean, number?)
	local ok, staged, code = ClaimHatchRules.Stage(
		EggConfig,
		DragonConfig,
		context.Profile,
		payload,
		context.TransactionTime,
		math.random(),
		math.random()
	)
	if not ok then
		return false, code
	end
	context.Staged = staged
	return true, nil
end

function ClaimHatchTransaction.Commit(context)
	context.ResultData = ClaimHatchRules.Commit(context.Profile, context.Staged)
end

return ClaimHatchTransaction
