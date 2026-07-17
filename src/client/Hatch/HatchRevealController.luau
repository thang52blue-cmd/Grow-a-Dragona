-- Orchestrates the full 4-beat hatch reveal cinematic (docs/prd/hatch-reveal-sequence.md):
-- shake -> crack & flash -> reveal -> non-blocking summary. Every rarity plays the same beats;
-- src/shared/Data/HatchVisualConfig.json controls how dressed-up each beat gets. This module
-- now owns the whole ClaimHatch round trip (previously AutoClaimController fired-and-forgot the
-- InvokeServer call) since the shake/crack beats have to play *before* the claim, and the
-- reveal/summary beats need the claim's result (DragonId/Rarity/AssignedSlotId).
--
-- Reveal animation is presentation only (docs/prd/core-game-loop.md) -- it never determines RNG
-- or player data; Rarity/Element are read back off the already-server-authoritative dragon
-- record (via the newly-replicated world model's attributes, set by DragonSpawner) after the
-- real ClaimHatch commit, not guessed client-side.
local Debris = game:GetService("Debris")
local HapticService = game:GetService("HapticService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types.Types)
local TransactionType = require(Shared.Domain.TransactionType)
local HatchVisualConfig = require(Shared.Data.HatchVisualConfig)
local SummaryCardUI = require(script.Parent.SummaryCardUI)

local HatchRevealController = {}

local HATCH_SOUNDS_FOLDER_NAME = "HatchSounds"
local HAPTIC_CANDIDATE_INPUT_TYPES = { Enum.UserInputType.Touch, Enum.UserInputType.Gamepad1 }
local HAPTIC_INTENSITY: { [string]: number } = { Light = 0.3, Medium = 0.6, Strong = 1.0 }
-- Matches this feature's own HatchVisualConfig.json: both hasRoar tiers (Legendary, Mythic) put
-- their DragonRoar reveal-sound cue at delaySeconds = 0.3 -- kept as a named constant here so the
-- "timed with the roar" haptic pulse stays in sync with that authored delay without the two
-- files needing a shared source of truth for one number.
local ROAR_HAPTIC_DELAY_SECONDS = 0.3

-- Only one directed camera shot can play at a time -- concurrent hatches (multiple pending
-- hatches finishing near-simultaneously is a supported case, see ClaimHatchRules) queue for the
-- single Workspace.CurrentCamera instead of fighting over it.
local cameraLocked = false
local function acquireCameraLock()
	while cameraLocked do
		task.wait(0.05)
	end
	cameraLocked = true
end
local function releaseCameraLock()
	cameraLocked = false
end

local cachedScreenGui: ScreenGui? = nil
local function getScreenGui(player: Player): ScreenGui
	if cachedScreenGui and cachedScreenGui.Parent then
		return cachedScreenGui
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "HatchRevealGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")
	cachedScreenGui = gui
	return gui
end

-- HapticService's real per-device feedback can't be confirmed from this dev environment (no
-- physical device attached to Studio) -- see docs/prd/hatch-reveal-sequence.md. pcall +
-- IsVibrationSupported keep an unsupported/unexpected platform a silent no-op rather than
-- erroring the whole reveal sequence.
local function pulseHaptic(bucket: string)
	local intensity = HAPTIC_INTENSITY[bucket]
	if not intensity then
		return
	end
	for _, inputType in HAPTIC_CANDIDATE_INPUT_TYPES do
		pcall(function()
			if HapticService:IsVibrationSupported(inputType) then
				HapticService:SetMotor(inputType, Enum.VibrationMotor.Small, intensity)
			end
		end)
	end
end

local function playSoundCues(cues: { Types.HatchSoundCue }?, parent: Instance)
	if not cues then
		return
	end
	local soundsFolder = ReplicatedStorage:FindFirstChild(HATCH_SOUNDS_FOLDER_NAME)
	if not soundsFolder then
		return
	end

	for _, cue in cues do
		local template = soundsFolder:FindFirstChild(cue.name)
		if template then
			task.spawn(function()
				if cue.delaySeconds and cue.delaySeconds > 0 then
					task.wait(cue.delaySeconds)
				end
				if not parent.Parent then
					return
				end
				local sound = (template :: Sound):Clone()
				sound.Volume = cue.volume
				sound.PlaybackSpeed = cue.pitch
				sound.Looped = cue.looped == true
				sound.Parent = parent
				sound:Play()

				if cue.stopAfterSeconds then
					task.wait(cue.stopAfterSeconds)
					sound:Stop()
					sound:Destroy()
				elseif not sound.Looped then
					Debris:AddItem(sound, 6)
				end
			end)
		end
	end
end

local function stopLoopedSounds(anchor: Instance)
	for _, child in anchor:GetChildren() do
		if child:IsA("Sound") and child.Looped then
			child:Stop()
			child:Destroy()
		end
	end
end

local function colorFromList(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local RAINBOW_KEYPOINTS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 165, 0)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 200, 0)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 120, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 0, 255)),
})

