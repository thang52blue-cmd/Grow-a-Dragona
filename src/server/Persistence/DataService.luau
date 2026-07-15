local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ProfileSchema = require(Shared.Domain.ProfileSchema)
local SessionLock = require(Shared.Domain.SessionLock)
local Types = require(Shared.Types.Types)
local EconomyConfig = require(Shared.Data.EconomyConfig) :: Types.EconomyConfig

local PROFILE_STORE_NAME = "PlayerProfiles_v1"
local SESSION_LOCK_TIMEOUT_SECONDS = 30

local dataStoreOk, dataStoreOrErr = pcall(function()
	return DataStoreService:GetDataStore(PROFILE_STORE_NAME)
end)
local dataStore: DataStore? = if dataStoreOk then dataStoreOrErr :: DataStore else nil
local dataStoreInitError: string? = if dataStoreOk then nil else tostring(dataStoreOrErr)

local cache: { [number]: Types.Profile } = {}

local function keyFor(userId: number): string
	return "Player_" .. tostring(userId)
end

local DataService = {}

function DataService.Load(userId: number, jobId: string): (boolean, Types.Profile?, string?)
	if cache[userId] then
		return true, cache[userId], nil
	end

	if not dataStore then
		return false, nil, "datastore unavailable: " .. tostring(dataStoreInitError)
	end

	local getOk, raw = pcall(function()
		return dataStore:GetAsync(keyFor(userId))
	end)

	if not getOk then
		return false, nil, "datastore GetAsync failed: " .. tostring(raw)
	end

	local profile: Types.Profile
	if raw == nil then
		profile = ProfileSchema.default(EconomyConfig.startingGold)
	else
		local validOk, validated, validateErr = ProfileSchema.validate(raw)
		if not validOk then
			return false, nil, "corrupt profile: " .. tostring(validateErr)
		end
		profile = validated :: Types.Profile
	end

	local now = os.time()
	if not SessionLock.canClaim(profile.meta.session, jobId, now, SESSION_LOCK_TIMEOUT_SECONDS) then
		return false, nil, "profile locked by another server"
	end

	profile.meta.session = { jobId = jobId, updatedAt = now }
	cache[userId] = profile

	return true, profile, nil
end

function DataService.Get(userId: number): Types.Profile?
	return cache[userId]
end

function DataService.Save(userId: number): (boolean, string?)
	local profile = cache[userId]
	if not profile then
		return false, "no cached profile for user " .. tostring(userId)
	end

	if not dataStore then
		return false, "datastore unavailable: " .. tostring(dataStoreInitError)
	end

	profile.meta.session.updatedAt = os.time()

	local setOk, setErr = pcall(function()
		dataStore:SetAsync(keyFor(userId), profile)
	end)

	if not setOk then
		return false, "datastore SetAsync failed: " .. tostring(setErr)
	end

	return true, nil
end

function DataService.Release(userId: number): (boolean, string?)
	local profile = cache[userId]
	if not profile then
		return true, nil
	end

	profile.meta.session = { jobId = nil, updatedAt = os.time() }
	local ok, err = DataService.Save(userId)
	cache[userId] = nil

	return ok, err
end

return DataService
