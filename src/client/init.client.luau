local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

local EggShopUI = require(script.Shop.EggShopUI)
local EggInventoryUI = require(script.Inventory.EggInventoryUI)
local RequestIdGenerator = require(script.RequestIdGenerator)
local HatchCountdownController = require(script.Hatch.HatchCountdownController)
local AutoClaimController = require(script.Hatch.AutoClaimController)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TestHarness"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.fromOffset(420, 70)
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
makeButton("AddGold10000Button", "+10000 Gold", 2, "AddTestGold10000")

type PendingHatch = {
	Id: string,
	Rarity: string,
	StartedAt: number,
	FinishAt: number,
}

type ProfileSnapshot = {
	gold: number,
	inventory: { [string]: number },
	pendingHatches: { [string]: PendingHatch },
	dragons: { [string]: any },
	lastError: string?,
}

local latestPendingHatches: { [string]: PendingHatch } = {}

local function render(snapshot: ProfileSnapshot)
	local lines = { `Gold: {snapshot.gold}` }

	if snapshot.lastError then
		table.insert(lines, `Last error: {snapshot.lastError}`)
	end

	statusLabel.Text = table.concat(lines, "\n")
	latestPendingHatches = snapshot.pendingHatches
end

(remotesFolder:WaitForChild("ProfileUpdated") :: RemoteEvent).OnClientEvent:Connect(render)

EggShopUI.Init(player, remotesFolder)
EggInventoryUI.Init(player, remotesFolder)
HatchCountdownController.Init()
AutoClaimController.Init(remotesFolder, RequestIdGenerator, function()
	return latestPendingHatches
end)
