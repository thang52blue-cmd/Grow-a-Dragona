-- Wires the ProximityPrompt on every world-visible Farm Slot tile (tagged "FarmSlot" by
-- src/server/Services/FarmPlotSpawner.luau) to the Storage feature's three transactions. See
-- docs/prd/storage-and-farm-slot-management.md.
--
-- Which flow to open is read directly off the prompt's own ActionText ("Place Dragon" vs
-- "Manage Dragon") rather than a second attribute -- the server already keeps that text in sync
-- with the slot's real occupancy (FarmPlotSpawner.UpdateSlotPrompt), so this is one source of
-- truth, not two that could drift.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types.Types)
local TransactionType = require(Shared.Domain.TransactionType)
local TransactionCode = require(Shared.Domain.TransactionCode)

local StoragePickerUI = require(script.Parent.StoragePickerUI)
local ManageDragonMenu = require(script.Parent.ManageDragonMenu)

local FARM_SLOT_TAG = "FarmSlot"

local CODE_MESSAGE: { [number]: string } = {
	[TransactionCode.SlotOccupied] = "That slot is already occupied.",
	[TransactionCode.SlotNotFound] = "Unknown slot.",
	[TransactionCode.DragonAlreadyAssigned] = "That dragon is already placed elsewhere.",
	[TransactionCode.DragonNotFound] = "Unknown dragon.",
	[TransactionCode.NoDragonInSlot] = "That slot is already empty.",
	[TransactionCode.NestNotEmpty] = "Collect this Nest's eggs first.",
	[TransactionCode.RateLimited] = "Too many requests, slow down.",
}

local FarmSlotPromptController = {}

local function showFeedback(anchor: BasePart, text: string, color: Color3)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(180, 40)
	billboard.StudsOffset = Vector3.new(0, 5, 0)
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

function FarmSlotPromptController.Init(
	player: Player,
	remotesFolder: Folder,
	requestIdGenerator: { Next: () -> number }
)
	local profileUpdated = remotesFolder:WaitForChild("ProfileUpdated") :: RemoteEvent
	local transactionRemote = remotesFolder:WaitForChild("Transaction") :: RemoteFunction

	local picker = StoragePickerUI.Init(player)
	local manageMenu = ManageDragonMenu.Init(player)

	local latestDragons: { [string]: Types.DragonRecord } = {}
	profileUpdated.OnClientEvent:Connect(function(snapshot)
		latestDragons = snapshot.dragons or {}
	end)

	local function storageDragons(): { [string]: Types.DragonRecord }
		local result = {}
		for uid, dragon in latestDragons do
			if dragon.AssignedSlotId == nil then
				result[uid] = dragon
			end
		end
		return result
	end

	local function invoke(typeId: number, payload: { [string]: any }, anchor: BasePart)
		local requestId = requestIdGenerator.Next()
		local result = transactionRemote:InvokeServer(requestId, typeId, payload)
		if not result.Success then
			showFeedback(
				anchor,
				CODE_MESSAGE[result.Code] or `Failed (code {result.Code}).`,
				Color3.fromRGB(230, 100, 100)
			)
		end
		return result
	end

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
			local basePartAnchor = anchor :: BasePart

			if prompt.ActionText == "Place Dragon" then
				picker.Open(storageDragons(), function(dragonUID: string)
					invoke(TransactionType.PlaceDragon, { DragonUID = dragonUID, SlotId = slotId }, basePartAnchor)
				end)
			else
				manageMenu.Open(function()
					invoke(TransactionType.SendToStorage, { SlotId = slotId }, basePartAnchor)
				end, function()
					picker.Open(storageDragons(), function(newDragonUID: string)
						invoke(
							TransactionType.SwapDragon,
							{ SlotId = slotId, NewDragonUID = newDragonUID },
							basePartAnchor
						)
					end)
				end)
			end
		end)
	end

	for _, anchor in CollectionService:GetTagged(FARM_SLOT_TAG) do
		attach(anchor)
	end
	CollectionService:GetInstanceAddedSignal(FARM_SLOT_TAG):Connect(attach)
end

return FarmSlotPromptController
