-- Engine-glue for owned-dragon world presence in the shared "Nursery" area (Phase B, docs/prd/
-- core-game-loop.md, extended 2026-07-17 per direct user request to also show the Adult model in
-- place after transformation, instead of despawning). Spawns a clone of
-- ReplicatedStorage.DragonModels.Baby or .Adult (picked from dragon.GrowthStage) for every owned
-- dragon not yet assigned to a Farm Slot; a Baby gets a Feed ProximityPrompt whose Triggered
-- handler is wired client-side (src/client/Dragon/FeedPromptController.luau) to call
-- FeedDragonTransaction with only the DragonUID (AGENTS.md: clients request actions, server owns
-- state); an Adult gets no prompt yet (Farm Slot assignment's own world-presence pass, backlog
-- item 6, isn't built). This is Runtime-only decoration -- the persistent GrowthStage/FeedCount
-- lives on the profile; nothing here is saved, same pattern as HatchSpawner.luau for hatching eggs.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage:WaitForChild("Shared").Types.Types)

local DRAGON_MODELS_FOLDER_NAME = "DragonModels"
local NURSERY_FOLDER_NAME = "Nursery"
local BABY_DRAGON_TAG = "BabyDragon"
local ADULT_DRAGON_TAG = "AdultDragon"

-- Placeholder MVP location, chosen clear of Workspace.SpawnLocation (0, 0.5, -79) and within
-- Workspace.Baseplate's bounds (2048x16x2048 centered at origin, top surface at Y=0).
local NURSERY_ORIGIN = Vector3.new(60, 3, -40)
local LANE_SPACING = Vector3.new(25, 0, 0)
local SLOT_SPACING = Vector3.new(6, 0, 0)
local ROW_SPACING = Vector3.new(0, 0, 6)
local SLOTS_PER_ROW = 5

local DragonSpawner = {}

local playerLane: { [Player]: number } = {}
local nextLane = 0

local function laneOrigin(player: Player): Vector3
	local lane = playerLane[player]
	if not lane then
		lane = nextLane
		nextLane += 1
		playerLane[player] = lane
	end
	return NURSERY_ORIGIN + LANE_SPACING * lane
end

local function playerFolder(player: Player): Folder
	local root = Workspace:FindFirstChild(NURSERY_FOLDER_NAME)
	if not root then
		root = Instance.new("Folder")
		root.Name = NURSERY_FOLDER_NAME
		root.Parent = Workspace
	end

	local userId = tostring(player.UserId)
	local folder = root:FindFirstChild(userId)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = userId
		folder.Parent = root
	end
	return folder :: Folder
end

local function findPlayerFolder(player: Player): Folder?
	local root = Workspace:FindFirstChild(NURSERY_FOLDER_NAME)
	return root and (root:FindFirstChild(tostring(player.UserId)) :: Folder?)
end

local function slotPosition(player: Player, slotIndex: number): Vector3
	local row = math.floor(slotIndex / SLOTS_PER_ROW)
	local col = slotIndex % SLOTS_PER_ROW
	return laneOrigin(player) + SLOT_SPACING * col + ROW_SPACING * row
end

-- Full debug-friendly status text -- Rarity + Element + exact GrowthStage (not just a Baby/Adult
-- bucket) + Feed progress, per direct user request for complete on-model dragon info.
local function statusLabelText(dragon: Types.DragonRecord): string
	if dragon.GrowthStage == "Adult" then
		return `{dragon.Rarity} {dragon.Element} - Adult`
	end
	return `{dragon.Rarity} {dragon.Element} - {dragon.GrowthStage} (Fed {dragon.FeedCount}/4)`
end

local function addStatusBillboard(clone: Model, text: string): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "FeedStatus"
	billboard.Size = UDim2.fromOffset(140, 36)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = clone

	local label = Instance.new("TextLabel")
	label.Name = "FeedLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.Text = text
	label.Parent = billboard

	return label
end

