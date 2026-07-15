# Transactions

Server-authoritative modules. One transaction per valuable action; see AGENTS.md's transaction
model. Files are added when their backlog item is implemented with tests, not pre-scaffolded.

Expected modules (per AGENTS.md):

```text
Economy/BuyEggTransaction.luau
Economy/SellProductionEggTransaction.luau
Hatching/StartHatchTransaction.luau
Hatching/ClaimHatchTransaction.luau
Dragon/FeedDragonTransaction.luau
Dragon/SetFavoriteTransaction.luau
Production/AssignProducerTransaction.luau
Production/CollectNestTransaction.luau
Display/AssignDisplayTransaction.luau
Display/RemoveDisplayTransaction.luau
```
