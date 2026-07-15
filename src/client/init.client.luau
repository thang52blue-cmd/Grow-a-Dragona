local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TransactionType = require(Shared.Domain.TransactionType)
local TransactionCode = require(Shared.Domain.TransactionCode)

local transactionRemote = remotesFolder:WaitForChild("Transaction") :: RemoteFunction

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TestHarness"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.fromOffset(420, 160)
statusLabel.Position = UDim2.fromOffset(20, 20)
statusLabel.BackgroundColor3 = Color3.new(0, 0, 0)
statusLabel.BackgroundTransparency = 0.4
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Font = Enum.Font.Code
statusLabel.TextSize = 18
statusLabel.Text = "Loading..."
statusLabel.Parent = screenGui

local transactionLabel = Instance.new("TextLabel")
transactionLabel.Name = "TransactionLabel"
transactionLabel.Size = UDim2.fromOffset(420, 100)
transactionLabel.Position = UDim2.fromOffset(20, 560)
transactionLabel.BackgroundColor3 = Color3.new(0, 0, 0)
transactionLabel.BackgroundTransparency = 0.4
transactionLabel.TextColor3 = Color3.new(1, 1, 1)
transactionLabel.TextXAlignment = Enum.TextXAlignment.Left
transactionLabel.TextYAlignment = Enum.TextYAlignment.Top
transactionLabel.Font = Enum.Font.Code
transactionLabel.TextSize = 16
transactionLabel.Text = "No transaction yet."
transactionLabel.Parent = screenGui

local function makeButton(name: string, text: string, order: number, remoteName: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(180, 40)
	button.Position = UDim2.fromOffset(20, 200 + (order * 50))
	button.Text = text
	button.Font = Enum.Font.SourceSansBold
	button.TextSize = 18
	button.Parent = screenGui

	button.Activated:Connect(function()
		(remotesFolder:WaitForChild(remoteName) :: RemoteEvent):FireServer()
	end)

	return button
end

makeButton("AddGoldButton", "+10 Gold", 0, "AddTestGold")
makeButton("SpendGoldButton", "-10 Gold", 1, "SpendTestGold")
makeButton("AddFoodButton", "+1 Fish", 2, "AddTestFood")
makeButton("RemoveFoodButton", "-1 Fish", 3, "RemoveTestFood")

local function codeName(code: number): string
	for name, value in TransactionCode :: { [string]: number } do
		if value == code then
			return name
		end
	end
	return tostring(code)
end

local nextRequestId = 1
local lastRequestId: number? = nil
local lastTypeId: number? = nil
local lastPayload: { [string]: any }? = nil

local function renderTransactionResult(requestId: number, result: any)
	local lines = { `Request #{requestId}`, `Success: {tostring(result.Success)}`, `Code: {codeName(result.Code)}` }

	if result.Success and result.Data then
		for key, value in result.Data do
			table.insert(lines, `  {key}: {tostring(value)}`)
		end
	end

	transactionLabel.Text = table.concat(lines, "\n")
end

local function submitTransaction(typeId: number, payload: { [string]: any }, requestId: number?)
	local id = requestId
	if not id then
		id = nextRequestId
		nextRequestId += 1
	end

	lastRequestId = id
	lastTypeId = typeId
	lastPayload = payload

	local result = transactionRemote:InvokeServer(id, typeId, payload)
	renderTransactionResult(id :: number, result)
end

local function makeTransactionButton(
	name: string,
	text: string,
	order: number,
	typeId: number,
	payload: { [string]: any }
): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(180, 40)
	button.Position = UDim2.fromOffset(220, 200 + (order * 50))
	button.Text = text
	button.Font = Enum.Font.SourceSansBold
	button.TextSize = 18
	button.Parent = screenGui

	button.Activated:Connect(function()
		submitTransaction(typeId, payload)
	end)

	return button
end

makeTransactionButton(
	"BuyCommonEggButton",
	"Buy 1 Common Egg",
	0,
	TransactionType.BuyEgg,
	{ Rarity = "Common", Amount = 1 }
)
makeTransactionButton("BuyRareEggButton", "Buy 1 Rare Egg", 1, TransactionType.BuyEgg, { Rarity = "Rare", Amount = 1 })

local retryButton = Instance.new("TextButton")
retryButton.Name = "RetryLastRequestButton"
retryButton.Size = UDim2.fromOffset(180, 40)
retryButton.Position = UDim2.fromOffset(220, 300)
retryButton.Text = "Retry Last Request"
retryButton.Font = Enum.Font.SourceSansBold
retryButton.TextSize = 18
retryButton.Parent = screenGui

retryButton.Activated:Connect(function()
	-- Resends the exact same RequestId/TypeId/Payload -- lets you manually verify the server
	-- returns the cached result instead of double-charging (AGENTS.md §3.7).
	if lastRequestId and lastTypeId and lastPayload then
		submitTransaction(lastTypeId, lastPayload, lastRequestId)
	end
end)

type ProfileSnapshot = {
	gold: number,
	inventory: { [string]: number },
	lastError: string?,
}

local function render(snapshot: ProfileSnapshot)
	local lines = { `Gold: {snapshot.gold}`, "Inventory:" }

	local hasItems = false
	for itemId, quantity in snapshot.inventory do
		hasItems = true
		table.insert(lines, `  {itemId}: {quantity}`)
	end
	if not hasItems then
		table.insert(lines, "  (empty)")
	end

	if snapshot.lastError then
		table.insert(lines, `Last error: {snapshot.lastError}`)
	end

	statusLabel.Text = table.concat(lines, "\n")
end

(remotesFolder:WaitForChild("ProfileUpdated") :: RemoteEvent).OnClientEvent:Connect(render)