-- Spawns one Dragon model (Baby or Adult variant, picked from dragon.GrowthStage) for an
-- already-known dragon record. No-op if a model for this DragonUID already exists (rejoin-safe,
-- mirrors HatchSpawner.Spawn's tolerance of a missing source model). A Baby gets a Feed
-- ProximityPrompt; an Adult does not (nothing to feed) -- see FeedPromptController, which only
-- attaches to the BABY_DRAGON_TAG.
function DragonSpawner.Spawn(player: Player, dragonUID: string, dragon: Types.DragonRecord)
	local folder = playerFolder(player)
	if folder:FindFirstChild(dragonUID) then
		return
	end

	local isAdult = dragon.GrowthStage == "Adult"

	local dragonModels = ReplicatedStorage:FindFirstChild(DRAGON_MODELS_FOLDER_NAME)
	local source = dragonModels and dragonModels:FindFirstChild(if isAdult then "Adult" else "Baby")
	if not source then
		return
	end

	local clone = (source :: Instance):Clone() :: Model
	clone.Name = dragonUID

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		end
	end

	local slotIndex = #folder:GetChildren()
	clone:PivotTo(CFrame.new(slotPosition(player, slotIndex)))

	clone:SetAttribute("DragonUID", dragonUID)
	clone:SetAttribute("Rarity", dragon.Rarity)
	clone:SetAttribute("Element", dragon.Element)
	clone:SetAttribute("GrowthStage", dragon.GrowthStage)

	if isAdult then
		addStatusBillboard(clone, statusLabelText(dragon))
		clone.Parent = folder
		CollectionService:AddTag(clone, ADULT_DRAGON_TAG)
		return
	end

	clone:SetAttribute("FeedCount", dragon.FeedCount)

	local anchorPart = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
	if anchorPart then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "FeedPrompt"
		prompt.ActionText = "Feed"
		prompt.ObjectText = `{dragon.Rarity} {dragon.Element} Dragon`
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchorPart
	end

	addStatusBillboard(clone, statusLabelText(dragon))

	clone.Parent = folder
	CollectionService:AddTag(clone, BABY_DRAGON_TAG)
end

-- Updates the FeedCount attribute/label after a successful Feed that didn't transform the
-- dragon to Adult (BecameAdult=true despawns and re-Spawns the Adult model instead -- see
-- init.server.luau).
function DragonSpawner.UpdateFeedCount(player: Player, dragonUID: string, feedCount: number)
	local folder = findPlayerFolder(player)
	local model = folder and (folder:FindFirstChild(dragonUID) :: Model?)
	if not model then
		return
	end

	local growthStage = "Baby_" .. feedCount
	model:SetAttribute("FeedCount", feedCount)
	model:SetAttribute("GrowthStage", growthStage)

	local billboard = model:FindFirstChild("FeedStatus")
	local label = billboard and (billboard:FindFirstChild("FeedLabel") :: TextLabel?)
	if label then
		local rarity = model:GetAttribute("Rarity")
		local element = model:GetAttribute("Element")
		label.Text = `{rarity} {element} - {growthStage} (Fed {feedCount}/4)`
	end
end

function DragonSpawner.Despawn(player: Player, dragonUID: string)
	local folder = findPlayerFolder(player)
	local model = folder and folder:FindFirstChild(dragonUID)
	if model then
		model:Destroy()
	end
end

-- Recreates a Dragon model for every owned dragon not yet assigned to a Farm Slot (Baby or Adult
-- alike) -- called once the player's character has loaded, so dragons fed/grown in a previous
-- session reappear in the Nursery. A dragon with AssignedSlotId set gets no Nursery model -- its
-- world presence belongs at its Farm Slot, a still-unbuilt follow-up (see
-- adr/ADR-004-farm-slot-and-nest-schema.md's Consequences).
function DragonSpawner.RespawnAll(player: Player, profile: Types.Profile)
	for dragonUID, dragon in profile.dragons do
		if dragon.AssignedSlotId == nil then
			DragonSpawner.Spawn(player, dragonUID, dragon)
		end
	end
end

function DragonSpawner.DespawnAll(player: Player)
	local folder = findPlayerFolder(player)
	if folder then
		folder:Destroy()
	end
	playerLane[player] = nil
end

return DragonSpawner
