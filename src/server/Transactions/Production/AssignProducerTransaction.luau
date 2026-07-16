-- Thin TransactionService handler for assigning an Adult dragon to a Farm Slot. All real logic
-- (and its spec) lives in the pure src/shared/Domain/AssignProducerRules.luau -- this file only
-- adapts it to the Validate/Stage/Commit contract and supplies context.TransactionTime as the
-- production start time.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssignProducerRules = require(Shared.Domain.AssignProducerRules)

local AssignProducerTransaction = {}

function AssignProducerTransaction.Validate(_context, payload): (boolean, number?)
	return AssignProducerRules.Validate(payload)
end

function AssignProducerTransaction.Stage(context, payload): (boolean, number?)
	local ok, staged, code = AssignProducerRules.Stage(context.Profile, payload, context.TransactionTime)
	if not ok then
		return false, code
	end
	context.Staged = staged
	return true, nil
end

function AssignProducerTransaction.Commit(context)
	context.ResultData = AssignProducerRules.Commit(context.Profile, context.Staged)
end

return AssignProducerTransaction
