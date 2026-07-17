-- Player-facing Sell screen (GDD §8): opened by walking up to the Market Stall, shows an
-- itemized breakdown of the player's entire Production Egg inventory (by Rarity + Variant) with
-- each line's unit/subtotal gold value and the grand total, and a single "Sell All" action -- no
-- selective/per-line selling, per the GDD's explicit design decision. Reuses
-- SellProductionEggRules.Stage (the same pure function SellProductionEggTransaction runs
-- server-side) to compute the preview, so the numbers shown here can never drift from what the
-- real Sell actually grants.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TransactionType = require(Shared.Domain.TransactionType)
local TransactionCode = require(Shared.Domain.TransactionCode)
local SellProductionEggRules = require(Shared.Domain.SellProductionEggRules)
local Rarities = require(Shared.Domain.Rarities)
local Variants = require(Shared.Domain.Variants)
local EggConfig = require(Shared.Data.EggConfig)
local DragonConfig = require(Shared.Data.DragonConfig)
local EconomyConfig = require(Shared.Data.EconomyConfig)

local RarityDisplay = require(script.Parent.Parent.UI.RarityDisplay)
local RequestIdGenerator = require(script.Parent.Parent.RequestIdGenerator)

local RARITY_ORDER = RarityDisplay.Order
local RARITY_COLOR = RarityDisplay.Color
local VARIANT_ORDER = Variants.List

local ROW_HEIGHT = 32
local ROW_SPACING = 4

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

local function emptyProductionEggInventory()
	local byRarity: { [string]: { [string]: number } } = {}
	for _, rarity in Rarities.List do
		local bucket = {}
		for _, variant in VARIANT_ORDER do
			bucket[variant] = 0
		end
		byRarity[rarity] = bucket
	end
	return byRarity
end

-- The snapshot may arrive as `{}` (profile not loaded yet) rather than a fully-shaped by-rarity
-- table, so every field is read defensively instead of trusted to exist.
local function normalizeProductionEggInventory(raw: unknown)
	local byRarity = emptyProductionEggInventory()
	if type(raw) == "table" then
		for _, rarity in Rarities.List do
			local bucket = (raw :: any)[rarity]
			if type(bucket) == "table" then
				for _, variant in VARIANT_ORDER do
					byRarity[rarity][variant] = bucket[variant] or 0
				end
			end
		end
	end
	return byRarity
end

local SellScreenUI = {}