local function spawnSparkleBurst(anchor: BasePart, color: Color3, sizeScale: number, rainbow: boolean)
	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = if rainbow then RAINBOW_KEYPOINTS else ColorSequence.new(color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35 * sizeScale),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Lifetime = NumberRange.new(0.5, 1.1)
	emitter.Speed = NumberRange.new(6 * sizeScale, 12 * sizeScale)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(math.floor(20 * sizeScale))

	Debris:AddItem(attachment, 2.5)
end

local function spawnShockwaveRing(position: Vector3, color: Color3)
	local ring = Instance.new("Part")
	ring.Name = "HatchShockwave"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Transparency = 0.2
	ring.Parent = Workspace

	TweenService:Create(
		ring,
		TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.2, 16, 16), Transparency = 1 }
	):Play()
	Debris:AddItem(ring, 0.8)
end

-- Simplified "light rays": a handful of thin radiating Neon parts, not real Beam/god-rays --
-- a flagged placeholder, see docs/prd/hatch-reveal-sequence.md.
local function spawnLightRays(position: Vector3, color: Color3)
	for i = 1, 6 do
		local ray = Instance.new("Part")
		ray.Name = "HatchLightRay"
		ray.Material = Enum.Material.Neon
		ray.Color = color
		ray.Anchored = true
		ray.CanCollide = false
		ray.CanQuery = false
		ray.Size = Vector3.new(0.15, 6, 0.15)
		ray.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
			* CFrame.Angles(0, math.rad(i * 60), 0)
			* CFrame.Angles(math.rad(20), 0, 0)
		ray.Transparency = 0.4
		ray.Parent = Workspace

		TweenService:Create(ray, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
			Size = ray.Size + Vector3.new(0, 3, 0),
		}):Play()
		Debris:AddItem(ray, 0.9)
	end
end

-- Approximated as a full-screen rainbow-tinted flash -- no real radial vignette asset is staged,
-- see docs/prd/hatch-reveal-sequence.md.
local function screenFlash(gui: ScreenGui)
	local flash = Instance.new("Frame")
	flash.Name = "HatchScreenFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0.2
	flash.ZIndex = 100
	flash.Parent = gui

	local gradient = Instance.new("UIGradient")
	gradient.Color = RAINBOW_KEYPOINTS
	gradient.Parent = flash

	TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	Debris:AddItem(flash, 0.5)
end

-- Small CFrame jitter around `part`'s own starting position -- purely a client-local cosmetic
-- effect (never replicated/authoritative), same rationale as every other Runtime-only visual in
-- this feature. Blocks the calling coroutine for `durationSeconds` (matches the shake beat's
-- length).
local function shakePart(part: BasePart, durationSeconds: number, magnitudeStuds: number)
	local basePosition = part.Position
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= durationSeconds or not part.Parent then
			connection:Disconnect()
			if part.Parent then
				part.Position = basePosition
			end
			return
		end
		part.Position = basePosition
			+ Vector3.new(
				(math.random() - 0.5) * 2 * magnitudeStuds,
				(math.random() - 0.5) * 2 * magnitudeStuds,
				(math.random() - 0.5) * 2 * magnitudeStuds
			)
	end)
	task.wait(durationSeconds)
end

