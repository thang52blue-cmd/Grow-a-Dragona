-- Thin TransactionService handler for atomically swapping a Farm Slot's dragon for a different
-- Storage dragon. All real logic (and its spec) lives in the pure
-- src/shared/Domain/SwapDragonRules.luau. See docs/prd/storage-and-farm-slot-management.md.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SwapDragonRules = require(Shared.Domain.SwapDragonRules)

local SwapDragonTransaction = {}

function SwapDragonTransaction.Validate(_context, payload): (boolean, number?)
	return SwapDragonRules.Validate(payload)
end

function SwapDragonTransaction.Stage(context, payload): (boolean, number?)
	local ok, staged, code = SwapDragonRules.Stage(context.Profile, payload, context.TransactionTime)
	if not ok then
		return false, code
	end
	context.Staged = staged
	return true, nil
end

function SwapDragonTransaction.Commit(context)
	context.ResultData = SwapDragonRules.Commit(context.Profile, context.Staged)
end

return SwapDragonTransaction
