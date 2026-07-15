local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_EVENT_NAMES = {
	"AddTestGold",
	"AddTestGold10000",
	"SpendTestGold",
	"ProfileUpdated",
}

-- Transaction: client -> server intent {RequestId, TypeId, Payload}, server -> TransactionResult.
-- A RemoteFunction (not an event) since the test-harness UI needs the result synchronously.
local REMOTE_FUNCTION_NAMES = {
	"Transaction",
}

local RemotesSetup = {}

function RemotesSetup.Init(): Folder
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		return existing :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = "Remotes"

	for _, name in REMOTE_EVENT_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end

	for _, name in REMOTE_FUNCTION_NAMES do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end

	folder.Parent = ReplicatedStorage
	return folder
end

return RemotesSetup
