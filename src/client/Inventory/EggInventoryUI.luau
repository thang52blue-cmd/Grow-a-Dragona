-- Player-facing Inventory panel: shows the 3D icon + owned count for each of the 5
-- hatching-egg rarities, a Hatch button per rarity (enabled only while owned > 0), and
-- plain-text readouts for in-progress hatches and owned dragons -- all read live off the
-- same ProfileUpdated snapshot EggShopUI already listens to. Dragons have no icon/model
-- yet by design (backlog item 4 scope): text only until a later pass adds one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuyEggRules = require(Shared.Domain.BuyEggRules)
local TransactionType = require(Shared.Domain.TransactionType)
local TransactionCode = require(Shared.Domain.TransactionCode)

local RarityDisplay = require(script.Parent.Parent.UI.RarityDisplay)
local EggIconViewport = require(script.Parent.Parent.UI.EggIconViewport)
local RequestIdGenerator = require(script.Parent.Parent.RequestIdGenerator)

local RARITY_ORDER = RarityDisplay.Order
local RARITY_COLOR = RarityDisplay.Color

local CODE_MESSAGE: { [number]: string } = {
	[TransactionCode.NoEggToHatch] = "You don't own that egg.",
	[TransactionCode.RateLimited] = "Too many requests, slow down.",
	[TransactionCode.InvalidEggType] = "Unknown egg type.",
	[TransactionCode.ProfileNotLoaded] = "Profile not loaded yet.",
	[TransactionCode.PlayerClosing] = "Session is closing.",
	[TransactionCode.QueueFull] = "Server busy, try again.",
}

local EggInventoryUI = {}

