-- Wires the Feed ProximityPrompt on every world-visible Baby Dragon (tagged "BabyDragon" by
-- src/server/Services/DragonSpawner.luau) to FeedDragonTransaction. Per docs/prd/core-game-loop.md,
-- the interaction sends only DragonUID -- Food type/Feed count/target GrowthStage are all resolved
-- server-side.
--
-- Per direct user spec: without the matching Food, no Feed *button* should be shown at all (not
-- just a relabeled one still clickable) -- the ProximityPrompt itself is disabled, and a separate
-- non-interactive BillboardGui reading "Need {Element} Food" takes its place instead, nudging the
-- player toward the Food Shop. Both are purely a presentational read of the same ProfileUpdated
-- snapshot every other UI module already listens to -- never mutates persistent state. An Adult
-- gets neither (DragonSpawner never attaches a FeedPrompt to an Adult model in the first place).
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

-- Built lazily (once per model, on first refresh) rather than by DragonSpawner -- this hint is
-- purely a client-side presentational read of the local player's own inventory, not
-- server-authoritative world state, so it doesn't belong in the server-built model.
local function ensureNeedFoodHint(anchorPart: BasePart): TextLabel
	local existing = anchorPart:FindFirstChild("NeedFoodHint") :: BillboardGui?
	if existing then
		return existing:FindFirstChildWhichIsA("TextLabel") :: TextLabel
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NeedFoodHint"
	billboard.Size = UDim2.fromOffset(170, 44)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.Parent = anchorPart

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 130, 130)
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = billboard

	return label
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

		local anchorPart = prompt.Parent :: BasePart
		local hintLabel = ensureNeedFoodHint(anchorPart)
		local hintBillboard = hintLabel.Parent :: BillboardGui

		if isFoodOwned(element, latestInventory) then
			prompt.Enabled = true
			prompt.ActionText = "Feed"
			hintBillboard.Enabled = false
		else
			prompt.Enabled = false
			hintBillboard.Enabled = true
			hintLabel.Text = `Need {element} Food\n(Visit the Food Shop)`
		end
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
