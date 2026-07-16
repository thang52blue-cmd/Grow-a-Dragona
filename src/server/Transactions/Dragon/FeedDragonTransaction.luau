-- Thin TransactionService handler for feeding a Baby dragon. All real logic (and its spec)
-- lives in the pure src/shared/Domain/FeedDragonRules.luau -- this file only adapts it to the
-- Validate/Stage/Commit contract and supplies the server-only FoodConfig.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FeedDragonRules = require(Shared.Domain.FeedDragonRules)
local Types = require(Shared.Types.Types)
local FoodConfig = require(Shared.Data.FoodConfig) :: Types.FoodConfig

local FeedDragonTransaction = {}

function FeedDragonTransaction.Validate(_context, payload): (boolean, number?)
	return FeedDragonRules.Validate(payload)
end

function FeedDragonTransaction.Stage(context, payload): (boolean, number?)
	local ok, staged, code = FeedDragonRules.Stage(FoodConfig, context.Profile, payload)
	if not ok then
		return false, code
	end
	context.Staged = staged
	return true, nil
end

function FeedDragonTransaction.Commit(context)
	context.ResultData = FeedDragonRules.Commit(context.Profile, context.Staged)
end

return FeedDragonTransaction
