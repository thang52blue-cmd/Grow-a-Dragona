-- Thin TransactionService handler for selling the player's entire Production Egg inventory. All
-- real logic (and its spec) lives in the pure src/shared/Domain/SellProductionEggRules.luau --
-- this file only adapts it to the Validate/Stage/Commit contract and supplies the server-only
-- config.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SellProductionEggRules = require(Shared.Domain.SellProductionEggRules)
local Types = require(Shared.Types.Types)
local EggConfig = require(Shared.Data.EggConfig) :: Types.EggConfig
local DragonConfig = require(Shared.Data.DragonConfig) :: Types.DragonConfig
local EconomyConfig = require(Shared.Data.EconomyConfig) :: Types.EconomyConfig

local SellProductionEggTransaction = {}

function SellProductionEggTransaction.Validate(_context, payload): (boolean, number?)
	return SellProductionEggRules.Validate(payload)
end

function SellProductionEggTransaction.Stage(context, _payload): (boolean, number?)
	local ok, staged, code = SellProductionEggRules.Stage(EggConfig, DragonConfig, EconomyConfig, context.Profile)
	if not ok then
		return false, code
	end
	context.Staged = staged
	return true, nil
end

function SellProductionEggTransaction.Commit(context)
	context.ResultData = SellProductionEggRules.Commit(context.Profile, context.Staged)
end

return SellProductionEggTransaction
