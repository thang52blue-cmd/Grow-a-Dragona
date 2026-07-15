local function isNonNegativeInteger(value: unknown): boolean
	return type(value) == "number"
		and (value :: number) == (value :: number)
		and (value :: number) >= 0
		and (value :: number) % 1 == 0
end

local Currency = {}

function Currency.add(balance: number, amount: number, maxGold: number): (boolean, number, string?)
	if not isNonNegativeInteger(amount) then
		return false, balance, "amount must be a non-negative integer"
	end

	local newBalance = balance + amount
	if newBalance > maxGold then
		newBalance = maxGold
	end

	return true, newBalance, nil
end

function Currency.spend(balance: number, amount: number): (boolean, number, string?)
	if not isNonNegativeInteger(amount) then
		return false, balance, "amount must be a non-negative integer"
	end

	if amount > balance then
		return false, balance, "insufficient balance"
	end

	return true, balance - amount, nil
end

return Currency
