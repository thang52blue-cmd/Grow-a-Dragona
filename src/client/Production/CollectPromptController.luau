-- Wires the Collect ProximityPrompt on every world-visible Nest (tagged "Nest" by
-- src/server/Services/NestSpawner.luau) to CollectNestTransaction. Per
-- adr/ADR-006-production-egg-rarity-inventory.md, the interaction sends only SlotId -- how many
-- eggs, and which variants they become, are resolved entirely server-side.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TransactionType = require(Shared.Domain.TransactionType)

local NEST_TAG = "Nest"

local CollectPromptController = {}

local function showFeedback(anchor: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 36)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 215, 90)
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard

	Debris:AddItem(billboard, 2)
end

function CollectPromptController.Init(remotesFolder: Folder, requestIdGenerator: { Next: () -> number })
	local transactionRemote = remotesFolder:WaitForChild("Transaction") :: RemoteFunction

	local function attach(anchor: Instance)
		local prompt = anchor:FindFirstChildWhichIsA("ProximityPrompt")
		if not prompt then
			return
		end
		prompt.Triggered:Connect(function()
			local slotId = anchor:GetAttribute("SlotId")
			if type(slotId) ~= "number" then
				return
			end
			local requestId = requestIdGenerator.Next()
			local result = transactionRemote:InvokeServer(requestId, TransactionType.CollectNest, { SlotId = slotId })
			if result.Success then
				showFeedback(anchor :: BasePart, `+{result.Data.EggsCollected} eggs`)
			end
		end)
	end

	for _, anchor in CollectionService:GetTagged(NEST_TAG) do
		attach(anchor)
	end
	CollectionService:GetInstanceAddedSignal(NEST_TAG):Connect(attach)
end

return CollectPromptController
