-- Player-facing Food Shop panel: lists every Food item from FoodConfig, grouped by Element, with
-- its price from FoodShopConfig, and lets the player buy one via the BuyFood transaction. Purely
-- presentation + remote glue -- price/afford/existence checks are re-validated server-side by
-- BuyFoodRules regardless of what the button shows here. Mirrors EggShopUI.luau's structure.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TransactionType = require(Shared.Domain.TransactionType)
local TransactionCode = require(Shared.Domain.TransactionCode)
local FoodConfig = require(Shared.Data.FoodConfig)
local FoodShopConfig = require(Shared.Data.FoodShopConfig)
local Elements = require(Shared.Domain.Elements)

local RequestIdGenerator = require(script.Parent.Parent.RequestIdGenerator)

local ELEMENT_ORDER = Elements.List
local ELEMENT_COLOR: { [string]: Color3 } = {
	Fire = Color3.fromRGB(230, 90, 60),
	Water = Color3.fromRGB(70, 140, 220),
	Earth = Color3.fromRGB(140, 110, 70),
	Light = Color3.fromRGB(230, 210, 90),
	Dark = Color3.fromRGB(120, 80, 160),
}

local CODE_MESSAGE: { [number]: string } = {
	[TransactionCode.NotEnoughCurrency] = "Not enough gold.",
	[TransactionCode.InventoryFull] = "Inventory is full.",
	[TransactionCode.InvalidFoodType] = "Unknown food item.",
	[TransactionCode.RateLimited] = "Too many requests, slow down.",
	[TransactionCode.InvalidAmount] = "Invalid purchase amount.",
	[TransactionCode.ProfileNotLoaded] = "Profile not loaded yet.",
	[TransactionCode.PlayerClosing] = "Session is closing.",
	[TransactionCode.QueueFull] = "Server busy, try again.",
}

local ROW_HEIGHT = 40
local HEADER_HEIGHT = 28
local ROW_SPACING = 6

