-- Fixed order, shared by every module that needs to iterate/validate the 5 elements
-- (mirrors Rarities.luau's rationale -- plain `string`, not `{ Types.Element }`, to sidestep
-- the same luau-lsp union-widening quirk).
local ORDER: { string } = { "Fire", "Water", "Earth", "Light", "Dark" }

local Elements = {}

Elements.List = ORDER

function Elements.IsValid(value: unknown): boolean
	if type(value) ~= "string" then
		return false
	end
	for _, element in ORDER do
		if element == value then
			return true
		end
	end
	return false
end

return Elements
