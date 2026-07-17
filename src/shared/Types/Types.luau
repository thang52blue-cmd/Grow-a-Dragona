export type Element = "Fire" | "Water" | "Earth" | "Light" | "Dark"

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type EggVariant = "Normal" | "Mini" | "Heavy" | "Giant" | "Golden"

export type EggOdds = { [Rarity]: number }

export type HatchingTierConfig = {
	goldPrice: number,
	odds: EggOdds,
	enabled: boolean,
	maxPurchaseAmount: number,
	hatchDurationSeconds: number,
}

export type ProductionVariantConfig = {
	goldMultiplier: number,
	baseSellValue: number,
}

export type EggConfig = {
	hatchingTiers: { [Rarity]: HatchingTierConfig },
	productionVariants: { [EggVariant]: ProductionVariantConfig },
}

export type ElementConfig = {
	foodType: string,
	synergyType: string,
}

export type RarityConfig = {
	productionMultiplier: number,
}

export type DragonConfig = {
	elements: { [Element]: ElementConfig },
	elementOdds: { [Element]: number },
	rarities: { [Rarity]: RarityConfig },
}

export type GrowthStage = "Baby_0" | "Baby_1" | "Baby_2" | "Baby_3" | "Adult"

export type FoodConfig = { [Element]: { string } }

export type FoodShopConfig = { [string]: number }

export type EconomyConfig = {
	startingGold: number,
	maxGold: number,
	maxInventoryStack: number,
}

export type Inventory = { [string]: number }

-- Plain X/Y/Z, not a Vector3 -- src/shared/ must stay engine-global-free (AGENTS.md hard
-- rule) and this needs to round-trip through the pure ProfileSchema validator and Lune
-- specs. Engine-glue code (HatchSpawner, init.server) converts to/from Vector3 at the
-- boundary.
export type Position = {
	X: number,
	Y: number,
	Z: number,
}

export type PendingHatch = {
	Id: string,
	Rarity: Rarity,
	StartedAt: number,
	FinishAt: number,
	Position: Position,
}

export type DragonRecord = {
	Id: string,
	Rarity: Rarity,
	Element: Element,
	GrowthStage: GrowthStage,
	FeedCount: number,
	HatchedAt: number,
	AssignedSlotId: number?,
}

export type FarmSlot = {
	SlotId: number,
	AssignedDragonUID: string?,
	ProductionStartedAt: number?,
	UncollectedEggCount: number,
	IsProductionPaused: boolean,
}

export type ProductionEggInventory = {
	Normal: number,
	Mini: number,
	Heavy: number,
	Giant: number,
	Golden: number,
}

-- Per-Rarity breakdown of the laying dragon's rarity, keyed the same way as `Profile.dragons`'
-- own `Rarity` field -- needed (not just a flat variant bucket) because SellProductionEggRules
-- must apply the *laying* dragon's own rarity multiplier per egg (GDD §8), which a flat
-- `{variant: count}` bucket can't distinguish. See adr/ADR-006-production-egg-rarity-inventory.md.
export type ProductionEggInventoryByRarity = { [Rarity]: ProductionEggInventory }

export type ProductionConfig = {
	productionIntervalSeconds: number,
	nestCapacity: number,
	startingFarmSlots: number,
	-- GDD §2 "Production egg variant odds scale with dragon rarity" table -- each Rarity's own
	-- variant odds, summing to 1, used by CollectNestRules to roll each newly-produced egg's
	-- variant against the *laying* dragon's rarity.
	variantOddsByRarity: { [Rarity]: { [EggVariant]: number } },
}

export type Session = {
	jobId: string?,
	updatedAt: number,
}

export type ProfileMeta = {
	schemaVersion: number,
	session: Session,
	nextEntityId: number,
	starterHatchGranted: boolean,
}

export type Profile = {
	gold: number,
	inventory: Inventory,
	pendingHatches: { [string]: PendingHatch },
	dragons: { [string]: DragonRecord },
	farmSlots: { [number]: FarmSlot },
	productionEggInventory: ProductionEggInventoryByRarity,
	lastPosition: Position?,
	meta: ProfileMeta,
}

export type TransactionResult = {
	Success: boolean,
	Code: number,
	Revision: number?,
	Data: { [string]: any }?,
}

return {}
