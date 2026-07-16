-- Thin TransactionService handler for collecting a Nest's Production Eggs. All real logic (and
-- its spec) lives in the pure src/shared/Domain/CollectNestRules.luau -- this file only adapts it
-- to the Validate/Stage/Commit contract and supplies the server-only ProductionConfig and
-- context.TransactionTime as `now`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CollectNestRules = require(Shared.Domain.CollectNestRules)
local Types = require(Shared.Types.Types)
local ProductionConfig = require(Shared.Data.ProductionConfig) :: Types.ProductionConfig

local CollectNestTransaction = {}

function CollectNestTransaction.Validate(_context, payload): (boolean, number?)
	return CollectNestRules.Validate(payload)
end

function CollectNestTransaction.Stage(context, payload): (boolean, number?)
	local ok, staged, code = CollectNestRules.Stage(ProductionConfig, context.Profile, payload, context.TransactionTime)
	if not ok then
		return false, code
	end
	context.Staged = staged
	return true, nil
end

function CollectNestTransaction.Commit(context)
	context.ResultData = CollectNestRules.Commit(context.Profile, context.Staged)
end

return CollectNestTransaction
