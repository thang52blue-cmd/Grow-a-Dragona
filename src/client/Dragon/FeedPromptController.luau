-- Wires the Feed ProximityPrompt on every world-visible Baby Dragon (tagged "BabyDragon" by
-- src/server/Services/DragonSpawner.luau) to FeedDragonTransaction. Per docs/prd/core-game-loop.md,
-- the interaction sends only DragonUID -- Food type/Feed count/target GrowthStage are all resolved
-- server-side. Also keeps the prompt's ActionText showing "Need Food" when the player owns none of
-- the dragon's Element's food items, purely a presentational read of the same ProfileUpdated
-- snapshot every other UI module already listens to -- never mutates persistent state.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TransactionType = require(Shared.Domain.TransactionType)
local FoodConfig = require(Shared.Data.FoodConfig)

local BABY_DRAGON_TAG = "BabyDragon"

local FeedPromptController = {}

local function isFoodOwned(element: string, inventory: { [string]: number }): boolean
	for _, itemId in FoodConfig[element] or {} do
		if (inventory[itemId] or 0) > 0 then
			return true
		end
	end
	return false
end

function FeedPromptController.Init(remotesFolder: Folder, requestIdGenerator: { Next: () -> number })
	local transactionRemote = remotesFolder:WaitForChild("Transaction") :: RemoteFunction
	local profileUpdated = remotesFolder:WaitForChild("ProfileUpdated") :: RemoteEvent

	local latestInventory: { [string]: number } = {}

	local function refreshHint(model: Instance)
		local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true) :: ProximityPrompt?
		local element = model:GetAttribute("Element")
		if not prompt or type(element) ~= "string" then
			return
		end
		prompt.ActionText = if isFoodOwned(element, latestInventory) then "Feed" else "Need Food"
	end

	local function attach(model: Instance)
		refreshHint(model)
		local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true) :: ProximityPrompt?
		if not prompt then
			return
		end
		prompt.Triggered:Connect(function()
			local dragonUID = model:GetAttribute("DragonUID")
			if type(dragonUID) ~= "string" then
				return
			end
			local requestId = requestIdGenerator.Next()
			transactionRemote:InvokeServer(requestId, TransactionType.FeedDragon, { DragonUID = dragonUID })
		end)
	end

	for _, model in CollectionService:GetTagged(BABY_DRAGON_TAG) do
		attach(model)
	end
	CollectionService:GetInstanceAddedSignal(BABY_DRAGON_TAG):Connect(attach)

	profileUpdated.OnClientEvent:Connect(function(snapshot)
		latestInventory = snapshot.inventory
		for _, model in CollectionService:GetTagged(BABY_DRAGON_TAG) do
			refreshHint(model)
		end
	end)
end

return FeedPromptController
