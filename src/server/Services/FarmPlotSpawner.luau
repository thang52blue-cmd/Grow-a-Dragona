-- Engine-glue for the physical per-player Farm Plot: a fenced ground area with one walkable
-- slot tile per Profile.farmSlots entry. Placeholder MVP art (AGENTS.md MVP scope) -- built
-- from primitive Parts, since unlike DragonModels/EggModels (hand-staged in Studio before
-- this pass) no Toolbox/Studio-authored fence or tile assets exist yet. See
-- adr/ADR-005-farm-plot-and-starter-hatch.md.
--
-- Runtime-only geometry, same pattern as DragonSpawner/HatchSpawner's Nursery/HatchingEggs
-- folders -- nothing here is saved; it's rebuilt from the persisted farmSlots data whenever
-- a player's plot is (re)ensured.
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local FarmPlotSpawner = {}

local FARM_PLOTS_FOLDER_NAME = "FarmPlots"
local FARM_SLOT_TAG = "FarmSlot"
-- Clear of Workspace.SpawnLocation (0, 0.5, -79), Workspace.Baseplate (2048x16x2048 centered
-- at the origin), and DragonSpawner's Nursery placeholder (60, 3, -40) -- see that module's
-- own placement comment.
local PLOT_ORIGIN = Vector3.new(-60, 0, -40)
local PLOT_SPACING = Vector3.new(50, 0, 0) -- distance between each player's own plot
local TILE_SIZE = Vector3.new(6, 1, 6)
local TILE_GAP = 9 -- distance between tile centers
local TILES_PER_ROW = 4
local FENCE_MARGIN = 7 -- clearance from the outermost tile's edge to the fence
local FENCE_HEIGHT = 6
local FENCE_THICKNESS = 1
local ENTRANCE_WIDTH = 8 -- walkable gap left in the near beam, wide enough for a player to pass

local playerPlotIndex: { [Player]: number } = {}
local nextPlotIndex = 0

local function plotOrigin(player: Player): Vector3
	local index = playerPlotIndex[player]
	if not index then
		index = nextPlotIndex
		nextPlotIndex += 1
		playerPlotIndex[player] = index
	end
	return PLOT_ORIGIN + PLOT_SPACING * index
end

-- World position of the tile for a given (1-based) SlotId -- slot IDs are always a dense
-- 1..N sequence in today's schema (ProfileSchema.defaultFarmSlots), so SlotId - 1 is a
-- stable, deterministic grid index.
local function tileWorldPosition(player: Player, slotId: number): Vector3
	local slotIndex = slotId - 1
	local row = math.floor(slotIndex / TILES_PER_ROW)
	local col = slotIndex % TILES_PER_ROW
	return plotOrigin(player) + Vector3.new(col * TILE_GAP, 0, row * TILE_GAP)
end

local function plotFolder(player: Player): Folder
	local root = Workspace:FindFirstChild(FARM_PLOTS_FOLDER_NAME)
	if not root then
		root = Instance.new("Folder")
		root.Name = FARM_PLOTS_FOLDER_NAME
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

-- Smallest axis-aligned rectangle (center, width, depth) covering every given tile position
-- plus FENCE_MARGIN of padding on every side.
local function computeBounds(tilePositions: { Vector3 }): (Vector3, number, number)
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, pos in tilePositions do
		minX = math.min(minX, pos.X)
		maxX = math.max(maxX, pos.X)
		minZ = math.min(minZ, pos.Z)
		maxZ = math.max(maxZ, pos.Z)
	end
	local width = (maxX - minX) + TILE_SIZE.X + FENCE_MARGIN * 2
	local depth = (maxZ - minZ) + TILE_SIZE.Z + FENCE_MARGIN * 2
	local center = Vector3.new((minX + maxX) / 2, 0, (minZ + maxZ) / 2)
	return center, width, depth
end

