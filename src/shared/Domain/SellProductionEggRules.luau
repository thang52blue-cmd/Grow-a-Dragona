-- Pure Validate/Stage/Commit rules for SellProductionEggTransaction (backlog item 7). No engine
-- globals or IO (AGENTS.md hard rule). GDD §8: selling is always "Sell all" (no selective
-- selling, no payload fields to validate beyond shape), converting the player's entire
-- Profile.productionEggInventory into Gold in one shot. Sell value is always computed
-- server-side as `variant's base sell value x the laying dragon's own rarity production
-- multiplier` (GDD §8's table) -- never trusted from the client, and never derivable from just
-- the variant, since the whole point of ADR-006's schema change was to track which Rarity laid
-- each egg.
local Types = require("../Types/Types")
local TransactionCode = require("./TransactionCode")
local Currency = require("./Currency")
local Rarities = require("./Rarities")
local Variants = require("./Variants")

local SellProductionEggRules = {}

export type SoldLineItem = {
	Rarity: string,
	Variant: string,
	Count: number,
	UnitValue: number,
	Subtotal: number,
}

export type StagedSellProductionEgg = {
	TotalGold: number,
	SoldLineItems: { SoldLineItem },
	NewGold: number,
	NewProductionEggInventory: Types.ProductionEggInventoryByRarity,
}

local function emptyProductionEggInventory(): Types.ProductionEggInventoryByRarity
	local byRarity: { [string]: Types.ProductionEggInventory } = {}
	for _, rarity in Rarities.List do
		byRarity[rarity] = { Normal = 0, Mini = 0, Heavy = 0, Giant = 0, Golden = 0 }
	end
	return byRarity :: any
end

-- Validate: read-only, payload shape only -- there is nothing else to check since Sell always
-- sells everything (GDD §8: "Only Sell all - no selective selling").
function SellProductionEggRules.Validate(payload: unknown): (boolean, number?)
	if type(payload) ~= "table" then
		return false, TransactionCode.InvalidRequest
	end
	return true, nil
end

-- Stage: computes the full write set as new values, never mutating `profile`. Walks every
-- (Rarity, Variant) bucket, valuing each non-empty one at
-- `eggConfig.productionVariants[variant].baseSellValue * dragonConfig.rarities[rarity]
-- .productionMultiplier`, and rejects with NothingToSell if the whole inventory is empty (an
-- explicit Sell tap with nothing to sell shouldn't silently succeed for 0 gold).
function SellProductionEggRules.Stage(
	eggConfig: Types.EggConfig,
	dragonConfig: Types.DragonConfig,
	economyConfig: Types.EconomyConfig,
	profile: Types.Profile
): (boolean, StagedSellProductionEgg?, number?)
	local totalGold = 0
	local soldLineItems: { SoldLineItem } = {}

	for _, rarity in Rarities.List do
		local bucket = profile.productionEggInventory[rarity :: any]
		local rarityMultiplier = dragonConfig.rarities[rarity :: any].productionMultiplier
		for _, variant in Variants.List do
			local count = bucket[variant :: any]
			if count > 0 then
				local unitValue = eggConfig.productionVariants[variant :: any].baseSellValue * rarityMultiplier
				local subtotal = unitValue * count
				totalGold += subtotal
				table.insert(soldLineItems, {
					Rarity = rarity,
					Variant = variant,
					Count = count,
					UnitValue = unitValue,
					Subtotal = subtotal,
				})
			end
		end
	end

	if totalGold <= 0 then
		return false, nil, TransactionCode.NothingToSell
	end

	local addOk, newGold = Currency.add(profile.gold, totalGold, economyConfig.maxGold)
	if not addOk then
		return false, nil, TransactionCode.NotEnoughCurrency
	end

	return true,
		{
			TotalGold = totalGold,
			SoldLineItems = soldLineItems,
			NewGold = newGold,
			NewProductionEggInventory = emptyProductionEggInventory(),
		},
		nil
end

-- Commit: the only step allowed to mutate `profile`. Grants Gold and clears the entire
-- inventory in the same shot so a sell can never credit Gold without also emptying the
-- inventory it was computed from (or vice versa).
function SellProductionEggRules.Commit(profile: Types.Profile, staged: StagedSellProductionEgg): { [string]: any }
	profile.gold = staged.NewGold
	profile.productionEggInventory = staged.NewProductionEggInventory

	return {
		TotalGold = staged.TotalGold,
		SoldLineItems = staged.SoldLineItems,
		RemainingGold = staged.NewGold,
	}
end

return SellProductionEggRules
