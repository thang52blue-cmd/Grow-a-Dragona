-- Fixed order, shared by every module that needs to iterate/validate the 5 Production Egg
-- variants (CollectNestRules' variant roll, SellProductionEggRules, ProfileSchema, ...). Same
-- luau-lsp widening-quirk precedent as Rarities.luau/Elements.luau -- callers indexing
-- Variant-keyed tables with a loop variable here cast through `:: any`.
local ORDER: { string } = { "Normal", "Mini", "Heavy", "Giant", "Golden" }

local Variants = {}

Variants.List = ORDER

function Variants.IsValid(value: unknown): boolean
	if type(value) ~= "string" then
		return false
	end
	for _, variant in ORDER do
		if variant == value then
			return true
		end
	end
	return false
end

return Variants
