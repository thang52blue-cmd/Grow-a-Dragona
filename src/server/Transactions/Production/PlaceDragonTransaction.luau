-- Thin TransactionService handler for placing a Storage dragon (Baby or Adult) into an empty
-- Farm Slot. All real logic (and its spec) lives in the pure
-- src/shared/Domain/PlaceDragonRules.luau -- this file only adapts it to the
-- Validate/Stage/Commit contract and supplies context.TransactionTime as the production start
-- time. See docs/prd/storage-and-farm-slot-management.md.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PlaceDragonRules = require(Shared.Domain.PlaceDragonRules)

local PlaceDragonTransaction = {}

function PlaceDragonTransaction.Validate(_context, payload): (boolean, number?)
	return PlaceDragonRules.Validate(payload)
end

function PlaceDragonTransaction.Stage(context, payload): (boolean, number?)
	local ok, staged, code = PlaceDragonRules.Stage(context.Profile, payload, context.TransactionTime)
	if not ok then
		return false, code
	end
	context.Staged = staged
	return true, nil
end

function PlaceDragonTransaction.Commit(context)
	context.ResultData = PlaceDragonRules.Commit(context.Profile, context.Staged)
end

return PlaceDragonTransaction
