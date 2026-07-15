-- Shared display order/colors for the 5 hatching-egg rarities. Extracted out of
-- EggShopUI so EggInventoryUI can render the same order/accent colors without
-- redefining them.
--
-- Fixed display order -- table iteration over EggConfig.hatchingTiers has no guaranteed order.
-- Plain `string`, not `{ Types.Rarity }`: generalized iteration here trips the same luau-lsp
-- widening quirk documented in BuyEggRules.luau (union-typed element collapses to a repeated
-- "string | string | ..." instead of the literal union), so indexing Rarity-keyed tables below
-- casts through `:: any` instead.
local RarityDisplay = {}

local order: { string } = { "Common", "Rare", "Epic", "Legendary", "Mythic" }
local color: { [string]: Color3 } = {
	Common = Color3.fromRGB(190, 190, 190),
	Rare = Color3.fromRGB(68, 140, 255),
	Epic = Color3.fromRGB(170, 80, 230),
	Legendary = Color3.fromRGB(255, 170, 40),
	Mythic = Color3.fromRGB(255, 60, 60),
}

RarityDisplay.Order = order
RarityDisplay.Color = color

return RarityDisplay
