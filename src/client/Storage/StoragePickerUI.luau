-- The Storage Picker modal (docs/prd/storage-and-farm-slot-management.md): a grid/list of every
-- dragon currently in Storage (AssignedSlotId == nil). Used for both "Place Dragon" (an empty
-- slot) and "Swap Dragon" (an occupied slot's Manage menu) -- the caller supplies which dragons
-- to list and what happens when one is picked; this module only owns the modal chrome
-- (title/sort/close) and delegates card rendering to StorageCardList.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types.Types)

local RarityDisplay = require(script.Parent.Parent.UI.RarityDisplay)
local StorageCardList = require(script.Parent.StorageCardList)

local StoragePickerUI = {}

export type PickerHandle = {
	Open: (dragons: { [string]: Types.DragonRecord }, onPick: (dragonUID: string) -> ()) -> (),
	Close: () -> (),
}

local function dragonLabel(dragon: Types.DragonRecord): (string, string)
	local title = `{dragon.Rarity} {dragon.Element} Dragon`
	local subtitle = if dragon.GrowthStage == "Adult"
		then "Adult"
		else `{dragon.GrowthStage} (Fed {dragon.FeedCount}/4)`
	return title, subtitle
end

local function rarityRank(rarity: string): number
	for index, candidate in RarityDisplay.Order do
		if candidate == rarity then
			return index
		end
	end
	return #RarityDisplay.Order + 1
end

function StoragePickerUI.Init(player: Player): PickerHandle
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StoragePickerGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 5
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "PickerFrame"
	frame.Size = UDim2.fromOffset(420, 480)
	frame.Position = UDim2.new(0.5, -210, 0.5, -240)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	frame.Visible = false
	frame.Parent = screenGui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -140, 0, 36)
	titleLabel.Position = UDim2.fromOffset(12, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Choose a Dragon"
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.TextSize = 22
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	local sortButton = Instance.new("TextButton")
	sortButton.Name = "SortButton"
	sortButton.Size = UDim2.fromOffset(96, 28)
	sortButton.Position = UDim2.new(1, -136, 0, 12)
	sortButton.Font = Enum.Font.SourceSans
	sortButton.TextSize = 14
	sortButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	sortButton.TextColor3 = Color3.new(1, 1, 1)
	sortButton.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.fromOffset(32, 32)
	closeButton.Position = UDim2.new(1, -40, 0, 8)
	closeButton.Text = "X"
	closeButton.Font = Enum.Font.SourceSansBold
	closeButton.TextSize = 18
	closeButton.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Parent = frame

	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.Name = "EmptyLabel"
	emptyLabel.Size = UDim2.new(1, -24, 0, 30)
	emptyLabel.Position = UDim2.fromOffset(12, 52)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Text = "Storage is empty."
	emptyLabel.Font = Enum.Font.SourceSans
	emptyLabel.TextSize = 15
	emptyLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	emptyLabel.TextXAlignment = Enum.TextXAlignment.Left
	emptyLabel.Visible = false
	emptyLabel.Parent = frame

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "CardScroll"
	scrollFrame.Size = UDim2.new(1, -24, 1, -60)
	scrollFrame.Position = UDim2.fromOffset(12, 52)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.Parent = frame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = scrollFrame

	local sortByNewest = false
	local currentDragons: { [string]: Types.DragonRecord } = {}
	local currentOnPick: ((string) -> ())? = nil

	local function close()
		frame.Visible = false
	end

	local function render()
		local uids = {}
		for uid in currentDragons do
			table.insert(uids, uid)
		end

		if sortByNewest then
			table.sort(uids, function(a, b)
				return currentDragons[a].HatchedAt > currentDragons[b].HatchedAt
			end)
		else
			table.sort(uids, function(a, b)
				local dragonA, dragonB = currentDragons[a], currentDragons[b]
				local rankA, rankB = rarityRank(dragonA.Rarity), rarityRank(dragonB.Rarity)
				if rankA ~= rankB then
					return rankA > rankB -- rarest first
				end
				return dragonA.HatchedAt > dragonB.HatchedAt
			end)
		end

		local entries = {}
		for _, uid in uids do
			local dragon = currentDragons[uid]
			local title, subtitle = dragonLabel(dragon)
			table.insert(entries, {
				Key = uid,
				Title = title,
				Subtitle = subtitle,
				AccentColor = RarityDisplay.Color[dragon.Rarity :: any],
				OnSelect = function()
					local onPick = currentOnPick
					close()
					if onPick then
						onPick(uid)
					end
				end,
			})
		end

		StorageCardList.Rebuild(scrollFrame, entries)
		emptyLabel.Visible = #entries == 0
		scrollFrame.Visible = #entries > 0
	end

	sortButton.Activated:Connect(function()
		sortByNewest = not sortByNewest
		sortButton.Text = if sortByNewest then "Sort: Newest" else "Sort: Rarity"
		render()
	end)
	sortButton.Text = "Sort: Rarity"

	closeButton.Activated:Connect(close)

	local function open(dragons: { [string]: Types.DragonRecord }, onPick: (string) -> ())
		currentDragons = dragons
		currentOnPick = onPick
		render()
		frame.Visible = true
	end

	return { Open = open, Close = close }
end

return StoragePickerUI