local function buildFenceBeam(parent: Instance, position: Vector3, size: Vector3)
	local part = Instance.new("Part")
	part.Name = "FenceBeam"
	part.Anchored = true
	part.CanCollide = true
	part.Material = Enum.Material.WoodPlanks
	part.Color = Color3.fromRGB(120, 82, 45)
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Parent = parent
end

-- 4 beams around the rectangle (not a solid wall) so the boundary reads clearly without
-- blocking the view into the plot -- matches the GDD's "vùng bao phủ bên ngoài dạng hàng
-- rào" (an outer fence-like boundary), not a solid keep wall. The near (-Z) beam, facing
-- Workspace.SpawnLocation (0, 0.5, -79), is split around a centered ENTRANCE_WIDTH gap --
-- otherwise all 4 beams fully seal the rectangle and a player has no way to walk in.
local function buildFence(parent: Instance, center: Vector3, width: number, depth: number)
	local halfWidth, halfDepth = width / 2, depth / 2
	local y = FENCE_HEIGHT / 2
	buildFenceBeam(parent, center + Vector3.new(0, y, halfDepth), Vector3.new(width, FENCE_HEIGHT, FENCE_THICKNESS))
	buildFenceBeam(parent, center + Vector3.new(-halfWidth, y, 0), Vector3.new(FENCE_THICKNESS, FENCE_HEIGHT, depth))
	buildFenceBeam(parent, center + Vector3.new(halfWidth, y, 0), Vector3.new(FENCE_THICKNESS, FENCE_HEIGHT, depth))

	local entranceHalf = ENTRANCE_WIDTH / 2
	local sideBeamWidth = math.max(halfWidth - entranceHalf, 0)
	if sideBeamWidth > 0 then
		local sideBeamSize = Vector3.new(sideBeamWidth, FENCE_HEIGHT, FENCE_THICKNESS)
		local offsetX = entranceHalf + sideBeamWidth / 2
		buildFenceBeam(parent, center + Vector3.new(-offsetX, y, -halfDepth), sideBeamSize)
		buildFenceBeam(parent, center + Vector3.new(offsetX, y, -halfDepth), sideBeamSize)
	end
end

-- No dedicated ground Part -- Workspace.Baseplate's own top surface (Y=0, see PLOT_ORIGIN
-- comment) already sits exactly under the plot, and an extra coplanar grass-colored Part
-- there just z-fights with it (visible as a flickering green floor). The fence + tiles are
-- enough to mark the plot's boundary; the Baseplate is the walkable floor inside it.
local function buildFenceForPlot(folder: Folder, player: Player, slotIds: { number })
	local tilePositions = {}
	for _, slotId in slotIds do
		table.insert(tilePositions, tileWorldPosition(player, slotId))
	end
	local center, width, depth = computeBounds(tilePositions)
	buildFence(folder, center, width, depth)
end

local function ensureTile(folder: Folder, player: Player, slotId: number)
	local name = "Slot" .. slotId
	if folder:FindFirstChild(name) then
		return
	end

	local tile = Instance.new("Part")
	tile.Name = name
	tile.Anchored = true
	tile.CanCollide = true
	tile.Material = Enum.Material.WoodPlanks
	tile.Color = Color3.fromRGB(160, 130, 90)
	tile.Size = TILE_SIZE
	tile.CFrame = CFrame.new(tileWorldPosition(player, slotId))
	tile:SetAttribute("SlotId", slotId)
	tile.Parent = folder

	-- Storage feature (docs/prd/storage-and-farm-slot-management.md): every tile is a walk-up
	-- interaction point for placing/managing a dragon. ActionText starts "Place Dragon" (every
	-- freshly-built tile starts empty); FarmPlotSpawner.UpdateSlotPrompt flips it to "Manage
	-- Dragon" once/if the slot gets occupied, same "refresh on every call" split as
	-- NestSpawner.UpdatePileCount (this constructor only ever runs once per tile; occupancy
	-- changes far more often than that).
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FarmSlotPrompt"
	prompt.ActionText = "Place Dragon"
	prompt.ObjectText = "Farm Slot"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = tile

	CollectionService:AddTag(tile, FARM_SLOT_TAG)
