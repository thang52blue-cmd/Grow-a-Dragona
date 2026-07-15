local Players = game:GetService("Players")

local DataService = require(script.Persistence.DataService)
local CurrencyService = require(script.Services.CurrencyService)
local InventoryService = require(script.Services.InventoryService)
local RemotesSetup = require(script.Remotes.RemotesSetup)

local TEST_GOLD_AMOUNT = 10
local TEST_FOOD_ITEM = "Fish"
local TEST_FOOD_AMOUNT = 1

local remotesFolder = RemotesSetup.Init()

local profileUpdated = remotesFolder:WaitForChild("ProfileUpdated") :: RemoteEvent
local addTestGold = remotesFolder:WaitForChild("AddTestGold") :: RemoteEvent
local spendTestGold = remotesFolder:WaitForChild("SpendTestGold") :: RemoteEvent
local addTestFood = remotesFolder:WaitForChild("AddTestFood") :: RemoteEvent
local removeTestFood = remotesFolder:WaitForChild("RemoveTestFood") :: RemoteEvent

local function snapshotOf(player: Player): { gold: number, inventory: { [string]: number }, lastError: string? }
	local profile = DataService.Get(player.UserId)
	if not profile then
		return { gold = 0, inventory = {}, lastError = "profile not loaded" }
	end
	return { gold = profile.gold, inventory = profile.inventory, lastError = nil }
end

local function pushSnapshot(player: Player, lastError: string?)
	local snapshot = snapshotOf(player)
	snapshot.lastError = lastError
	profileUpdated:FireClient(player, snapshot)
end

Players.PlayerAdded:Connect(function(player: Player)
	local ok, _profile, err = DataService.Load(player.UserId, game.JobId)
	pushSnapshot(player, if ok then nil else err)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local ok, err = DataService.Release(player.UserId)
	if not ok then
		warn(`[GrowADragona] Save failed for user {player.UserId} on leave: {err}`)
	end
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
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

spendTestGold.OnServerEvent:Connect(function(player: Player)
	local ok, _newBalance, err = CurrencyService.SpendGold(player, TEST_GOLD_AMOUNT)
	pushSnapshot(player, if ok then nil else err)
end)

addTestFood.OnServerEvent:Connect(function(player: Player)
	local ok, _newQuantity, err = InventoryService.AddItem(player, TEST_FOOD_ITEM, TEST_FOOD_AMOUNT)
	pushSnapshot(player, if ok then nil else err)
end)

removeTestFood.OnServerEvent:Connect(function(player: Player)
	local ok, _newQuantity, err = InventoryService.RemoveItem(player, TEST_FOOD_ITEM, TEST_FOOD_AMOUNT)
	pushSnapshot(player, if ok then nil else err)
end)
