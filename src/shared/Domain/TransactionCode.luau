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

	InvalidAmount = 20,
	NotEnoughCurrency = 21,
	InventoryFull = 22,

	InternalError = 100,
}

return table.freeze(TransactionCode)
