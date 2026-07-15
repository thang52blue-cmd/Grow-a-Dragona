local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number"
		and (value :: number) == (value :: number)
		and (value :: number) ~= math.huge
		and (value :: number) ~= -math.huge
end

local PayloadValidator = {}

function PayloadValidator.IsFiniteNumber(value: unknown): boolean
	return isFiniteNumber(value)
end

function PayloadValidator.IsIntegerInRange(value: unknown, minimum: number, maximum: number): boolean
	if not isFiniteNumber(value) then
		return false
	end

	local number = value :: number
	return number % 1 == 0 and number >= minimum and number <= maximum
end

function PayloadValidator.IsPositiveInteger(value: unknown, maximum: number): boolean
	return PayloadValidator.IsIntegerInRange(value, 1, maximum)
end

return PayloadValidator