-- Waits (bounded) for the dragon world model DragonSpawner just created server-side to
-- replicate to this client -- it's always named exactly `dragonId` under
-- Workspace.Nursery.<userId> regardless of whether it ends up standing in the Nursery or on a
-- Farm Plot tile (see DragonSpawner.Spawn).
local function waitForDragonModel(player: Player, dragonId: string): Model?
	local nursery = Workspace:WaitForChild("Nursery", 2)
	if not nursery then
		return nil
	end
	local playerFolder = nursery:WaitForChild(tostring(player.UserId), 2)
	if not playerFolder then
		return nil
	end
	return playerFolder:WaitForChild(dragonId, 2) :: Model?
end

-- Plays the full shake -> crack&flash -> claim -> reveal -> summary sequence for one hatch, then
-- returns. Meant to be called from inside a task.spawn (AutoClaimController already wraps each
-- hatch's auto-claim in its own coroutine so overlapping hatches don't block each other, aside
-- from sharing the single camera lock above).
function HatchRevealController.Play(
	player: Player,
	remotesFolder: Folder,
	requestIdGenerator: { Next: () -> number },
	hatchId: string,
	rarity: string
)
	local transactionRemote = remotesFolder:WaitForChild("Transaction") :: RemoteFunction
	local config = (HatchVisualConfig :: any)[rarity]
	if not config then
		-- Unknown/misconfigured rarity: still claim the hatch (never block real game state on
		-- a missing cosmetic config), just skip the cinematic entirely.
		local requestId = requestIdGenerator.Next()
		transactionRemote:InvokeServer(requestId, TransactionType.ClaimHatch, { HatchId = hatchId })
		return
	end

	acquireCameraLock()

	local camera = Workspace.CurrentCamera
	local originalCameraType = camera.CameraType
	local originalFov = camera.FieldOfView

	local character = player.Character
	local humanoid = character and (character:FindFirstChildOfClass("Humanoid") :: Humanoid?)
	local originalWalkSpeed = humanoid and humanoid.WalkSpeed
	local originalJumpPower = humanoid and humanoid.JumpPower
	local originalJumpHeight = humanoid and humanoid.JumpHeight

	local function releaseControl()
		if camera.Parent then
			camera.CameraType = originalCameraType
			camera.FieldOfView = originalFov
		end
		if humanoid and humanoid.Parent then
			humanoid.WalkSpeed = originalWalkSpeed :: number
			humanoid.JumpPower = originalJumpPower :: number
			humanoid.JumpHeight = originalJumpHeight :: number
		end
		releaseCameraLock()
	end

	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	end

	local hatchingEggsRoot = Workspace:FindFirstChild("HatchingEggs")
	local playerEggFolder = hatchingEggsRoot and hatchingEggsRoot:FindFirstChild(tostring(player.UserId))
	local eggPart = (playerEggFolder and playerEggFolder:FindFirstChild(hatchId)) :: BasePart?

	local anchorPosition = if eggPart
		then eggPart.Position
		elseif character then character:GetPivot().Position
		else camera.CFrame.Position

	-- Directed shot: reframe the camera to look at the egg from a fixed, rarity-scaled
	-- distance/FOV -- deliberately an *absolute* distance, not "N studs closer than wherever the
	-- player's camera happened to be": a directed shot needs to look the same regardless of the
	-- player's own zoom level. An earlier version derived distance from the player's current
	-- zoom (which in one Studio test sat ~57 studs out, barely moving at all) and, before that,
	-- from a flat `8 - pushInStuds` (which clipped the camera almost inside the egg on higher
	-- rarities) -- both were wrong for opposite reasons; this only keeps the *direction*
	-- (bearing) the player happened to be facing from, not the distance.
	camera.CameraType = Enum.CameraType.Scriptable
	local awayFromAnchor = camera.CFrame.Position - anchorPosition
	if awayFromAnchor.Magnitude < 1 then
		awayFromAnchor = Vector3.new(0, 2, 8)
	end
	local BASE_CAMERA_DISTANCE = 13
	local MIN_CAMERA_DISTANCE = 5
	local targetDistance = math.max(MIN_CAMERA_DISTANCE, BASE_CAMERA_DISTANCE - config.cameraPushInStuds)
	local targetPosition = anchorPosition + awayFromAnchor.Unit * targetDistance
	TweenService:Create(camera, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(targetPosition, anchorPosition),
		FieldOfView = math.max(30, originalFov - config.cameraFovDelta),
	}):Play()

	-- A dedicated, stable anchor for sounds/particles -- the egg part itself gets destroyed by
	-- the server the instant ClaimHatch commits, and the dragon model doesn't exist yet.
	local soundAnchor = Instance.new("Part")
	soundAnchor.Name = "HatchRevealAnchor"
	soundAnchor.Anchored = true
	soundAnchor.CanCollide = false
	soundAnchor.CanQuery = false
	soundAnchor.Transparency = 1
	soundAnchor.Size = Vector3.new(1, 1, 1)
	soundAnchor.CFrame = CFrame.new(anchorPosition)
	soundAnchor.Parent = Workspace

	-- Beat 1: Shake.
	playSoundCues(config.shakeSounds, soundAnchor)
	if eggPart then
		shakePart(eggPart, config.shakeDurationSeconds, config.shakeMagnitudeStuds)
	else
		task.wait(config.shakeDurationSeconds)
	end

	-- Beat 2: Crack & Flash.
	playSoundCues(config.crackSounds, soundAnchor)
	spawnSparkleBurst(soundAnchor, colorFromList(config.particleColor), config.particleSizeScale * 0.6, false)
	if config.hasHitch then
		-- A real pause on the crack frame -- Roblox has no engine-wide slow-motion without
		-- affecting physics/other players, so "slow-motion hitch" is approximated as a longer
		-- suspended beat with the flash/particles already visible, per the PRD's own "first-pass
		-- timing targets, meant to be tuned" framing.
		task.wait(config.hitchDurationSeconds)
	end
	task.wait(config.crackDurationSeconds)

	stopLoopedSounds(soundAnchor)

	-- The actual claim: server re-validates FinishAt, auto-places the dragon, and returns the
	-- authoritative result. Nothing about the cinematic above determined this outcome.
	local requestId = requestIdGenerator.Next()
	local result = transactionRemote:InvokeServer(requestId, TransactionType.ClaimHatch, { HatchId = hatchId })

	if not result or not result.Success then
		soundAnchor:Destroy()
		releaseControl()
		return
	end

	local dragonModel = waitForDragonModel(player, tostring(result.Data.DragonId))
	local revealPosition = if dragonModel then dragonModel:GetPivot().Position else anchorPosition
	soundAnchor.CFrame = CFrame.new(revealPosition)

	-- Beat 3: Reveal.
	playSoundCues(config.revealSounds, soundAnchor)
	spawnSparkleBurst(
		soundAnchor,
		colorFromList(config.particleColor),
		config.particleSizeScale,
		config.hasRainbowCascade
	)
	if config.hasShockwaveRing then
		spawnShockwaveRing(revealPosition, colorFromList(config.particleColor))
	end
	if config.hasLightRays then
		spawnLightRays(revealPosition, colorFromList(config.particleColor))
	end
	if config.hasRoar then
		task.delay(ROAR_HAPTIC_DELAY_SECONDS, pulseHaptic, config.hapticBucket)
	else
		pulseHaptic(config.hapticBucket)
	end
	if config.hasScreenFlash then
		screenFlash(getScreenGui(player))
	end

	task.wait(config.revealDurationSeconds)

	releaseControl()
	Debris:AddItem(soundAnchor, 3)

	local element = (dragonModel and dragonModel:GetAttribute("Element")) or "Unknown"
	local placementText = if result.Data.AssignedSlotId then "Placed on your farm" else "Sent to storage (farm full)"
	SummaryCardUI.Show(getScreenGui(player), {
		Title = `{result.Data.Rarity} {element} Dragon!{config.toastSuffix}`,
		Subtitle = `{result.Data.Rarity} - {element} - {placementText}`,
		AccentColor = colorFromList(config.toastAccentColor),
	})
end

return HatchRevealController
