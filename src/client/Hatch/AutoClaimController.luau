-- Automatically fires ClaimHatch once a pending hatch's server-set FinishAt has passed --
-- the player doesn't need to click anything for the egg to "finish". The server
-- re-validates `now >= FinishAt` itself (ClaimHatchRules.Stage), so a client that's slow,
-- offline, or lying about the time can't claim early; worst case it just claims late.
--
-- The actual claim (and the shake/crack/reveal/summary cinematic around it, docs/prd/
-- hatch-reveal-sequence.md) is delegated to HatchRevealController -- this module is only
-- responsible for noticing *when* each pending hatch is ready and making sure each HatchId only
-- gets one in-flight claim at a time.
local RunService = game:GetService("RunService")

local HatchRevealController = require(script.Parent.HatchRevealController)

local AutoClaimController = {}

export type PendingHatch = {
	Id: string,
	Rarity: string,
	StartedAt: number,
	FinishAt: number,
}

function AutoClaimController.Init(
	player: Player,
	remotesFolder: Folder,
	requestIdGenerator: { Next: () -> number },
	getPendingHatches: () -> { [string]: PendingHatch }
)
	local inFlight: { [string]: boolean } = {}

	RunService.Heartbeat:Connect(function()
		local now = os.time()
		for hatchId, pending in getPendingHatches() do
			if not inFlight[hatchId] and now >= pending.FinishAt then
				inFlight[hatchId] = true
				task.spawn(function()
					HatchRevealController.Play(player, remotesFolder, requestIdGenerator, hatchId, pending.Rarity)
					inFlight[hatchId] = nil
				end)
			end
		end
	end)
end

return AutoClaimController
