-- Pure Validate/Stage/Commit rules for BuyFoodTransaction (Food Shop -- a new feature, not
-- previously planned in docs/prd/core-game-loop.md, which only called for "a temporary Food test
-- source"). No engine globals or IO (AGENTS.md hard rule); mirrors BuyEggRules.luau's structure
-- exactly. Food already reuses the generic Profile.inventory bucket (ADR-003), so no schema
-- change/ADR was needed here -- only a new price catalog (FoodShopConfig.json) and transaction.
local Types = require("../Types/Types")
local Currency = require("./Currency")
local Inventory = require("./Inventory")
local PayloadValidator = require("./PayloadValidator")
local TransactionCode = require("./TransactionCode")

-- Same hard ceiling rationale as BuyEggRules -- independent of any per-item config, just a sanity
-- cap on a single request's Amount.
local HARD_MAX_AMOUNT = 100

local BuyFoodRules = {}

export type StagedBuyFood = {
	ItemId: string,
	Amount: number,
	UnitPrice: number,
	TotalPrice: number,
	NewGold: number,
	NewInventory: Types.Inventory,
}

-- Validate: read-only. Never touches profile/inventory quantities, only checks the payload shape
-- and that the item exists in the (frozen, server-only) Food Shop price catalog.
function BuyFoodRules.Validate(foodShopConfig: Types.FoodShopConfig, payload: unknown): (boolean, number?)
	if type(payload) ~= "table" then
		return false, TransactionCode.InvalidRequest
	end
	local rawPayload = payload :: { [string]: any }

	if type(rawPayload.ItemId) ~= "string" or rawPayload.ItemId == "" then
		return false, TransactionCode.InvalidFoodType
	end

	if foodShopConfig[rawPayload.ItemId] == nil then
		return false, TransactionCode.InvalidFoodType
	end

	if not PayloadValidator.IsPositiveInteger(rawPayload.Amount, HARD_MAX_AMOUNT) then
		return false, TransactionCode.InvalidAmount
	end

	return true, nil
end

-- Stage: computes the full write set as new values, never mutating `profile`. Also re-checks the
-- Gold balance against the just-computed TotalPrice (the actual affordability check).
function BuyFoodRules.Stage(
	foodShopConfig: Types.FoodShopConfig,
	economyConfig: Types.EconomyConfig,
	profile: Types.Profile,
	payload: { [string]: any }
): (boolean, StagedBuyFood?, number?)
	local itemId = payload.ItemId :: string
	local amount = payload.Amount :: number

	local unitPrice = foodShopConfig[itemId]
	local totalPrice = unitPrice * amount

	local spendOk, newGold = Currency.spend(profile.gold, totalPrice)
	if not spendOk then
		return false, nil, TransactionCode.NotEnoughCurrency
	end

	local addOk, newInventory = Inventory.add(profile.inventory, itemId, amount, economyConfig.maxInventoryStack)
	if not addOk then
		return false, nil, TransactionCode.InventoryFull
	end

	return true,
		{
			ItemId = itemId,
			Amount = amount,
			UnitPrice = unitPrice,
			TotalPrice = totalPrice,
			NewGold = newGold,
			NewInventory = newInventory,
		},
		nil
end

-- Commit: the only step allowed to mutate `profile`. Applies Gold + inventory together so a
-- successful purchase can never grant one without the other.
function BuyFoodRules.Commit(profile: Types.Profile, staged: StagedBuyFood): { [string]: any }
	profile.gold = staged.NewGold
	profile.inventory = staged.NewInventory

	return {
		ItemId = staged.ItemId,
		PurchasedAmount = staged.Amount,
		UnitPrice = staged.UnitPrice,
		TotalPrice = staged.TotalPrice,
		RemainingGold = staged.NewGold,
		NewFoodAmount = staged.NewInventory[staged.ItemId] or 0,
	}
end

return BuyFoodRules