function SellScreenUI.Init(player: Player, remotesFolder: Folder): { Open: () -> () }
	local profileUpdated = remotesFolder:WaitForChild("ProfileUpdated") :: RemoteEvent
	local transactionRemote = remotesFolder:WaitForChild("Transaction") :: RemoteFunction

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SellScreenGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local sellFrame = Instance.new("Frame")
	sellFrame.Name = "SellFrame"
	sellFrame.Size = UDim2.fromOffset(420, 480)
	sellFrame.Position = UDim2.new(0.5, -210, 0.5, -240)
	sellFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	sellFrame.Visible = false
	sellFrame.Parent = screenGui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -44, 0, 40)
	titleLabel.Position = UDim2.fromOffset(12, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Sell Eggs"
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.TextSize = 26
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = sellFrame

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.fromOffset(32, 32)
	closeButton.Position = UDim2.new(1, -40, 0, 8)
	closeButton.Text = "X"
	closeButton.Font = Enum.Font.SourceSansBold
	closeButton.TextSize = 18
	closeButton.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Parent = sellFrame

	local rowsFrame = Instance.new("ScrollingFrame")
	rowsFrame.Name = "RowsFrame"
	rowsFrame.Size = UDim2.new(1, -24, 1, -196)
	rowsFrame.Position = UDim2.fromOffset(12, 56)
	rowsFrame.BackgroundTransparency = 1
	rowsFrame.BorderSizePixel = 0
	rowsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	rowsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rowsFrame.ScrollBarThickness = 6
	rowsFrame.Parent = sellFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, ROW_SPACING)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = rowsFrame

	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.Name = "EmptyLabel"
	emptyLabel.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Text = "Nothing to sell yet."
	emptyLabel.Font = Enum.Font.SourceSans
	emptyLabel.TextSize = 16
	emptyLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
	emptyLabel.TextXAlignment = Enum.TextXAlignment.Left
	emptyLabel.Visible = false
	emptyLabel.Parent = rowsFrame

	local totalLabel = Instance.new("TextLabel")
	totalLabel.Name = "TotalLabel"
	totalLabel.Size = UDim2.new(1, -24, 0, 28)
	totalLabel.Position = UDim2.new(0, 12, 1, -128)
	totalLabel.BackgroundTransparency = 1
	totalLabel.Text = "Total: 0 gold"
	totalLabel.Font = Enum.Font.SourceSansBold
	totalLabel.TextSize = 20
	totalLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	totalLabel.TextXAlignment = Enum.TextXAlignment.Left
	totalLabel.Parent = sellFrame

	local sellAllButton = Instance.new("TextButton")
	sellAllButton.Name = "SellAllButton"
	sellAllButton.Size = UDim2.new(1, -24, 0, 44)
	sellAllButton.Position = UDim2.new(0, 12, 1, -92)
	sellAllButton.Text = "Sell All"
	sellAllButton.Font = Enum.Font.SourceSansBold
	sellAllButton.TextSize = 20
	sellAllButton.BackgroundColor3 = Color3.fromRGB(60, 130, 60)
	sellAllButton.TextColor3 = Color3.new(1, 1, 1)
	sellAllButton.Parent = sellFrame

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -24, 0, 40)
	statusLabel.Position = UDim2.new(0, 12, 1, -40)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.Font = Enum.Font.SourceSans
	statusLabel.TextSize = 15
	statusLabel.TextWrapped = true
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = sellFrame

	local rowInstances: { Frame } = {}
	local currentGold = 0
	local currentInventory = emptyProductionEggInventory()

	local function clearRows()
		for _, row in rowInstances do
			row:Destroy()
		end
		table.clear(rowInstances)
	end

	local function refresh()
		clearRows()

		local fakeProfile = { gold = currentGold, productionEggInventory = currentInventory }
		local ok, staged = SellProductionEggRules.Stage(EggConfig, DragonConfig, EconomyConfig, fakeProfile)

		if not ok or #staged.SoldLineItems == 0 then
			emptyLabel.Visible = true
			totalLabel.Text = "Total: 0 gold"
			sellAllButton.Visible = false
			return
		end

		emptyLabel.Visible = false
		sellAllButton.Visible = true

		local layoutOrder = 0
		for _, rarity in RARITY_ORDER do
			for _, item in staged.SoldLineItems do
				if item.Rarity ~= rarity then
					continue
				end
				layoutOrder += 1

				local row = Instance.new("Frame")
				row.Name = `{item.Rarity}{item.Variant}Row`
				row.LayoutOrder = layoutOrder
				row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
				row.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				row.Parent = rowsFrame

				local accent = Instance.new("Frame")
				accent.Name = "Accent"
				accent.Size = UDim2.new(0, 6, 1, 0)
				accent.BorderSizePixel = 0
				accent.BackgroundColor3 = RARITY_COLOR[item.Rarity]
				accent.Parent = row

				local nameLabel = Instance.new("TextLabel")
				nameLabel.Name = "NameLabel"
				nameLabel.Size = UDim2.fromOffset(200, ROW_HEIGHT)
				nameLabel.Position = UDim2.fromOffset(14, 0)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Text = `{item.Rarity} {item.Variant} x{item.Count}`
				nameLabel.Font = Enum.Font.SourceSansBold
				nameLabel.TextSize = 15
				nameLabel.TextColor3 = Color3.new(1, 1, 1)
				nameLabel.TextXAlignment = Enum.TextXAlignment.Left
				nameLabel.Parent = row

				local valueLabel = Instance.new("TextLabel")
				valueLabel.Name = "ValueLabel"
				valueLabel.Size = UDim2.new(1, -224, 1, 0)
				valueLabel.Position = UDim2.fromOffset(214, 0)
				valueLabel.BackgroundTransparency = 1
				valueLabel.Text = `{formatGold(item.UnitValue)} ea = {formatGold(item.Subtotal)}`
				valueLabel.Font = Enum.Font.SourceSans
				valueLabel.TextSize = 14
				valueLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
				valueLabel.TextXAlignment = Enum.TextXAlignment.Right
				valueLabel.Parent = row

				table.insert(rowInstances, row)
			end
		end

		totalLabel.Text = `Total: {formatGold(staged.TotalGold)} gold`
	end

	sellAllButton.Activated:Connect(function()
		local requestId = RequestIdGenerator.Next()
		local result = transactionRemote:InvokeServer(requestId, TransactionType.SellProductionEgg, {})

		if result.Success then
			statusLabel.TextColor3 = Color3.fromRGB(120, 220, 120)
			statusLabel.Text = `Sold everything for {formatGold(result.Data.TotalGold)} gold.`
		elseif result.Code == TransactionCode.NothingToSell then
			statusLabel.TextColor3 = Color3.fromRGB(230, 100, 100)
			statusLabel.Text = "Nothing to sell."
		else
			statusLabel.TextColor3 = Color3.fromRGB(230, 100, 100)
			statusLabel.Text = `Sell failed (code {result.Code}).`
		end
	end)

	closeButton.Activated:Connect(function()
		sellFrame.Visible = false
	end)

	profileUpdated.OnClientEvent:Connect(function(snapshot)
		currentGold = snapshot.gold
		currentInventory = normalizeProductionEggInventory(snapshot.productionEggInventory)
		refresh()
	end)

	local function open()
		statusLabel.Text = ""
		refresh()
		sellFrame.Visible = true
	end

	return { Open = open }
end

return SellScreenUI
