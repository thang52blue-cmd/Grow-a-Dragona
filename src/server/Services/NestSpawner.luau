-- Engine-glue for the world-visible Nest that appears once an Adult dragon's production has
-- started on a Farm Slot (GDD §5: "The nest only exists once a dragon is Adult"). Clones
-- ReplicatedStorage.NestModels.Default (a Studio-staged Creator Store asset, see
-- memory-bank/systemPatterns.md) and shows a small pile of placeholder egg Parts (up to 5, per
-- GDD §5) plus a counter badge beyond that. Runtime-only decoration, same pattern as
-- HatchSpawner/DragonSpawner/FarmPlotSpawner -- nothing here is saved; it's rebuilt from the
-- persisted FarmSlot.UncollectedEggCount whenever a slot is (re)ensured. See
-- adr/ADR-006-production-egg-rarity-inventory.md.
--
-- Important simplification: which *variant* each uncollected egg will become is only rolled at
-- Collect time (CollectNestRules.Stage), not before -- there is no per-egg variant stored on the
-- profile while it's still sitting uncollected in the Nest. So unlike the GDD's description of a
-- Golden egg already glowing in the pile pre-collection, this pass's pile eggs are all the same
-- plain placeholder model regardless of what they'll roll into -- a known, flagged gap, not a
-- bug (would need its own schema change -- a list of pending per-egg variants -- to fix).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NEST_MODELS_FOLDER_NAME = "NestModels"
local NESTS_FOLDER_NAME = "Nests"
local NEST_TAG = "Nest"
local PILE_MAX_VISIBLE = 5
local EGG_DIAMETER = 1.1
local PILE_RADIUS = 1.4

local NestSpawner = {}

local function playerFolder(player: Player): Folder
	local root = Workspace:FindFirstChild(NESTS_FOLDER_NAME)
	if not root then
		root = Instance.new("Folder")
		root.Name = NESTS_FOLDER_NAME
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
	local root = Workspace:FindFirstChild(NESTS_FOLDER_NAME)
	return root and (root:FindFirstChild(tostring(player.UserId)) :: Folder?)
end

-- Rests a cloned Model's true bounding-box bottom exactly on `groundPosition`.Y, same technique
-- as DragonSpawner.placeModelOnGround -- works regardless of the Nest asset's own pivot/scale.
local function placeModelOnGround(model: Model, groundPosition: Vector3)
	model:PivotTo(CFrame.new(groundPosition))
	local boundingCFrame, size = model:GetBoundingBox()
	local bottomY = boundingCFrame.Position.Y - size.Y / 2
	local pivot = model:GetPivot()
	model:PivotTo(pivot + Vector3.new(0, groundPosition.Y - bottomY, 0))
end

-- Evenly-spaced points on a small ring around the Nest's center, so up to 5 egg Parts read as a
-- loose pile rather than a single stack (GDD §5: "arranged in a loose stack").
local function pileEggOffset(index: number): Vector3
	local angle = (index - 1) * (2 * math.pi / PILE_MAX_VISIBLE)
	return Vector3.new(math.cos(angle), 0, math.sin(angle)) * PILE_RADIUS
end

local function buildEggPart(parent: Instance, groundPosition: Vector3, index: number): Part
	local part = Instance.new("Part")
	part.Name = "Egg" .. index
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.fromRGB(245, 238, 220)
	part.Size = Vector3.new(EGG_DIAMETER, EGG_DIAMETER, EGG_DIAMETER)
	local eggPosition = groundPosition + pileEggOffset(index)
	part.CFrame = CFrame.new(eggPosition + Vector3.new(0, part.Size.Y / 2, 0))
	part.Parent = parent
	return part
end

local function ensureCounterBadge(anchor: BasePart): TextLabel
	local existing = anchor:FindFirstChild("EggCountBadge") :: BillboardGui?
	if existing then
		return existing:FindFirstChild("CountLabel") :: TextLabel
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EggCountBadge"
	billboard.Size = UDim2.fromOffset(70, 30)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = false
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Name = "CountLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.Parent = billboard

	return label
