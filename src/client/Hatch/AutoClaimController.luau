-- Automatically fires ClaimHatch once a pending hatch's server-set FinishAt has passed --
-- the player doesn't need to click anything for the egg to "finish". The server
-- re-validates `now >= FinishAt` itself (ClaimHatchRules.Stage), so a client that's slow,
-- offline, or lying about the time can't claim early; worst case it just claims late.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TransactionType = require(Shared.Domain.TransactionType)

local AutoClaimController = {}

export type PendingHatch = {
	Id: string,
	Rarity: string,
	StartedAt: number,
	FinishAt: number,
}

function AutoClaimController.Init(
	remotesFolder: Folder,
	requestIdGenerator: { Next: () -> number },
	getPendingHatches: () -> { [string]: PendingHatch }
)
	local transactionRemote = remotesFolder:WaitForChild("Transaction") :: RemoteFunction
	local inFlight: { [string]: boolean } = {}

	RunService.Heartbeat:Connect(function()
		local now = os.time()
		for hatchId, pending in getPendingHatches() do
			if not inFlight[hatchId] and now >= pending.FinishAt then
				inFlight[hatchId] = true
				task.spawn(function()
					local requestId = requestIdGenerator.Next()
					transactionRemote:InvokeServer(requestId, TransactionType.ClaimHatch, { HatchId = hatchId })
					inFlight[hatchId] = nil
				end)
			end
		end
	end)
end

return AutoClaimController
