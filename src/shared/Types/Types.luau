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

export type EggConfig = {
	hatchingTiers: { [Rarity]: HatchingTierConfig },
	productionVariants: { [EggVariant]: { goldMultiplier: number } },
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

export type ProductionConfig = {
	productionIntervalSeconds: number,
	nestCapacity: number,
	startingFarmSlots: number,
}

export type Session = {
	jobId: string?,
	updatedAt: number,
}

export type ProfileMeta = {
	schemaVersion: number,
	session: Session,
	nextEntityId: number,
}

export type Profile = {
	gold: number,
	inventory: Inventory,
	pendingHatches: { [string]: PendingHatch },
	dragons: { [string]: DragonRecord },
	farmSlots: { [number]: FarmSlot },
	productionEggInventory: ProductionEggInventory,
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
