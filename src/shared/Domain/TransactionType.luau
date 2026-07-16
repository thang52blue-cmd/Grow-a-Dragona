-- Numeric ids for TransactionService.RegisterHandler / the client Transaction request payload.
-- Only BuyEgg has an implemented handler so far (backlog item 2); the rest are reserved ids for
-- upcoming backlog items so payload shapes/ids don't need to change later.
local TransactionType = {
	BuyEgg = 10,
	BuyFood = 11,

	StartHatch = 20,
	ClaimHatch = 21,

	FeedDragon = 30,
	AssignProducer = 31,

	CollectNest = 40,
	SellProductionEgg = 41,
}

return table.freeze(TransactionType)