end

-- Rebuilds the egg-pile Parts and counter badge for an already-built Nest to match
-- `uncollectedEggCount` -- safe to call every time the count changes (Collect, or the periodic
-- production-refresh in init.server.luau).
function NestSpawner.UpdatePileCount(player: Player, slotId: number, uncollectedEggCount: number)
	local folder = findPlayerFolder(player)
	local slotFolder = folder and (folder:FindFirstChild(tostring(slotId)) :: Folder?)
	if not slotFolder then
		return
	end

	local anchor = slotFolder:FindFirstChild("PileAnchor") :: BasePart?
	if not anchor then
		return
	end

	local visibleCount = math.min(uncollectedEggCount, PILE_MAX_VISIBLE)
	for i = 1, PILE_MAX_VISIBLE do
		local existing = slotFolder:FindFirstChild("Egg" .. i)
		if i <= visibleCount then
			if not existing then
				buildEggPart(slotFolder, anchor.Position, i)
			end
		elseif existing then
			existing:Destroy()
		end
	end

	local label = ensureCounterBadge(anchor)
	local badge = anchor:FindFirstChild("EggCountBadge") :: BillboardGui
	badge.Enabled = uncollectedEggCount > PILE_MAX_VISIBLE
	label.Text = "x" .. uncollectedEggCount

	local prompt = anchor:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Enabled = uncollectedEggCount > 0
		(prompt :: ProximityPrompt).ActionText = if uncollectedEggCount >= 2 then "Collect All" else "Collect"
	end
end

-- Builds the Nest for a Farm Slot on first call (clone of NestModels.Default + a PileAnchor part
-- holding the Collect ProximityPrompt/counter badge), then syncs the egg pile to
-- `uncollectedEggCount` -- safe to call repeatedly, same pattern as FarmPlotSpawner.EnsurePlot.
function NestSpawner.EnsureNest(player: Player, slotId: number, groundPosition: Vector3, uncollectedEggCount: number)
	local folder = playerFolder(player)
	local slotKey = tostring(slotId)
	local slotFolder = folder:FindFirstChild(slotKey) :: Folder?

	if not slotFolder then
		local newSlotFolder = Instance.new("Folder")
		newSlotFolder.Name = slotKey
		newSlotFolder.Parent = folder
		slotFolder = newSlotFolder

		local nestModelsRoot = ReplicatedStorage:FindFirstChild(NEST_MODELS_FOLDER_NAME)
		local source = nestModelsRoot and nestModelsRoot:FindFirstChild("Default")
		if source then
			local clone = (source :: Instance):Clone() :: Model
			clone.Name = "NestModel"
			for _, descendant in clone:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Anchored = true
					descendant.CanCollide = false
				end
			end
			placeModelOnGround(clone, groundPosition)
			clone.Parent = newSlotFolder
		end

		local anchor = Instance.new("Part")
		anchor.Name = "PileAnchor"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.CFrame = CFrame.new(groundPosition + Vector3.new(0, 1, 0))
		anchor:SetAttribute("SlotId", slotId)
		anchor.Parent = newSlotFolder

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "CollectPrompt"
		prompt.ActionText = "Collect"
		prompt.ObjectText = "Nest"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor

		CollectionService:AddTag(anchor, NEST_TAG)
	end

	NestSpawner.UpdatePileCount(player, slotId, uncollectedEggCount)
end

function NestSpawner.Despawn(player: Player, slotId: number)
	local folder = findPlayerFolder(player)
	local slotFolder = folder and folder:FindFirstChild(tostring(slotId))
	if slotFolder then
		slotFolder:Destroy()
	end
end

function NestSpawner.DespawnAll(player: Player)
	local folder = findPlayerFolder(player)
	if folder then
		folder:Destroy()
	end
end

return NestSpawner
