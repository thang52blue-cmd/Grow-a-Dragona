-- Beat 4 of the hatch reveal sequence (docs/prd/hatch-reveal-sequence.md): a small, non-blocking
-- summary card that never requires an action to proceed -- it fades on its own after ~2 seconds,
-- or dismisses immediately on a tap/click anywhere on screen.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CARD_LIFETIME_SECONDS = 2
local FADE_SECONDS = 0.35

local SummaryCardUI = {}

export type SummaryCardInfo = {
	Title: string,
	Subtitle: string,
	AccentColor: Color3,
}

-- Builds and immediately shows the card under the given ScreenGui. Fire-and-forget: cleans
-- itself up (fade + Destroy) whether it times out or gets dismissed early.
function SummaryCardUI.Show(screenGui: ScreenGui, info: SummaryCardInfo)
	local card = Instance.new("Frame")
	card.Name = "HatchSummaryCard"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, 60)
	card.Size = UDim2.fromOffset(320, 90)
	card.BackgroundColor3 = Color3.new(0, 0, 0)
	card.BackgroundTransparency = 0.25
	card.BorderSizePixel = 0
	card.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = info.AccentColor
	stroke.Thickness = 2
	stroke.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 44)
	title.Position = UDim2.fromOffset(10, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.SourceSansBold
	title.TextScaled = true
	title.TextColor3 = info.AccentColor
	title.Text = info.Title
	title.Parent = card

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, -20, 0, 28)
	subtitle.Position = UDim2.fromOffset(10, 52)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.SourceSans
	subtitle.TextScaled = true
	subtitle.TextColor3 = Color3.new(1, 1, 1)
	subtitle.Text = info.Subtitle
	subtitle.Parent = card

	local dismissed = false
	local function dismiss()
		if dismissed then
			return
		end
		dismissed = true

		local fadeOut = TweenService:Create(card, TweenInfo.new(FADE_SECONDS), { BackgroundTransparency = 1 })
		TweenService:Create(title, TweenInfo.new(FADE_SECONDS), { TextTransparency = 1 }):Play()
		TweenService:Create(subtitle, TweenInfo.new(FADE_SECONDS), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(FADE_SECONDS), { Transparency = 1 }):Play()
		fadeOut:Play()
		Debris:AddItem(card, FADE_SECONDS + 0.1)
	end

	local inputConnection: RBXScriptConnection
	inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dismiss()
			inputConnection:Disconnect()
		end
	end)

	task.delay(CARD_LIFETIME_SECONDS, function()
		dismiss()
		if inputConnection.Connected then
			inputConnection:Disconnect()
		end
	end)
end

return SummaryCardUI
