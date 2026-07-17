-- Thin TransactionService handler for sending a Farm Slot's dragon back to Storage. All real
-- logic (and its spec) lives in the pure src/shared/Domain/SendToStorageRules.luau. See
-- docs/prd/storage-and-farm-slot-management.md.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SendToStorageRules = require(Shared.Domain.SendToStorageRules)

local SendToStorageTransaction = {}

function SendToStorageTransaction.Validate(_context, payload): (boolean, number?)
	return SendToStorageRules.Validate(payload)
end

function SendToStorageTransaction.Stage(context, payload): (boolean, number?)
	local ok, staged, code = SendToStorageRules.Stage(context.Profile, payload, context.TransactionTime)
	if not ok then
		return false, code
	end
	context.Staged = staged
	return true, nil
end

function SendToStorageTransaction.Commit(context)
	context.ResultData = SendToStorageRules.Commit(context.Profile, context.Staged)
end

return SendToStorageTransaction
