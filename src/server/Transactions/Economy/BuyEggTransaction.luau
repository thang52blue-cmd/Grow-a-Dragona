-- Thin TransactionService handler for buying a hatching egg. All real logic (and its spec) lives
-- in the pure src/shared/Domain/BuyEggRules.luau -- this file only adapts it to the
-- Validate/Stage/Commit contract and supplies the server-only config.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuyEggRules = require(Shared.Domain.BuyEggRules)
local Types = require(Shared.Types.Types)
local EggConfig = require(Shared.Data.EggConfig) :: Types.EggConfig
local EconomyConfig = require(Shared.Data.EconomyConfig) :: Types.EconomyConfig

local BuyEggTransaction = {}

function BuyEggTransaction.Validate(_context, payload): (boolean, number?)
	return BuyEggRules.Validate(EggConfig, payload)
end

function BuyEggTransaction.Stage(context, payload): (boolean, number?)
	local ok, staged, code = BuyEggRules.Stage(EggConfig, EconomyConfig, context.Profile, payload)
	if not ok then
		return false, code
	end
	context.Staged = staged
	return true, nil
end

function BuyEggTransaction.Commit(context)
	context.ResultData = BuyEggRules.Commit(context.Profile, context.Staged)
end

return BuyEggTransaction
