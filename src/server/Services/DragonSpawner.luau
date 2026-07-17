-- Engine-glue for owned-dragon world presence. Spawns a clone of ReplicatedStorage.DragonModels
-- .Baby or .Adult (picked from dragon.GrowthStage) for a dragon assigned to a Farm Slot, standing
-- on its FarmPlotSpawner tile. A dragon in Storage (AssignedSlotId == nil) gets NO world model at
-- all -- per docs/GROW_A_DRAGONA_IMPLEMENTATION_GDD.md Section 12: "Storage isn't a physical
-- building on the plot... there's nothing to walk up to." It's browsed only through the Storage
-- Picker / HUD Collection button (src/client/Storage/), never a physical location. This
-- supersedes an earlier pass's "Nursery holding area" fallback for unassigned dragons -- the
-- container folder is still named "Nursery" (kept as-is; other modules like
-- HatchRevealController hardcode that path) but it now only ever holds Farm-Slot-positioned
-- models. A Baby gets a Feed ProximityPrompt whose Triggered handler is wired client-side
-- (src/client/Dragon/FeedPromptController.luau) to call FeedDragonTransaction with only the
-- DragonUID (AGENTS.md: clients request actions, server owns state); an Adult gets no prompt
-- (nothing to feed). This is Runtime-only decoration -- the persistent GrowthStage/FeedCount/
-- AssignedSlotId lives on the profile; nothing here is saved, same pattern as HatchSpawner.luau
-- for hatching eggs. See adr/ADR-005-farm-plot-and-starter-hatch.md.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage:WaitForChild("Shared").Types.Types)
local FarmPlotSpawner = require(script.Parent.FarmPlotSpawner)

local DRAGON_MODELS_FOLDER_NAME = "DragonModels"
local NURSERY_FOLDER_NAME = "Nursery"
local BABY_DRAGON_TAG = "BabyDragon"
local ADULT_DRAGON_TAG = "AdultDragon"

local DragonSpawner = {}

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

-- Full debug-friendly status text -- Rarity + Element + exact GrowthStage (not just a Baby/Adult
-- bucket) + Feed progress, per direct user request for complete on-model dragon info.
local function statusLabelText(dragon: Types.DragonRecord): string
	if dragon.GrowthStage == "Adult" then
		return `{dragon.Rarity} {dragon.Element} - Adult`
	end
	return `{dragon.Rarity} {dragon.Element} - {dragon.GrowthStage} (Fed {dragon.FeedCount}/4)`
end

-- Rests `model`'s true bounding-box bottom exactly on `groundPosition`.Y (its X/Z), instead
-- of assuming a fixed model height/pivot offset -- works regardless of where each model's
-- own pivot sits relative to its geometry, so Baby and Adult models (different sizes/rigs)
-- both land on the ground rather than floating or sinking in.
local function placeModelOnGround(model: Model, groundPosition: Vector3)
	model:PivotTo(CFrame.new(groundPosition))
	local boundingCFrame, size = model:GetBoundingBox()
	local bottomY = boundingCFrame.Position.Y - size.Y / 2
	local pivot = model:GetPivot()
	model:PivotTo(pivot + Vector3.new(0, groundPosition.Y - bottomY, 0))
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
-- already-known dragon record. No-op if the dragon is in Storage (AssignedSlotId == nil --
-- Storage has no physical presence, see this module's header) or if a model for this DragonUID
-- already exists (rejoin-safe, mirrors HatchSpawner.Spawn's tolerance of a missing source
-- model). A Baby gets a Feed ProximityPrompt; an Adult does not (nothing to feed) -- see
-- FeedPromptController, which only attaches to the BABY_DRAGON_TAG.
function DragonSpawner.Spawn(player: Player, dragonUID: string, dragon: Types.DragonRecord)
	if dragon.AssignedSlotId == nil then
		return
	end

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

	local position = FarmPlotSpawner.SlotPosition(player, dragon.AssignedSlotId)
	placeModelOnGround(clone, position)

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

-- Recreates a Dragon model for every owned dragon that's actually assigned to a Farm Slot
-- (Spawn itself no-ops for a Storage dragon) -- called once the player's character has loaded,
-- so dragons fed/grown/placed in a previous session reappear exactly where they were.
function DragonSpawner.RespawnAll(player: Player, profile: Types.Profile)
	for dragonUID, dragon in profile.dragons do
		DragonSpawner.Spawn(player, dragonUID, dragon)
	end
end

function DragonSpawner.DespawnAll(player: Player)
	local folder = findPlayerFolder(player)
	if folder then
		folder:Destroy()
	end
end

return DragonSpawner
