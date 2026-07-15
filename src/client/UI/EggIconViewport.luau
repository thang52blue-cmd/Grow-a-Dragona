-- Renders a static 3D preview of an egg model inside a ViewportFrame, for use as a
-- Shop/Inventory row icon. Source meshes live in ReplicatedStorage.EggModels, a
-- Studio-authored folder (not synced by Rojo, lives only in the place file -- see
-- adr/plan notes), so lookups tolerate the folder or a given rarity being absent
-- rather than yielding forever or erroring.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EGG_MODELS_FOLDER_NAME = "EggModels"
local WAIT_TIMEOUT_SECONDS = 3

local CAMERA_DISTANCE_MULTIPLIER = 1.6
local CAMERA_PITCH_DEGREES = 20

local EggIconViewport = {}

local function findEggModel(rarity: string): MeshPart?
	local eggModels = ReplicatedStorage:FindFirstChild(EGG_MODELS_FOLDER_NAME)
		or ReplicatedStorage:WaitForChild(EGG_MODELS_FOLDER_NAME, WAIT_TIMEOUT_SECONDS)
	if not eggModels then
		return nil
	end
	return eggModels:FindFirstChild(rarity) :: MeshPart?
end

local function frameCamera(viewportFrame: ViewportFrame, eggClone: MeshPart)
	local camera = Instance.new("Camera")
	local distance = eggClone.Size.Magnitude * CAMERA_DISTANCE_MULTIPLIER
	local pitch = math.rad(CAMERA_PITCH_DEGREES)
	local offset = Vector3.new(0, math.sin(pitch) * distance, math.cos(pitch) * distance)
	camera.CFrame = CFrame.lookAt(offset, Vector3.zero)
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera
end

-- Returns a ready-to-parent ViewportFrame showing the given rarity's egg. Falls back to
-- an empty transparent frame if the source mesh isn't present in the current place.
function EggIconViewport.Create(rarity: string): ViewportFrame
	local viewportFrame = Instance.new("ViewportFrame")
	viewportFrame.Name = "EggIcon"
	viewportFrame.BackgroundTransparency = 1
	viewportFrame.Ambient = Color3.fromRGB(150, 150, 150)
	viewportFrame.LightColor = Color3.fromRGB(255, 255, 255)
	viewportFrame.LightDirection = Vector3.new(-0.5, -1, -0.3)

	local eggModel = findEggModel(rarity)
	if not eggModel then
		return viewportFrame
	end

	local clone = eggModel:Clone()
	clone.Anchored = true
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.Parent = viewportFrame

	frameCamera(viewportFrame, clone)

	return viewportFrame
end

return EggIconViewport
