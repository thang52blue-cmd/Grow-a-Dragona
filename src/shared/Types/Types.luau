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
	rarities: { [Rarity]: RarityConfig },
}

export type FoodConfig = { [Element]: { string } }

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
	HatchedAt: number,
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
