-- The small "Manage Dragon" popup (docs/prd/storage-and-farm-slot-management.md): shown when a
-- player triggers an already-occupied Farm Slot's prompt. Two choices only -- Send to Storage,
-- or Swap Dragon (which hands off to the Storage Picker) -- never blocks, closes itself on
-- either choice or Cancel.
local ManageDragonMenu = {}

export type MenuHandle = {
	Open: (onSendToStorage: () -> (), onSwap: () -> ()) -> (),
	Close: () -> (),
}

function ManageDragonMenu.Init(player: Player): MenuHandle
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ManageDragonMenuGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 6
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "ManageMenuFrame"
	frame.Size = UDim2.fromOffset(260, 168)
	frame.Position = UDim2.new(0.5, -130, 0.5, -84)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	frame.Visible = false
	frame.Parent = screenGui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -24, 0, 32)
	titleLabel.Position = UDim2.fromOffset(12, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Manage Dragon"
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.TextSize = 20
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	local function makeButton(text: string, order: number, backgroundColor: Color3): TextButton
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -24, 0, 36)
		button.Position = UDim2.fromOffset(12, 44 + order * 44)
		button.Text = text
		button.Font = Enum.Font.SourceSansBold
		button.TextSize = 16
		button.BackgroundColor3 = backgroundColor
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Parent = frame
		return button
	end

	local sendButton = makeButton("Send to Storage", 0, Color3.fromRGB(60, 60, 60))
	local swapButton = makeButton("Swap Dragon", 1, Color3.fromRGB(60, 60, 60))
	local cancelButton = makeButton("Cancel", 2, Color3.fromRGB(80, 30, 30))

	local function close()
		frame.Visible = false
	end

	cancelButton.Activated:Connect(close)

	-- One persistent connection per button, calling through a reassignable upvalue -- Open()
	-- swaps which callback is live rather than adding a new Activated connection every time it's
	-- called (which would leak a connection per open and eventually fire every past slot's
	-- callback at once).
	local currentOnSendToStorage: (() -> ())? = nil
	local currentOnSwap: (() -> ())? = nil

	sendButton.Activated:Connect(function()
		local callback = currentOnSendToStorage
		close()
		if callback then
			callback()
		end
	end)
	swapButton.Activated:Connect(function()
		local callback = currentOnSwap
		close()
		if callback then
			callback()
		end
	end)

	local function open(onSendToStorage: () -> (), onSwap: () -> ())
		currentOnSendToStorage = onSendToStorage
		currentOnSwap = onSwap
		frame.Visible = true
	end

	return { Open = open, Close = close }
end

return ManageDragonMenu