local function formatGold(amount: number): string
	local formatted = tostring(math.floor(amount))
	local isNegative = formatted:sub(1, 1) == "-"
	if isNegative then
		formatted = formatted:sub(2)
	end
	while true do
		local replaced
		formatted, replaced = formatted:gsub("^(%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then
			break
		end
	end
	return (if isNegative then "-" else "") .. formatted
end

local FoodShopUI = {}

function FoodShopUI.Init(player: Player, remotesFolder: Folder): ScreenGui
	local transactionRemote = remotesFolder:WaitForChild("Transaction") :: RemoteFunction
	local profileUpdated = remotesFolder:WaitForChild("ProfileUpdated") :: RemoteEvent

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FoodShopGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local openButton = Instance.new("TextButton")
	openButton.Name = "OpenFoodShopButton"
	openButton.Size = UDim2.fromOffset(120, 44)
	openButton.Position = UDim2.new(1, -140, 1, -168)
	openButton.Text = "Food Shop"
	openButton.Font = Enum.Font.SourceSansBold
	openButton.TextSize = 18
	openButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	openButton.TextColor3 = Color3.new(1, 1, 1)
	openButton.Parent = screenGui

	local shopFrame = Instance.new("Frame")
	shopFrame.Name = "FoodShopFrame"
	shopFrame.Size = UDim2.fromOffset(420, 520)
	shopFrame.Position = UDim2.new(0.5, -210, 0.5, -260)
	shopFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	shopFrame.Visible = false
	shopFrame.Parent = screenGui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -44, 0, 40)
	titleLabel.Position = UDim2.fromOffset(12, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Food Shop"
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.TextSize = 26
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = shopFrame

	local goldLabel = Instance.new("TextLabel")
	goldLabel.Name = "GoldLabel"
	goldLabel.Size = UDim2.new(1, -24, 0, 24)
	goldLabel.Position = UDim2.fromOffset(12, 44)
	goldLabel.BackgroundTransparency = 1
	goldLabel.Text = "Gold: 0"
	goldLabel.Font = Enum.Font.SourceSans
	goldLabel.TextSize = 18
	goldLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	goldLabel.TextXAlignment = Enum.TextXAlignment.Left
	goldLabel.Parent = shopFrame

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.fromOffset(32, 32)
	closeButton.Position = UDim2.new(1, -40, 0, 8)
	closeButton.Text = "X"
	closeButton.Font = Enum.Font.SourceSansBold
	closeButton.TextSize = 18
	closeButton.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Parent = shopFrame

	local rowsFrame = Instance.new("ScrollingFrame")
	rowsFrame.Name = "RowsFrame"
	rowsFrame.Size = UDim2.new(1, -24, 1, -140)
	rowsFrame.Position = UDim2.fromOffset(12, 76)
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.BorderSizePixel = 0
	rowsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	rowsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rowsFrame.ScrollBarThickness = 6
	rowsFrame.Parent = shopFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, ROW_SPACING)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = rowsFrame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -24, 0, 48)
	statusLabel.Position = UDim2.new(0, 12, 1, -56)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.Font = Enum.Font.SourceSans
	statusLabel.TextSize = 16
	statusLabel.TextWrapped = true
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = shopFrame

	local buyButtons: { [string]: TextButton } = {}
	local currentGold = 0

	local function refreshAffordability()
		for itemId, button in buyButtons do
			local price = FoodShopConfig[itemId]
			button.Text = if currentGold < price then "Not enough gold" else "Buy"
		end
	end

	local layoutOrder = 0
	for _, element in ELEMENT_ORDER do
		layoutOrder += 1

		local header = Instance.new("TextLabel")
		header.Name = element .. "Header"
		header.LayoutOrder = layoutOrder
		header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
		header.BackgroundTransparency = 1
		header.Text = element .. " Food"
		header.Font = Enum.Font.SourceSansBold
		header.TextSize = 18
		header.TextColor3 = ELEMENT_COLOR[element]
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Parent = rowsFrame

		for _, itemId in FoodConfig[element :: any] do
			layoutOrder += 1
			local price = FoodShopConfig[itemId]

			local row = Instance.new("Frame")
			row.Name = itemId .. "Row"
			row.LayoutOrder = layoutOrder
			row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
			row.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
			row.Parent = rowsFrame

			local accent = Instance.new("Frame")
			accent.Name = "Accent"
			accent.Size = UDim2.new(0, 6, 1, 0)
			accent.BorderSizePixel = 0
			accent.BackgroundColor3 = ELEMENT_COLOR[element]
			accent.Parent = row

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Name = "NameLabel"
			nameLabel.Size = UDim2.new(0, 160, 1, 0)
			nameLabel.Position = UDim2.fromOffset(14, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = itemId
			nameLabel.Font = Enum.Font.SourceSansBold
			nameLabel.TextSize = 16
			nameLabel.TextScaled = true
			nameLabel.TextWrapped = false
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = row

			local priceLabel = Instance.new("TextLabel")
			priceLabel.Name = "PriceLabel"
			priceLabel.Size = UDim2.fromScale(0.28, 1)
			priceLabel.Position = UDim2.fromScale(0.45, 0)
			priceLabel.BackgroundTransparency = 1
			priceLabel.Text = formatGold(price) .. " gold"
			priceLabel.Font = Enum.Font.SourceSans
			priceLabel.TextSize = 15
			priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
			priceLabel.TextXAlignment = Enum.TextXAlignment.Left
			priceLabel.Parent = row

			local buyButton = Instance.new("TextButton")
			buyButton.Name = "BuyButton"
			buyButton.Size = UDim2.new(0.25, -16, 0.75, 0)
			buyButton.Position = UDim2.fromScale(0.75, 0.125)
			buyButton.Text = "Buy"
			buyButton.Font = Enum.Font.SourceSansBold
			buyButton.TextSize = 14
			buyButton.BackgroundColor3 = Color3.fromRGB(60, 130, 60)
			buyButton.TextColor3 = Color3.new(1, 1, 1)
			buyButton.Parent = row

			buyButton.Activated:Connect(function()
				local requestId = RequestIdGenerator.Next()
				local result =
					transactionRemote:InvokeServer(requestId, TransactionType.BuyFood, { ItemId = itemId, Amount = 1 })

				if result.Success then
					statusLabel.TextColor3 = Color3.fromRGB(120, 220, 120)
					statusLabel.Text = `Bought 1 {itemId} for {formatGold(result.Data.TotalPrice)} gold.`
				else
					statusLabel.TextColor3 = Color3.fromRGB(230, 100, 100)
					statusLabel.Text = CODE_MESSAGE[result.Code] or `Purchase failed (code {result.Code}).`
				end
			end)

			buyButtons[itemId] = buyButton
		end
	end

	openButton.Activated:Connect(function()
		shopFrame.Visible = not shopFrame.Visible
	end)

	closeButton.Activated:Connect(function()
		shopFrame.Visible = false
	end)

	profileUpdated.OnClientEvent:Connect(function(snapshot)
		currentGold = snapshot.gold
		goldLabel.Text = `Gold: {formatGold(currentGold)}`
		refreshAffordability()
	end)

	return screenGui
end

return FoodShopUI
