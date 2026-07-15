local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Inventory = require(Shared.Domain.Inventory)
local Types = require(Shared.Types.Types)
local EconomyConfig = require(Shared.Data.EconomyConfig) :: Types.EconomyConfig

local DataService = require(script.Parent.Parent.Persistence.DataService)

local InventoryService = {}

local function getProfile(player: Player): (Types.Profile?, string?)
	local profile = DataService.Get(player.UserId)
	if not profile then
		return nil, "profile not loaded for this player"
	end
	return profile, nil
end

function InventoryService.GetItem(player: Player, itemId: string): (boolean, number?, string?)
	local profile, err = getProfile(player)
	if not profile then
		return false, nil, err
	end
	return true, Inventory.get(profile.inventory, itemId), nil
end

function InventoryService.AddItem(player: Player, itemId: string, quantity: number): (boolean, number?, string?)
	local profile, err = getProfile(player)
	if not profile then
		return false, nil, err
	end

	local ok, nextInventory, reason =
		Inventory.add(profile.inventory, itemId, quantity, EconomyConfig.maxInventoryStack)
	if not ok then
		return false, nil, reason
	end

	profile.inventory = nextInventory
	return true, nextInventory[itemId], nil
end

function InventoryService.RemoveItem(player: Player, itemId: string, quantity: number): (boolean, number?, string?)
	local profile, err = getProfile(player)
	if not profile then
		return false, nil, err
	end

	local ok, nextInventory, reason = Inventory.remove(profile.inventory, itemId, quantity)
	if not ok then
		return false, nil, reason
	end

	profile.inventory = nextInventory
	return true, nextInventory[itemId] or 0, nil
end

return InventoryService
