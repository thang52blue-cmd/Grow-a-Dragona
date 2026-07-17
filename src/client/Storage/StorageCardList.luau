-- Reusable card-list renderer shared by the Storage Picker (selectable) and the Collection
-- viewer (read-only) -- both are "a grid/list of dragon cards", differing only in whether a
-- card responds to a click and whether entries are individual dragons or grouped duplicates.
-- See docs/prd/storage-and-farm-slot-management.md.
local StorageCardList = {}

export type CardEntry = {
	Key: string,
	Title: string,
	Subtitle: string,
	AccentColor: Color3,
	CountSuffix: string?,
	OnSelect: (() -> ())?,
}

local CARD_HEIGHT = 56

-- Rebuilds `container`'s cards from scratch to match `entries`, in order. Only destroys
-- previously-built cards (tagged by Name == "Card") so a persistent UIListLayout sibling isn't
-- clobbered on every refresh.
function StorageCardList.Rebuild(container: Instance, entries: { CardEntry })
	for _, child in container:GetChildren() do
		if child.Name == "Card" then
			child:Destroy()
		end
	end

	for order, entry in entries do
		-- Always a plain Frame (not a TextButton) so selectable/non-selectable cards share one
		-- code path -- a selectable card gets a full-size transparent TextButton overlaid on
		-- top to catch the click instead, a common Roblox pattern that sidesteps needing a
		-- Frame|TextButton union type for every property assignment below.
		local card = Instance.new("Frame")
		card.Name = "Card"
		card.LayoutOrder = order
		card.Size = UDim2.new(1, 0, 0, CARD_HEIGHT)
		card.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		card.Parent = container

		local accent = Instance.new("Frame")
		accent.Name = "Accent"
		accent.Size = UDim2.new(0, 6, 1, 0)
		accent.BorderSizePixel = 0
		accent.BackgroundColor3 = entry.AccentColor
		accent.Parent = card

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "Title"
		titleLabel.Size = UDim2.new(1, -80, 0, 30)
		titleLabel.Position = UDim2.fromOffset(16, 4)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Font = Enum.Font.SourceSansBold
		titleLabel.TextSize = 16
		titleLabel.TextColor3 = Color3.new(1, 1, 1)
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.Text = entry.Title
		titleLabel.Parent = card

		local subtitleLabel = Instance.new("TextLabel")
		subtitleLabel.Name = "Subtitle"
		subtitleLabel.Size = UDim2.new(1, -80, 0, 20)
		subtitleLabel.Position = UDim2.fromOffset(16, 32)
		subtitleLabel.BackgroundTransparency = 1
		subtitleLabel.Font = Enum.Font.SourceSans
		subtitleLabel.TextSize = 14
		subtitleLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
		subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
		subtitleLabel.Text = entry.Subtitle
		subtitleLabel.Parent = card

		if entry.CountSuffix then
			local countLabel = Instance.new("TextLabel")
			countLabel.Name = "Count"
			countLabel.Size = UDim2.fromOffset(60, CARD_HEIGHT)
			countLabel.Position = UDim2.new(1, -70, 0, 0)
			countLabel.BackgroundTransparency = 1
			countLabel.Font = Enum.Font.SourceSansBold
			countLabel.TextSize = 18
			countLabel.TextColor3 = Color3.new(1, 1, 1)
			countLabel.TextXAlignment = Enum.TextXAlignment.Right
			countLabel.Text = entry.CountSuffix
			countLabel.Parent = card
		end

		if entry.OnSelect then
			local clickCatcher = Instance.new("TextButton")
			clickCatcher.Name = "ClickCatcher"
			clickCatcher.Size = UDim2.fromScale(1, 1)
			clickCatcher.BackgroundTransparency = 1
			clickCatcher.Text = ""
			clickCatcher.ZIndex = 2
			clickCatcher.Parent = card
			clickCatcher.Activated:Connect(entry.OnSelect)
		end
	end
end

return StorageCardList
