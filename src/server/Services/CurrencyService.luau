local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Currency = require(Shared.Domain.Currency)
local Types = require(Shared.Types.Types)
local EconomyConfig = require(Shared.Data.EconomyConfig) :: Types.EconomyConfig

local DataService = require(script.Parent.Parent.Persistence.DataService)

local CurrencyService = {}

local function getProfile(player: Player): (Types.Profile?, string?)
	local profile = DataService.Get(player.UserId)
	if not profile then
		return nil, "profile not loaded for this player"
	end
	return profile, nil
end

function CurrencyService.GetGold(player: Player): (boolean, number?, string?)
	local profile, err = getProfile(player)
	if not profile then
		return false, nil, err
	end
	return true, profile.gold, nil
end

function CurrencyService.AddGold(player: Player, amount: number): (boolean, number?, string?)
	local profile, err = getProfile(player)
	if not profile then
		return false, nil, err
	end

	local ok, newBalance, reason = Currency.add(profile.gold, amount, EconomyConfig.maxGold)
	if not ok then
		return false, nil, reason
	end

	profile.gold = newBalance
	return true, newBalance, nil
end

function CurrencyService.SpendGold(player: Player, amount: number): (boolean, number?, string?)
	local profile, err = getProfile(player)
	if not profile then
		return false, nil, err
	end

	local ok, newBalance, reason = Currency.spend(profile.gold, amount)
	if not ok then
		return false, nil, reason
	end

	profile.gold = newBalance
	return true, newBalance, nil
end

return CurrencyService
