-- Wires the Sell ProximityPrompt on the world-visible Market Stall (tagged "MarketStall" by
-- src/server/Services/MarketStallSpawner.luau) to SellProductionEggTransaction. Per GDD §8,
-- selling is always "Sell all" -- the interaction sends an empty payload, and the entire
-- Production Egg inventory's value is computed and granted server-side.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TransactionType = require(Shared.Domain.TransactionType)
local TransactionCode = require(Shared.Domain.TransactionCode)

local STALL_TAG = "MarketStall"

local SellPromptController = {}

local function showFeedback(anchor: BasePart, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 36)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard

	Debris:AddItem(billboard, 2)
end

function SellPromptController.Init(remotesFolder: Folder, requestIdGenerator: { Next: () -> number })
	local transactionRemote = remotesFolder:WaitForChild("Transaction") :: RemoteFunction

	local function attach(anchor: Instance)
		local prompt = anchor:FindFirstChildWhichIsA("ProximityPrompt")
		if not prompt then
			return
		end
		prompt.Triggered:Connect(function()
			local requestId = requestIdGenerator.Next()
			local result = transactionRemote:InvokeServer(requestId, TransactionType.SellProductionEgg, {})
			if result.Success then
				showFeedback(anchor :: BasePart, `+{result.Data.TotalGold} gold`, Color3.fromRGB(255, 215, 90))
			elseif result.Code == TransactionCode.NothingToSell then
				showFeedback(anchor :: BasePart, "Nothing to sell", Color3.fromRGB(230, 100, 100))
			end
		end)
	end

	for _, anchor in CollectionService:GetTagged(STALL_TAG) do
		attach(anchor)
	end
	CollectionService:GetInstanceAddedSignal(STALL_TAG):Connect(attach)
end

return SellPromptController
