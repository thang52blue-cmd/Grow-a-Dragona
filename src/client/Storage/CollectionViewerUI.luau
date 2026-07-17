-- The HUD "Collection" button (docs/prd/storage-and-farm-slot-management.md): view-only
-- browsing of every owned dragon (both on the farm and in Storage), grouped with a duplicate
-- count and sortable by Rarity or newest. This never places a dragon -- per the spec's own
-- closing line, actually placing one still requires walking to a physical Farm Slot and using
-- its prompt (see FarmSlotPromptController); this button only opens the read-only viewer.
local RarityDisplay = require(script.Parent.Parent.UI.RarityDisplay)
local StorageCardList = require(script.Parent.StorageCardList)

local CollectionViewerUI = {}

type GroupEntry = {
	Rarity: string,
	Element: string,
	GrowthStage: string,
	Count: number,
	OnFarmCount: number,
	NewestHatchedAt: number,
}

local function rarityRank(rarity: string): number
	for index, candidate in RarityDisplay.Order do
		if candidate == rarity then
			return index
		end
	end
	return #RarityDisplay.Order + 1
end

function CollectionViewerUI.Init(player: Player, remotesFolder: Folder): ScreenGui
	local profileUpdated = remotesFolder:WaitForChild("ProfileUpdated") :: RemoteEvent

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CollectionViewerGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local openButton = Instance.new("TextButton")
	openButton.Name = "OpenCollectionButton"
	openButton.Size = UDim2.fromOffset(120, 44)
	openButton.Position = UDim2.new(1, -140, 1, -220)
	openButton.Text = "Collection"
	openButton.Font = Enum.Font.SourceSansBold
	openButton.TextSize = 20
	openButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	openButton.TextColor3 = Color3.new(1, 1, 1)
	openButton.Parent = screenGui

	local frame = Instance.new("Frame")
	frame.Name = "CollectionFrame"
	frame.Size = UDim2.fromOffset(420, 480)
	frame.Position = UDim2.new(0.5, -210, 0.5, -240)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	frame.Visible = false
	frame.Parent = screenGui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -140, 0, 36)
	titleLabel.Position = UDim2.fromOffset(12, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Collection"
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.TextSize = 22
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	local sortButton = Instance.new("TextButton")
	sortButton.Size = UDim2.fromOffset(96, 28)
	sortButton.Position = UDim2.new(1, -136, 0, 12)
	sortButton.Font = Enum.Font.SourceSans
	sortButton.TextSize = 14
	sortButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	sortButton.TextColor3 = Color3.new(1, 1, 1)
	sortButton.Text = "Sort: Rarity"
	sortButton.Parent = frame

	local closeButton = Instance.new("TextButton")
	closeButton.Size = UDim2.fromOffset(32, 32)
	closeButton.Position = UDim2.new(1, -40, 0, 8)
	closeButton.Text = "X"
	closeButton.Font = Enum.Font.SourceSansBold
	closeButton.TextSize = 18
	closeButton.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Parent = frame

	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.Size = UDim2.new(1, -24, 0, 30)
	emptyLabel.Position = UDim2.fromOffset(12, 52)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Text = "You don't own any dragons yet."
	emptyLabel.Font = Enum.Font.SourceSans
	emptyLabel.TextSize = 15
	emptyLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
	emptyLabel.TextXAlignment = Enum.TextXAlignment.Left
	emptyLabel.Visible = false
	emptyLabel.Parent = frame

	local scrollFrame = Instance.new("ScrollingFrame")
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
	local latestGroups: { [string]: GroupEntry } = {}

	local function render()
		local keys = {}
		for key in latestGroups do
			table.insert(keys, key)
		end

		if sortByNewest then
			table.sort(keys, function(a, b)
				return latestGroups[a].NewestHatchedAt > latestGroups[b].NewestHatchedAt
			end)
		else
			table.sort(keys, function(a, b)
				local groupA, groupB = latestGroups[a], latestGroups[b]
				local rankA, rankB = rarityRank(groupA.Rarity), rarityRank(groupB.Rarity)
				if rankA ~= rankB then
					return rankA > rankB
				end
				return groupA.NewestHatchedAt > groupB.NewestHatchedAt
			end)
		end

		local entries = {}
		for _, key in keys do
			local group = latestGroups[key]
			local placementNote = if group.OnFarmCount == 0
				then "All in Storage"
				elseif group.OnFarmCount == group.Count then "All on farm"
				else `{group.OnFarmCount} on farm, {group.Count - group.OnFarmCount} in Storage`
			local subtitle = if group.GrowthStage == "Adult"
				then `Adult - {placementNote}`
				else `{group.GrowthStage} - {placementNote}`
			table.insert(entries, {
				Key = key,
				Title = `{group.Rarity} {group.Element} Dragon`,
				Subtitle = subtitle,
				AccentColor = RarityDisplay.Color[group.Rarity :: any],
				CountSuffix = `x{group.Count}`,
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

	openButton.Activated:Connect(function()
		frame.Visible = not frame.Visible
		if frame.Visible then
			render()
		end
	end)
	closeButton.Activated:Connect(function()
		frame.Visible = false
	end)

	profileUpdated.OnClientEvent:Connect(function(snapshot)
		local groups: { [string]: GroupEntry } = {}
		for _, dragon in snapshot.dragons do
			local key = `{dragon.Rarity} {dragon.Element} {dragon.GrowthStage}`
			local group = groups[key]
			if not group then
				group = {
					Rarity = dragon.Rarity,
					Element = dragon.Element,
					GrowthStage = dragon.GrowthStage,
					Count = 0,
					OnFarmCount = 0,
					NewestHatchedAt = 0,
				}
				groups[key] = group
			end
			group.Count += 1
			if dragon.AssignedSlotId ~= nil then
				group.OnFarmCount += 1
			end
			group.NewestHatchedAt = math.max(group.NewestHatchedAt, dragon.HatchedAt)
		end
		latestGroups = groups
		if frame.Visible then
			render()
		end
	end)

	return screenGui
end

return CollectionViewerUI
