-- Fixed order, shared by every module that needs to iterate/validate the 5 rarities
-- (Shop UI, BuyEggRules, StartHatchRules, ProfileSchema, ...). Plain `string`, not
-- `{ Types.Rarity }`: generalized iteration trips a luau-lsp widening quirk (a union-typed
-- element collapses to a repeated "string | string | ..." instead of the literal union),
-- so callers indexing Rarity-keyed tables with a loop variable here cast through `:: any`.
local ORDER: { string } = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

local Rarities = {}

Rarities.List = ORDER

function Rarities.IsValid(value: unknown): boolean
	if type(value) ~= "string" then
		return false
	end
	for _, rarity in ORDER do
		if rarity == value then
			return true
		end
	end
	return false
end

return Rarities