function EggInventoryUI.Init(player: Player, remotesFolder: Folder): ScreenGui
	local profileUpdated = remotesFolder:WaitForChild("ProfileUpdated") :: RemoteEvent
	local transactionRemote = remotesFolder:WaitForChild("Transaction") :: RemoteFunction

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "EggInventoryGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local openButton = Instance.new("TextButton")
	openButton.Name = "OpenInventoryButton"
	openButton.Size = UDim2.fromOffset(120, 44)
	openButton.Position = UDim2.new(1, -140, 1, -116)
	openButton.Text = "Inventory"
	openButton.Font = Enum.Font.SourceSansBold
	openButton.TextSize = 20
	openButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	openButton.TextColor3 = Color3.new(1, 1, 1)
	openButton.Parent = screenGui

	local inventoryFrame = Instance.new("Frame")
	inventoryFrame.Name = "InventoryFrame"
	inventoryFrame.Size = UDim2.fromOffset(500, 470)
	inventoryFrame.Position = UDim2.new(0.5, -250, 0.5, -235)
	inventoryFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	inventoryFrame.Visible = false
	inventoryFrame.Parent = screenGui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -44, 0, 40)
	titleLabel.Position = UDim2.fromOffset(12, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Inventory"
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.TextSize = 26
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = inventoryFrame

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.fromOffset(32, 32)
	closeButton.Position = UDim2.new(1, -40, 0, 8)
	closeButton.Text = "X"
	closeButton.Font = Enum.Font.SourceSansBold
	closeButton.TextSize = 18
	closeButton.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Parent = inventoryFrame

	local rowsFrame = Instance.new("Frame")
	rowsFrame.Name = "RowsFrame"
	rowsFrame.Size = UDim2.new(1, -24, 0, 272)
	rowsFrame.Position = UDim2.fromOffset(12, 56)
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.Parent = inventoryFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = rowsFrame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -24, 0, 24)
	statusLabel.Position = UDim2.fromOffset(12, 336)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.Font = Enum.Font.SourceSans
	statusLabel.TextSize = 15
	statusLabel.TextWrapped = true
	statusLabel.TextColor3 = Color3.fromRGB(230, 100, 100)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = inventoryFrame

	local hatchingLabel = Instance.new("TextLabel")
	hatchingLabel.Name = "HatchingLabel"
	hatchingLabel.Size = UDim2.new(1, -24, 0, 44)
	hatchingLabel.Position = UDim2.fromOffset(12, 364)
	hatchingLabel.BackgroundTransparency = 1
	hatchingLabel.Text = "Hatching: (none)"
	hatchingLabel.Font = Enum.Font.SourceSans
	hatchingLabel.TextSize = 15
	hatchingLabel.TextWrapped = true
	hatchingLabel.TextYAlignment = Enum.TextYAlignment.Top
	hatchingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	hatchingLabel.TextXAlignment = Enum.TextXAlignment.Left
	hatchingLabel.Parent = inventoryFrame

	local dragonsLabel = Instance.new("TextLabel")
	dragonsLabel.Name = "DragonsLabel"
	dragonsLabel.Size = UDim2.new(1, -24, 0, 44)
	dragonsLabel.Position = UDim2.fromOffset(12, 412)
	dragonsLabel.BackgroundTransparency = 1
	dragonsLabel.Text = "Dragons: (none)"
	dragonsLabel.Font = Enum.Font.SourceSans
	dragonsLabel.TextSize = 15
	dragonsLabel.TextWrapped = true
	dragonsLabel.TextYAlignment = Enum.TextYAlignment.Top
	dragonsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	dragonsLabel.TextXAlignment = Enum.TextXAlignment.Left
	dragonsLabel.Parent = inventoryFrame

	local countLabels: { [string]: TextLabel } = {}
	local hatchButtons: { [string]: TextButton } = {}
	local ownedCounts: { [string]: number } = {}

	local function refreshHatchButtons()
		for rarity, button in hatchButtons do
			if (ownedCounts[rarity] or 0) > 0 then
				button.Text = "Hatch"
				button.BackgroundColor3 = Color3.fromRGB(60, 130, 60)
				button.AutoButtonColor = true
			else
				button.Text = "Hatch"
				button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
				button.AutoButtonColor = false
			end
		end
	end

	for order, rarity in RARITY_ORDER do
		local row = Instance.new("Frame")
		row.Name = rarity .. "Row"
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 48)
		row.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		row.Parent = rowsFrame

		local accent = Instance.new("Frame")
		accent.Name = "Accent"
		accent.Size = UDim2.new(0, 6, 1, 0)
		accent.BorderSizePixel = 0
		accent.BackgroundColor3 = RARITY_COLOR[rarity]
		accent.Parent = row

		local iconViewport = EggIconViewport.Create(rarity :: any)
		iconViewport.Size = UDim2.fromOffset(40, 40)
		iconViewport.Position = UDim2.fromOffset(14, 4)
		iconViewport.Parent = row

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.Size = UDim2.fromOffset(130, 48)
		nameLabel.Position = UDim2.fromOffset(62, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = rarity .. " Egg"
		nameLabel.Font = Enum.Font.SourceSansBold
		nameLabel.TextSize = 18
		nameLabel.TextScaled = true
		nameLabel.TextWrapped = false
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = row

		local countLabel = Instance.new("TextLabel")
		countLabel.Name = "CountLabel"
		countLabel.Size = UDim2.fromOffset(100, 48)
		countLabel.Position = UDim2.fromOffset(198, 0)
		countLabel.BackgroundTransparency = 1
		countLabel.Text = "Owned: 0"
		countLabel.Font = Enum.Font.SourceSans
		countLabel.TextSize = 16
		countLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		countLabel.TextXAlignment = Enum.TextXAlignment.Left
		countLabel.Parent = row

		local hatchButton = Instance.new("TextButton")
		hatchButton.Name = "HatchButton"
		hatchButton.Size = UDim2.fromOffset(110, 36)
		hatchButton.Position = UDim2.new(0, 306, 0.5, -18)
		hatchButton.Text = "Hatch"
		hatchButton.Font = Enum.Font.SourceSansBold
		hatchButton.TextSize = 16
		hatchButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		hatchButton.AutoButtonColor = false
		hatchButton.TextColor3 = Color3.new(1, 1, 1)
		hatchButton.Parent = row

		hatchButton.Activated:Connect(function()
			if (ownedCounts[rarity] or 0) <= 0 then
				return
			end

			local requestId = RequestIdGenerator.Next()
			local result = transactionRemote:InvokeServer(requestId, TransactionType.StartHatch, { Rarity = rarity })

			if not result.Success then
				statusLabel.Text = CODE_MESSAGE[result.Code] or `Hatch failed (code {result.Code}).`
			else
				statusLabel.Text = ""
			end
		end)

		countLabels[rarity] = countLabel
		hatchButtons[rarity] = hatchButton
	end

	openButton.Activated:Connect(function()
		inventoryFrame.Visible = not inventoryFrame.Visible
	end)

	closeButton.Activated:Connect(function()
		inventoryFrame.Visible = false
	end)

	profileUpdated.OnClientEvent:Connect(function(snapshot)
		for _, rarity in RARITY_ORDER do
			local itemId = BuyEggRules.HatchEggItemId(rarity)
			local count = snapshot.inventory[itemId] or 0
			ownedCounts[rarity] = count
			countLabels[rarity].Text = `Owned: {count}`
		end
		refreshHatchButtons()

		local hatchingLines = {}
		local now = os.time()
		for _, pending in snapshot.pendingHatches do
			local remaining = math.max(0, math.ceil(pending.FinishAt - now))
			table.insert(hatchingLines, `{pending.Rarity} ({remaining}s)`)
		end
		hatchingLabel.Text = if #hatchingLines > 0
			then "Hatching: " .. table.concat(hatchingLines, ", ")
			else "Hatching: (none)"

		local dragonCounts: { [string]: number } = {}
		for _, dragon in snapshot.dragons do
			dragonCounts[dragon.Rarity] = (dragonCounts[dragon.Rarity] or 0) + 1
		end
		local dragonLines = {}
		for _, rarity in RARITY_ORDER do
			local count = dragonCounts[rarity]
			if count and count > 0 then
				table.insert(dragonLines, `{rarity} x{count}`)
			end
		end
		dragonsLabel.Text = if #dragonLines > 0
			then "Dragons: " .. table.concat(dragonLines, ", ")
			else "Dragons: (none)"
	end)

	return screenGui
end

return EggInventoryUI
