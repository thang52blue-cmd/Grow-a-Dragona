-- Pure Validate/Stage/Commit rules for BuyEggTransaction (backlog item 2). No engine globals or
-- IO (AGENTS.md hard rule) so this is the part a Lune spec can actually prove atomic; the thin
-- server handler at src/server/Transactions/Economy/BuyEggTransaction.luau just adapts this to the
-- TransactionService handler contract.
local Types = require("../Types/Types")
local Currency = require("./Currency")
local Inventory = require("./Inventory")
local PayloadValidator = require("./PayloadValidator")
local Rarities = require("./Rarities")
local TransactionCode = require("./TransactionCode")

-- Hard ceiling independent of any single tier's own maxPurchaseAmount -- keeps one request from
-- ever requesting an absurd Amount even if a tier config is misconfigured.
local HARD_MAX_AMOUNT = 100

local function hatchEggItemId(rarity: string): string
	return "HatchEgg_" .. rarity
end

local BuyEggRules = {}
BuyEggRules.HatchEggItemId = hatchEggItemId

export type StagedBuyEgg = {
	-- Plain string, not Types.Rarity: Validate already confirmed membership via isValidRarity, and
	-- casting an `any`-typed payload field into a string-literal union here trips a luau-lsp
	-- widening quirk (repeats "string" once per union member instead of collapsing to `string`).
	Rarity: string,
	Amount: number,
	UnitPrice: number,
	TotalPrice: number,
	NewGold: number,
	NewInventory: Types.Inventory,
}

-- Validate: read-only. Never touches profile/inventory quantities, only checks the payload shape
-- and the (frozen, server-only) egg config.
function BuyEggRules.Validate(eggConfig: Types.EggConfig, payload: unknown): (boolean, number?)
	if type(payload) ~= "table" then
		return false, TransactionCode.InvalidRequest
	end
	local rawPayload = payload :: { [string]: any }

	if not Rarities.IsValid(rawPayload.Rarity) then
		return false, TransactionCode.InvalidEggType
	end

	if not PayloadValidator.IsPositiveInteger(rawPayload.Amount, HARD_MAX_AMOUNT) then
		return false, TransactionCode.InvalidAmount
	end

	local tierConfig = eggConfig.hatchingTiers[rawPayload.Rarity :: any]
	if not tierConfig then
		return false, TransactionCode.InvalidEggType
	end

	if not tierConfig.enabled then
		return false, TransactionCode.EggDisabled
	end

	if (rawPayload.Amount :: number) > tierConfig.maxPurchaseAmount then
		return false, TransactionCode.InvalidAmount
	end

	return true, nil
end

-- Stage: computes the full write set as new values, never mutating `profile`. Also re-checks the
-- Gold balance against the just-computed TotalPrice (the actual affordability check).
function BuyEggRules.Stage(
	eggConfig: Types.EggConfig,
	economyConfig: Types.EconomyConfig,
	profile: Types.Profile,
	payload: { [string]: any }
): (boolean, StagedBuyEgg?, number?)
	local rarity = payload.Rarity :: string
	local amount = payload.Amount :: number

	local tierConfig = eggConfig.hatchingTiers[rarity :: any]
	local unitPrice = tierConfig.goldPrice
	local totalPrice = unitPrice * amount

	local spendOk, newGold = Currency.spend(profile.gold, totalPrice)
	if not spendOk then
		return false, nil, TransactionCode.NotEnoughCurrency
	end

	local itemId = hatchEggItemId(rarity)
	local addOk, newInventory = Inventory.add(profile.inventory, itemId, amount, economyConfig.maxInventoryStack)
	if not addOk then
		return false, nil, TransactionCode.InventoryFull
	end

	return true,
		{
			Rarity = rarity,
			Amount = amount,
			UnitPrice = unitPrice,
			TotalPrice = totalPrice,
			NewGold = newGold,
			NewInventory = newInventory,
		},
		nil
end

-- Commit: the only step allowed to mutate `profile`. Applies the whole staged write set in one
-- shot (Gold + inventory together) so a successful transaction can never grant one without the
-- other.
function BuyEggRules.Commit(profile: Types.Profile, staged: StagedBuyEgg): { [string]: any }
	profile.gold = staged.NewGold
	profile.inventory = staged.NewInventory

	return {
		Rarity = staged.Rarity,
		PurchasedAmount = staged.Amount,
		UnitPrice = staged.UnitPrice,
		TotalPrice = staged.TotalPrice,
		RemainingGold = staged.NewGold,
		NewEggAmount = staged.NewInventory[hatchEggItemId(staged.Rarity)] or 0,
	}
end

return BuyEggRules
