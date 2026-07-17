-- Engine-glue for the world-visible Sell market stall (GDD §8: "a small market stall sits at a
-- fixed spot on the player's own plot... a Sell action converts everything at once"). One stall
-- per player, built from primitive Parts (no Toolbox/Studio-authored stall asset exists yet --
-- same placeholder-art rationale as FarmPlotSpawner's fence). Runtime-only, rebuilt on
-- (re)join -- nothing here is saved. See adr/ADR-006-production-egg-rarity-inventory.md.
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local FarmPlotSpawner = require(script.Parent.FarmPlotSpawner)

local STALLS_FOLDER_NAME = "MarketStalls"
local STALL_TAG = "MarketStall"
local TABLE_SIZE = Vector3.new(4, 3, 2)
local AWNING_SIZE = Vector3.new(5, 0.3, 3)

local MarketStallSpawner = {}

local function findPlayerFolder(player: Player): Folder?
	local root = Workspace:FindFirstChild(STALLS_FOLDER_NAME)
	return root and (root:FindFirstChild(tostring(player.UserId)) :: Folder?)
end

-- Builds the player's Sell stall on first call -- a wooden table (the interaction point) under a
-- red awning, matching the "cute, colorful farm aesthetic" the GDD asks for at placeholder-art
-- fidelity. Safe to call repeatedly (e.g. once per PlayerAdded).
function MarketStallSpawner.EnsureStall(player: Player)
	local root = Workspace:FindFirstChild(STALLS_FOLDER_NAME)
	if not root then
		root = Instance.new("Folder")
		root.Name = STALLS_FOLDER_NAME
		root.Parent = Workspace
	end

	local userId = tostring(player.UserId)
	if (root :: Folder):FindFirstChild(userId) then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = userId
	folder.Parent = root

	local stallOrigin = FarmPlotSpawner.StallPosition(player)

	local tablePart = Instance.new("Part")
	tablePart.Name = "Table"
	tablePart.Anchored = true
	tablePart.CanCollide = true
	tablePart.Material = Enum.Material.WoodPlanks
	tablePart.Color = Color3.fromRGB(150, 110, 70)
	tablePart.Size = TABLE_SIZE
	tablePart.CFrame = CFrame.new(stallOrigin + Vector3.new(0, TABLE_SIZE.Y / 2, 0))
	tablePart.Parent = folder

	local awning = Instance.new("Part")
	awning.Name = "Awning"
	awning.Anchored = true
	awning.CanCollide = false
	awning.Material = Enum.Material.Fabric
	awning.Color = Color3.fromRGB(200, 60, 60)
	awning.Size = AWNING_SIZE
	awning.CFrame = CFrame.new(stallOrigin + Vector3.new(0, TABLE_SIZE.Y + 1.5, 0))
	awning.Parent = folder

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SellPrompt"
	prompt.ActionText = "Sell"
	prompt.ObjectText = "Market Stall"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = tablePart

	CollectionService:AddTag(tablePart, STALL_TAG)
end

function MarketStallSpawner.Despawn(player: Player)
	local folder = findPlayerFolder(player)
	if folder then
		folder:Destroy()
	end
end

return MarketStallSpawner
