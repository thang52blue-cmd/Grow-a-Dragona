local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes")

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
