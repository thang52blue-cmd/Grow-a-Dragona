-- Engine-glue for the world-visible hatching egg decoration -- the only module in this
-- feature that touches Workspace/CollectionService. Purely a Runtime-only visual effect
-- (AGENTS.md data classification): the *logical* pending-hatch timer lives on the profile
-- and is persisted, but this decoration is never saved and is expected to be recreated
-- fresh (RespawnAllPending) whenever the owning player's character loads.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage:WaitForChild("Shared").Types.Types)

local EGG_MODELS_FOLDER_NAME = "EggModels"
local HATCHING_EGGS_FOLDER_NAME = "HatchingEggs"
local HATCH_TAG = "HatchingEgg"
local SPAWN_OFFSET = Vector3.new(3, 2, 0)

local HatchSpawner = {}

local function playerFolder(player: Player): Folder
	local root = Workspace:FindFirstChild(HATCHING_EGGS_FOLDER_NAME)
	if not root then
		root = Instance.new("Folder")
		root.Name = HATCHING_EGGS_FOLDER_NAME
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
	local root = Workspace:FindFirstChild(HATCHING_EGGS_FOLDER_NAME)
	return root and (root:FindFirstChild(tostring(player.UserId)) :: Folder?)
end

-- Spawns the visible hatching-egg decoration at the given (already-decided) position --
-- the caller passes the position the profile actually recorded at StartHatch time
-- (Types.Position, plain X/Y/Z), not wherever the player happens to be standing right
-- now, so a respawn after rejoin lands in the same spot every time. Tolerates a missing
-- ReplicatedStorage.EggModels[rarity] the same way the client's EggIconViewport.luau
-- does -- it's a Studio-authored asset, not guaranteed to exist.
function HatchSpawner.Spawn(player: Player, hatchId: string, rarity: string, finishAt: number, position: Types.Position)
	local eggModels = ReplicatedStorage:FindFirstChild(EGG_MODELS_FOLDER_NAME)
	local source = eggModels and eggModels:FindFirstChild(rarity)
	if not source then
		return
	end

	local clone = (source :: Instance):Clone() :: BasePart
	clone.Name = hatchId
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone:PivotTo(CFrame.new(Vector3.new(position.X, position.Y, position.Z) + SPAWN_OFFSET))

	clone:SetAttribute("FinishAt", finishAt)
	clone:SetAttribute("Rarity", rarity)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HatchCountdown"
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = clone

	local label = Instance.new("TextLabel")
	label.Name = "CountdownLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.Text = "..."
	label.Parent = billboard

	clone.Parent = playerFolder(player)
	CollectionService:AddTag(clone, HATCH_TAG)
end

function HatchSpawner.Despawn(player: Player, hatchId: string)
	local folder = findPlayerFolder(player)
	local model = folder and folder:FindFirstChild(hatchId)
	if model then
		model:Destroy()
	end
end

-- Recreates a decoration for every still-pending hatch at its originally-recorded
-- position -- called once the player's character has loaded, so a hatch started in a
-- previous session reappears in the same spot after rejoin, not wherever the player
-- happens to spawn this time.
function HatchSpawner.RespawnAllPending(player: Player, profile: Types.Profile)
	for hatchId, pending in profile.pendingHatches do
		HatchSpawner.Spawn(player, hatchId, pending.Rarity, pending.FinishAt, pending.Position)
	end
end

function HatchSpawner.DespawnAll(player: Player)
	local folder = findPlayerFolder(player)
	if folder then
		folder:Destroy()
	end
end

return HatchSpawner
