-- Numeric result codes returned in TransactionResult.Code. Numeric, not string, so handlers/tests
-- compare by value; string names are for logs/UI debug only (see AGENTS.md transaction model).
local TransactionCode = {
	Success = 0,

	InvalidRequest = 1,
	ProfileNotLoaded = 2,
	PlayerClosing = 3,
	QueueFull = 4,
	DuplicateRequest = 5,
	RateLimited = 6,

	InvalidEggType = 10,
	EggDisabled = 11,
	FeatureLocked = 12,
	InvalidFoodType = 13,

	InvalidAmount = 20,
	NotEnoughCurrency = 21,
	InventoryFull = 22,

	NoEggToHatch = 30,
	NoHatchInProgress = 31,
	HatchNotReady = 32,

	DragonNotFound = 40,
	DragonAlreadyAdult = 41,
	MissingFood = 42,

	SlotNotFound = 43,
	SlotOccupied = 44,
	DragonNotAdult = 45,
	DragonAlreadyAssigned = 46,
	NestEmpty = 47,
	NothingToSell = 48,

	InternalError = 100,
}

return table.freeze(TransactionCode)
