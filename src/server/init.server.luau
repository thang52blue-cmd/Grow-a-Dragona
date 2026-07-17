local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Restoring a saved lastPosition has to win the race against Roblox's own post-spawn
-- placement (repositioning a character inside CharacterAdded can get silently
-- overwritten a moment later by the engine's default spawn-finalization). Disabling
-- auto-load and pointing RespawnLocation at the saved spot *before* the character is
-- created is the standard robust way to control initial spawn position.
Players.CharacterAutoLoads = false

local DataService = require(script.Persistence.DataService)
local CurrencyService = require(script.Services.CurrencyService)
local InventoryService = require(script.Services.InventoryService)
local HatchSpawner = require(script.Services.HatchSpawner)
local DragonSpawner = require(script.Services.DragonSpawner)
local FarmPlotSpawner = require(script.Services.FarmPlotSpawner)
local NestSpawner = require(script.Services.NestSpawner)
local MarketStallSpawner = require(script.Services.MarketStallSpawner)
local RemotesSetup = require(script.Remotes.RemotesSetup)
local PlayerRuntimeStore = require(script.Runtime.PlayerRuntimeStore)
local TransactionService = require(script.Transactions.Core.TransactionService)
local BuyEggTransaction = require(script.Transactions.Economy.BuyEggTransaction)
local BuyFoodTransaction = require(script.Transactions.Economy.BuyFoodTransaction)
local StartHatchTransaction = require(script.Transactions.Hatching.StartHatchTransaction)
local ClaimHatchTransaction = require(script.Transactions.Hatching.ClaimHatchTransaction)
local FeedDragonTransaction = require(script.Transactions.Dragon.FeedDragonTransaction)
local AssignProducerTransaction = require(script.Transactions.Production.AssignProducerTransaction)
local CollectNestTransaction = require(script.Transactions.Production.CollectNestTransaction)
local SellProductionEggTransaction = require(script.Transactions.Economy.SellProductionEggTransaction)

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TransactionType = require(Shared.Domain.TransactionType)
local Types = require(Shared.Types.Types)
local FoodConfig = require(Shared.Data.FoodConfig) :: Types.FoodConfig
local EggConfig = require(Shared.Data.EggConfig) :: Types.EggConfig
local ProductionConfig = require(Shared.Data.ProductionConfig) :: Types.ProductionConfig
local StarterHatchRules = require(Shared.Domain.StarterHatchRules)
local ProductionRules = require(Shared.Domain.ProductionRules)

local TEST_GOLD_AMOUNT = 10
local TEST_GOLD_BIG_AMOUNT = 10000
local TEST_FOOD_AMOUNT = 5

-- Per-type rate limits on top of the global one TransactionService already enforces
-- (AGENTS.md §10).
TransactionService.RegisterHandler(TransactionType.BuyEgg, BuyEggTransaction)
TransactionService.SetTypeRateLimit(TransactionType.BuyEgg, 5, 2)
TransactionService.RegisterHandler(TransactionType.BuyFood, BuyFoodTransaction)
TransactionService.SetTypeRateLimit(TransactionType.BuyFood, 10, 2)
TransactionService.RegisterHandler(TransactionType.StartHatch, StartHatchTransaction)
TransactionService.SetTypeRateLimit(TransactionType.StartHatch, 10, 2)
TransactionService.RegisterHandler(TransactionType.ClaimHatch, ClaimHatchTransaction)
TransactionService.SetTypeRateLimit(TransactionType.ClaimHatch, 10, 2)
TransactionService.RegisterHandler(TransactionType.FeedDragon, FeedDragonTransaction)
TransactionService.SetTypeRateLimit(TransactionType.FeedDragon, 10, 2)
TransactionService.RegisterHandler(TransactionType.AssignProducer, AssignProducerTransaction)
TransactionService.SetTypeRateLimit(TransactionType.AssignProducer, 10, 2)
TransactionService.RegisterHandler(TransactionType.CollectNest, CollectNestTransaction)
TransactionService.SetTypeRateLimit(TransactionType.CollectNest, 10, 2)
TransactionService.RegisterHandler(TransactionType.SellProductionEgg, SellProductionEggTransaction)
TransactionService.SetTypeRateLimit(TransactionType.SellProductionEgg, 10, 2)

local remotesFolder = RemotesSetup.Init()

local profileUpdated = remotesFolder:WaitForChild("ProfileUpdated") :: RemoteEvent
local addTestGold = remotesFolder:WaitForChild("AddTestGold") :: RemoteEvent
local addTestGold10000 = remotesFolder:WaitForChild("AddTestGold10000") :: RemoteEvent
local spendTestGold = remotesFolder:WaitForChild("SpendTestGold") :: RemoteEvent
local addTestFood = remotesFolder:WaitForChild("AddTestFood") :: RemoteEvent
local addTestDragon = remotesFolder:WaitForChild("AddTestDragon") :: RemoteEvent
local fastForwardProduction = remotesFolder:WaitForChild("FastForwardProduction") :: RemoteEvent
local clearTestDragons = remotesFolder:WaitForChild("ClearTestDragons") :: RemoteEvent
local transactionRemote = remotesFolder:WaitForChild("Transaction") :: RemoteFunction

local function snapshotOf(player: Player): {
	gold: number,
	inventory: { [string]: number },
	pendingHatches: { [string]: any },
	dragons: { [string]: any },
	lastError: string?,
}
	local profile = DataService.Get(player.UserId)
	if not profile then
		return { gold = 0, inventory = {}, pendingHatches = {}, dragons = {}, lastError = "profile not loaded" }
	end
	return {
		gold = profile.gold,
		inventory = profile.inventory,
		pendingHatches = profile.pendingHatches,
		dragons = profile.dragons,
		lastError = nil,
	}
end

local function pushSnapshot(player: Player, lastError: string?)
	local snapshot = snapshotOf(player)
	snapshot.lastError = lastError
	profileUpdated:FireClient(player, snapshot)
end

-- Records where a still-live character currently stands into the (already-loaded)
-- profile, so DataService.Release persists it. Takes the character explicitly rather
-- than reading player.Character -- by the time PlayerRemoving fires (especially a
-- Studio "Stop", which tears characters down more abruptly than a real player leaving)
-- player.Character may already be nil/destroyed. player.CharacterRemoving fires *before*
-- that teardown, while the character instance is still valid, so that's the reliable
-- capture point; PlayerRemoving/BindToClose call this too as a best-effort fallback for
-- whatever character reference (if any) is still around.
local function saveCharacterPosition(player: Player, character: Model?)
	local profile = DataService.Get(player.UserId)
	if not profile then
		return
	end
	local target = character or player.Character
	local rootPart = target and target:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	local position = (rootPart :: BasePart).Position
	profile.lastPosition = { X = position.X, Y = position.Y, Z = position.Z }
end

-- A one-shot invisible SpawnLocation placed at the saved position, consumed by exactly
-- one LoadCharacter() call and then torn down -- a later respawn (e.g. after dying)
-- should fall back to the map's normal default spawn, not keep re-using an old session's
-- last position.
local function loadCharacterAtSavedPosition(player: Player, position: Types.Position)
	local spawnPart = Instance.new("SpawnLocation")
	spawnPart.Name = "RestoredSpawn"
	spawnPart.Anchored = true
	spawnPart.CanCollide = false
	spawnPart.CanQuery = false
	spawnPart.Transparency = 1
	spawnPart.Size = Vector3.new(4, 1, 4)
	spawnPart.CFrame = CFrame.new(position.X, position.Y, position.Z)
	spawnPart.Parent = Workspace

	player.RespawnLocation = spawnPart
	player:LoadCharacterAsync()
	player.RespawnLocation = nil :: any
	spawnPart:Destroy()
end

Players.PlayerAdded:Connect(function(player: Player)
	local ok, profile, err = DataService.Load(player.UserId, game.JobId)
	if ok then
		PlayerRuntimeStore.Create(player)

		if profile then
			local slotIds = {}
			for slotId in profile.farmSlots do
				table.insert(slotIds, slotId)
			end
			table.sort(slotIds)
			FarmPlotSpawner.EnsurePlot(player, slotIds)

			-- Free first-join Hatching Egg (GDD Section 1) -- granted at most once per
			-- profile (StarterHatchRules.ShouldGrant), directly here rather than through
			-- TransactionService: there's no client payload to validate/dedupe, this is a
			-- one-shot server-initiated grant that can only ever run once per profile.
			-- Recorded into pendingHatches before the character loads, so the normal
			-- HatchSpawner.RespawnAllPending call below picks it up and spawns its world
			-- egg the same way any other pending hatch would reappear after rejoin.
			if StarterHatchRules.ShouldGrant(profile) then
				local worldPosition = FarmPlotSpawner.StarterEggPosition(player)
				local position: Types.Position = { X = worldPosition.X, Y = worldPosition.Y, Z = worldPosition.Z }
				local staged = StarterHatchRules.Stage(EggConfig, profile, os.time(), position, math.random())
				StarterHatchRules.Commit(profile, staged)
			end
		end

		player.CharacterAdded:Once(function()
			if profile then
				HatchSpawner.RespawnAllPending(player, profile)
				DragonSpawner.RespawnAll(player, profile)
				MarketStallSpawner.EnsureStall(player)
				for slotId, slot in profile.farmSlots do
					if slot.ProductionStartedAt then
						NestSpawner.EnsureNest(
							player,
							slotId,
							FarmPlotSpawner.SlotPosition(player, slotId),
							slot.UncollectedEggCount
						)
					end
				end
			end
		end)

		player.CharacterRemoving:Connect(function(character: Model)
			saveCharacterPosition(player, character)
		end)

		if profile and profile.lastPosition then
			loadCharacterAtSavedPosition(player, profile.lastPosition)
		else
			player:LoadCharacterAsync()
		end
	else
		-- Profile failed to load (e.g. DataStore error, session lock) -- still let the
		-- player load into a default spawn rather than leaving them with no character.
		player:LoadCharacterAsync()
	end
	pushSnapshot(player, if ok then nil else err)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	PlayerRuntimeStore.SetClosing(player, true)
	saveCharacterPosition(player)
	HatchSpawner.DespawnAll(player)
	DragonSpawner.DespawnAll(player)
	NestSpawner.DespawnAll(player)
	MarketStallSpawner.Despawn(player)
	FarmPlotSpawner.Despawn(player)
	local ok, err = DataService.Release(player.UserId)
	if not ok then
		warn(`[GrowADragona] Save failed for user {player.UserId} on leave: {err}`)
	end
	PlayerRuntimeStore.Remove(player)
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		PlayerRuntimeStore.SetClosing(player, true)
		saveCharacterPosition(player)
		local ok, err = DataService.Release(player.UserId)
		if not ok then
			warn(`[GrowADragona] Save failed for user {player.UserId} on shutdown: {err}`)
		end
	end
end)

addTestGold.OnServerEvent:Connect(function(player: Player)
	local ok, _newBalance, err = CurrencyService.AddGold(player, TEST_GOLD_AMOUNT)
	pushSnapshot(player, if ok then nil else err)
end)

addTestGold10000.OnServerEvent:Connect(function(player: Player)
	local ok, _newBalance, err = CurrencyService.AddGold(player, TEST_GOLD_BIG_AMOUNT)
	pushSnapshot(player, if ok then nil else err)
end)

spendTestGold.OnServerEvent:Connect(function(player: Player)
	local ok, _newBalance, err = CurrencyService.SpendGold(player, TEST_GOLD_AMOUNT)
	pushSnapshot(player, if ok then nil else err)
end)

-- Grants a fixed amount of every food item across every element -- Feed Dragon (backlog item 5)
-- has no real acquisition path for Food yet (no Buy Food transaction), and a dragon's Element is
-- rolled randomly at hatch, so a manual tester can't know in advance which one food item to grant.
-- Same manual-test-lever pattern as AddTestGold above.
addTestFood.OnServerEvent:Connect(function(player: Player)
	local lastErr: string? = nil
	for _, items in FoodConfig do
		for _, itemId in items do
			local ok, _newQuantity, err = InventoryService.AddItem(player, itemId, TEST_FOOD_AMOUNT)
			if not ok then
				lastErr = err
			end
		end
	end
	pushSnapshot(player, lastErr)
end)

-- Grants an already-Adult, already-unassigned dragon -- backlog item 6 (Assign Producer / Collect
-- Nest) has no real acquisition path to an Adult dragon fast enough for manual testing (feeding a
-- Baby 4 times first). Same manual-test-lever pattern as AddTestFood above.
addTestDragon.OnServerEvent:Connect(function(player: Player)
	local profile = DataService.Get(player.UserId)
	if not profile then
		pushSnapshot(player, "profile not loaded")
		return
	end

	local dragonId = tostring(profile.meta.nextEntityId)
	profile.dragons[dragonId] = {
		Id = dragonId,
		Rarity = "Common",
		Element = "Fire",
		GrowthStage = "Adult",
		FeedCount = 4,
		HatchedAt = os.time(),
		AssignedSlotId = nil,
	}
	profile.meta.nextEntityId += 1
	pushSnapshot(player, nil)
end)

-- Rewinds a Farm Slot's ProductionStartedAt so completed-cycle math can be exercised without
-- waiting the real 180s production interval. Test-only lever, same rationale as AddTestFood/
-- AddTestDragon -- never touches gold/inventory, only lets a real CollectNestTransaction see
-- elapsed time that has genuinely already been recorded on the slot.
fastForwardProduction.OnServerEvent:Connect(function(player: Player, slotIdRaw: unknown, secondsBackRaw: unknown)
	local profile = DataService.Get(player.UserId)
	if not profile then
		pushSnapshot(player, "profile not loaded")
		return
	end

	local slotId = tonumber(slotIdRaw :: any)
	local secondsBack = tonumber(secondsBackRaw :: any)
	local slot = slotId and profile.farmSlots[slotId]
	if not slot or not slot.ProductionStartedAt or not secondsBack then
		pushSnapshot(player, "invalid FastForwardProduction request")
		return
	end

	slot.ProductionStartedAt -= secondsBack
	pushSnapshot(player, nil)
end)

-- Wipes every owned dragon and any Farm Slot assignment referencing one, then despawns the
-- Nursery so a tester can restart the Hatch->Feed->Assign->Collect loop from a clean slate.
-- Test-only lever, same rationale as AddTestFood/AddTestDragon -- never touches gold/inventory/
-- eggs, only the dragon-related profile sections plus their Runtime-only world models.
clearTestDragons.OnServerEvent:Connect(function(player: Player)
	local profile = DataService.Get(player.UserId)
	if not profile then
		pushSnapshot(player, "profile not loaded")
		return
	end

	profile.dragons = {}
	for slotId in profile.farmSlots do
		profile.farmSlots[slotId] = {
			SlotId = slotId,
			AssignedDragonUID = nil,
			ProductionStartedAt = nil,
			UncollectedEggCount = 0,
			IsProductionPaused = false,
		}
	end

	DragonSpawner.DespawnAll(player)
	pushSnapshot(player, nil)
end)

transactionRemote.OnServerInvoke = function(player: Player, requestId: unknown, typeId: unknown, payload: unknown)
	local result = TransactionService.Submit(player, requestId, typeId, payload)

	-- World-spawn/despawn of the hatching-egg decoration is a Runtime-only post-commit
	-- effect (AGENTS.md: "Post-commit UI/effect events cannot mutate persistent state") --
	-- it never touches the profile, so it's safe to trigger here regardless of the
	-- Transaction handler's own Commit having already run.
	if result.Success and typeId == TransactionType.StartHatch and result.Data then
		HatchSpawner.Spawn(player, result.Data.HatchId, result.Data.Rarity, result.Data.FinishAt, result.Data.Position)
	elseif result.Success and typeId == TransactionType.ClaimHatch then
		local hatchId = (payload :: any) and (payload :: any).HatchId
		if type(hatchId) == "string" then
			HatchSpawner.Despawn(player, hatchId)
		end
		if result.Data then
			local profile = DataService.Get(player.UserId)
			local dragon = profile and profile.dragons[result.Data.DragonId]
			if dragon then
				DragonSpawner.Spawn(player, result.Data.DragonId, dragon)
			end
		end
	elseif result.Success and typeId == TransactionType.FeedDragon and result.Data then
		if result.Data.BecameAdult then
			-- Swap the Baby model for the Adult one in place, rather than despawning --
			-- per direct user request, the Adult should stay visible in the Nursery until
			-- assigned to a Farm Slot (backlog item 6's own world-presence pass, not yet built).
			DragonSpawner.Despawn(player, result.Data.DragonUID)
			local profile = DataService.Get(player.UserId)
			local dragon = profile and profile.dragons[result.Data.DragonUID]
			if dragon then
				DragonSpawner.Spawn(player, result.Data.DragonUID, dragon)
				-- The 4th Feed also auto-starts production on the dragon's already-assigned
				-- Farm Slot (ADR-005) -- the Nest materializes the same moment (GDD §5).
				if dragon.AssignedSlotId then
					local slotPosition = FarmPlotSpawner.SlotPosition(player, dragon.AssignedSlotId)
					NestSpawner.EnsureNest(player, dragon.AssignedSlotId, slotPosition, 0)
				end
			end
		else
			DragonSpawner.UpdateFeedCount(player, result.Data.DragonUID, result.Data.FeedCount)
		end
	elseif result.Success and typeId == TransactionType.AssignProducer and result.Data then
		-- Manual re-assignment (e.g. a future Storage/swap flow) moves a dragon's world
		-- model to its newly-assigned slot the same way a fresh hatch does.
		DragonSpawner.Despawn(player, result.Data.DragonUID)
		local profile = DataService.Get(player.UserId)
		local dragon = profile and profile.dragons[result.Data.DragonUID]
		if dragon then
			DragonSpawner.Spawn(player, result.Data.DragonUID, dragon)
		end
		local slotPosition = FarmPlotSpawner.SlotPosition(player, result.Data.SlotId)
		NestSpawner.EnsureNest(player, result.Data.SlotId, slotPosition, 0)
	elseif result.Success and typeId == TransactionType.CollectNest and result.Data then
		local slotPosition = FarmPlotSpawner.SlotPosition(player, result.Data.SlotId)
		NestSpawner.EnsureNest(player, result.Data.SlotId, slotPosition, 0)
	end

	pushSnapshot(player, if result.Success then nil else `transaction failed: code {result.Code}`)
	return result
end

-- Periodic display-only refresh so a Nest's egg pile visibly grows between Collects instead of
-- only updating right after a transaction (GDD §5: "Visual states as eggs accumulate"). Reuses
-- the exact same pure ProductionRules.Advance already used by CollectNestTransaction -- this only
-- ever updates FarmSlot bookkeeping (UncollectedEggCount/ProductionStartedAt/IsProductionPaused),
-- the same fields CollectNest itself would compute at collect time, and never touches Gold or
-- productionEggInventory, so it grants nothing and can't be exploited for extra value.
task.spawn(function()
	while true do
		task.wait(15)
		for _, player in Players:GetPlayers() do
			local profile = DataService.Get(player.UserId)
			if profile then
				local now = os.time()
				for slotId, slot in profile.farmSlots do
					if slot.ProductionStartedAt then
						local advanced = ProductionRules.Advance(slot, now, ProductionConfig)
						if advanced.UncollectedEggCount ~= slot.UncollectedEggCount then
							profile.farmSlots[slotId] = advanced
							local slotPosition = FarmPlotSpawner.SlotPosition(player, slotId)
							NestSpawner.EnsureNest(player, slotId, slotPosition, advanced.UncollectedEggCount)
						end
					end
				end
			end
		end
	end
end)
