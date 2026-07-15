-- Updates the floating countdown label on every world-visible hatching egg (tagged
-- "HatchingEgg" by src/server/Services/HatchSpawner.luau). Purely a display concern --
-- `FinishAt` is a server-set attribute (an absolute timestamp); the client clock is only
-- used to format "how many seconds are left" for the player, never to decide anything.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local HATCH_TAG = "HatchingEgg"

local HatchCountdownController = {}

local function formatRemaining(seconds: number): string
	if seconds <= 0 then
		return "Hatching..."
	end
	return `{seconds}s`
end

local function attachCountdown(egg: Instance)
	local billboard = egg:FindFirstChild("HatchCountdown")
	local label = billboard and billboard:FindFirstChild("CountdownLabel") :: TextLabel?
	if not label then
		return
	end
	local textLabel = label :: TextLabel

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if not egg.Parent then
			connection:Disconnect()
			return
		end

		local finishAt = egg:GetAttribute("FinishAt")
		if type(finishAt) ~= "number" then
			return
		end

		local remaining = math.max(0, math.ceil(finishAt - os.time()))
		textLabel.Text = formatRemaining(remaining)
	end)
end

function HatchCountdownController.Init()
	for _, egg in CollectionService:GetTagged(HATCH_TAG) do
		attachCountdown(egg)
	end
	CollectionService:GetInstanceAddedSignal(HATCH_TAG):Connect(attachCountdown)
end

return HatchCountdownController
