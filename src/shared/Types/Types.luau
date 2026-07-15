export type Element = "Fire" | "Water" | "Earth" | "Light" | "Dark"

export type Rarity = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic"

export type EggVariant = "Normal" | "Mini" | "Heavy" | "Giant" | "Golden"

export type EggOdds = { [Rarity]: number }

export type HatchingTierConfig = {
	goldPrice: number,
	odds: EggOdds,
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

export type Session = {
	jobId: string?,
	updatedAt: number,
}

export type ProfileMeta = {
	schemaVersion: number,
	session: Session,
}

export type Profile = {
	gold: number,
	inventory: Inventory,
	meta: ProfileMeta,
}

return {}
