local Types = require("../Types/Types")

local function isPositiveInteger(value: unknown): boolean
	return type(value) == "number"
		and (value :: number) == (value :: number)
		and (value :: number) > 0
		and (value :: number) % 1 == 0
end

local Inventory = {}

function Inventory.get(inventory: Types.Inventory, itemId: string): number
	return inventory[itemId] or 0
end

function Inventory.add(
	inventory: Types.Inventory,
	itemId: string,
	quantity: number,
	maxStack: number
): (boolean, Types.Inventory, string?)
	if type(itemId) ~= "string" or itemId == "" then
		return false, inventory, "itemId must be a non-empty string"
	end
	if not isPositiveInteger(quantity) then
		return false, inventory, "quantity must be a positive integer"
	end

	local next = table.clone(inventory)
	local newQuantity = (inventory[itemId] or 0) + quantity
	if newQuantity > maxStack then
		newQuantity = maxStack
	end
	next[itemId] = newQuantity

	return true, next, nil
end

function Inventory.remove(
	inventory: Types.Inventory,
	itemId: string,
	quantity: number
): (boolean, Types.Inventory, string?)
	if type(itemId) ~= "string" or itemId == "" then
		return false, inventory, "itemId must be a non-empty string"
	end
	if not isPositiveInteger(quantity) then
		return false, inventory, "quantity must be a positive integer"
	end

	local current = inventory[itemId] or 0
	if quantity > current then
		return false, inventory, "insufficient quantity"
	end

	local next = table.clone(inventory)
	local remaining = current - quantity
	if remaining == 0 then
		next[itemId] = nil
	else
		next[itemId] = remaining
	end

	return true, next, nil
end

return Inventory