end

local function findTile(player: Player, slotId: number): BasePart?
	local root = Workspace:FindFirstChild(FARM_PLOTS_FOLDER_NAME)
	local folder = root and root:FindFirstChild(tostring(player.UserId))
	return folder and (folder:FindFirstChild("Slot" .. slotId) :: BasePart?)
end

-- Builds the player's Farm Plot on first call (ground + fence, sized to fit exactly the
-- given slot IDs), then makes sure every one of those slot IDs has a tile -- safe to call
-- repeatedly (e.g. once per PlayerAdded) and, later, safe to call again with a longer
-- slotIds list once Plot Expansion (backlog item 13) exists, though the fence/ground won't
-- resize to match until that item rebuilds them.
function FarmPlotSpawner.EnsurePlot(player: Player, slotIds: { number })
	local folder = plotFolder(player)
	if not folder:FindFirstChild("FenceBeam") then
		buildFenceForPlot(folder, player, slotIds)
	end
	for _, slotId in slotIds do
		ensureTile(folder, player, slotId)
	end
end

-- Flips a tile's ProximityPrompt between "Place Dragon" (slot empty) and "Manage Dragon" (slot
-- occupied) -- safe to call any time a slot's occupancy might have changed (PlaceDragon,
-- SendToStorage, SwapDragon, and hatch-time auto-placement all call this) as well as once per
-- slot on PlayerAdded, so a rejoining player's tiles reflect the profile's real current state
-- rather than whatever a freshly-built tile defaults to.
function FarmPlotSpawner.UpdateSlotPrompt(player: Player, slotId: number, isOccupied: boolean)
	local tile = findTile(player, slotId)
	local prompt = tile and (tile:FindFirstChildWhichIsA("ProximityPrompt") :: ProximityPrompt?)
	if not prompt then
		return
	end
	prompt.ActionText = if isOccupied then "Manage Dragon" else "Place Dragon"
end

-- World position of the walkable top surface of a given Farm Slot's tile -- callers that
-- place a model here (DragonSpawner) are expected to measure their own model's bounding box
-- and rest its bottom exactly on this Y, rather than assuming a fixed model height.
function FarmPlotSpawner.SlotPosition(player: Player, slotId: number): Vector3
	return tileWorldPosition(player, slotId) + Vector3.new(0, TILE_SIZE.Y / 2, 0)
end

-- Where the free first-join Hatching Egg sits (GDD Section 1: "already sitting on the
-- plot") -- Slot 1 always exists (every profile starts with at least
-- ProductionConfig.startingFarmSlots slots), so this is safe to call any time after
-- EnsurePlot.
function FarmPlotSpawner.StarterEggPosition(player: Player): Vector3
	return FarmPlotSpawner.SlotPosition(player, 1)
end

-- Placeholder ground spot for the Sell market stall (GDD §8: "a small market stall sits at a
-- fixed spot on the player's own plot"), clear of the current 2-3 starting slots' fence/tiles --
-- an engineering placeholder like PLOT_ORIGIN/NURSERY_ORIGIN, not GDD-sourced, since the GDD
-- never specifies exact placement. Plot Expansion (backlog item 13, up to 12 slots) can grow the
-- fence wider than this fixed offset clears; revisit alongside that item.
function FarmPlotSpawner.StallPosition(player: Player): Vector3
	return plotOrigin(player) + Vector3.new(30, 0, 12)
end

function FarmPlotSpawner.Despawn(player: Player)
	local root = Workspace:FindFirstChild(FARM_PLOTS_FOLDER_NAME)
	local folder = root and root:FindFirstChild(tostring(player.UserId))
	if folder then
		folder:Destroy()
	end
	playerPlotIndex[player] = nil
end

return FarmPlotSpawner
