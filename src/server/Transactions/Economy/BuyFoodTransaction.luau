-- Thin TransactionService handler for buying a Food item. All real logic (and its spec) lives in
-- the pure src/shared/Domain/BuyFoodRules.luau -- this file only adapts it to the
-- Validate/Stage/Commit contract and supplies the server-only config.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuyFoodRules = require(Shared.Domain.BuyFoodRules)
local Types = require(Shared.Types.Types)
local FoodShopConfig = require(Shared.Data.FoodShopConfig) :: Types.FoodShopConfig
local EconomyConfig = require(Shared.Data.EconomyConfig) :: Types.EconomyConfig

local BuyFoodTransaction = {}

function BuyFoodTransaction.Validate(_context, payload): (boolean, number?)
	return BuyFoodRules.Validate(FoodShopConfig, payload)
end

function BuyFoodTransaction.Stage(context, payload): (boolean, number?)
	local ok, staged, code = BuyFoodRules.Stage(FoodShopConfig, EconomyConfig, context.Profile, payload)
	if not ok then
		return false, code
	end
	context.Staged = staged
	return true, nil
end

function BuyFoodTransaction.Commit(context)
	context.ResultData = BuyFoodRules.Commit(context.Profile, context.Staged)
end

return BuyFoodTransaction
