local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
	"AddTestGold",
	"SpendTestGold",
	"AddTestFood",
	"RemoveTestFood",
	"ProfileUpdated",
}

local RemotesSetup = {}

function RemotesSetup.Init(): Folder
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing then
		return existing :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = "Remotes"

	for _, name in REMOTE_NAMES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end

	folder.Parent = ReplicatedStorage
	return folder
end

return RemotesSetup
