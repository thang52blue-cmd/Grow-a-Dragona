local Rarities = require("./Rarities")
local Types = require("../Types/Types")

local ZERO_POSITION: Types.Position = { X = 0, Y = 0, Z = 0 }

local function isValidPosition(value: unknown): boolean
	if type(value) ~= "table" then
		return false
	end
	local raw = value :: { [string]: any }
	return type(raw.X) == "number" and type(raw.Y) == "number" and type(raw.Z) == "number"
end

local function toPosition(value: { [string]: any }): Types.Position
	return { X = value.X, Y = value.Y, Z = value.Z }
end

local ProfileSchema = {}

ProfileSchema.CURRENT_SCHEMA_VERSION = 1

function ProfileSchema.default(startingGold: number): Types.Profile
	return {
		gold = startingGold,
		inventory = {},
		pendingHatches = {},
		dragons = {},
		lastPosition = nil,
		meta = {
			schemaVersion = ProfileSchema.CURRENT_SCHEMA_VERSION,
			session = {
				jobId = nil,
				updatedAt = 0,
			},
			nextEntityId = 1,
		},
	}
end

function ProfileSchema.validate(data: unknown): (boolean, Types.Profile?, string?)
	if type(data) ~= "table" then
		return false, nil, "profile is not a table"
	end
	local rawProfile = data :: { [string]: any }

	local gold = rawProfile.gold
	if type(gold) ~= "number" or gold ~= gold or gold < 0 then
		return false, nil, "invalid gold"
	end

	local inventory = rawProfile.inventory
	if type(inventory) ~= "table" then
		return false, nil, "invalid inventory"
	end
	for itemId, quantity in inventory :: { [string]: any } do
		if type(itemId) ~= "string" or type(quantity) ~= "number" or quantity < 0 or quantity % 1 ~= 0 then
			return false, nil, "invalid inventory entry for " .. tostring(itemId)
		end
	end

	-- pendingHatches/dragons are additive fields -- profiles saved before this schema change
	-- predate them entirely, so absence defaults to empty rather than failing validation. A
	-- present-but-malformed entry still rejects the whole profile like every other field here.
	local pendingHatchesRaw = rawProfile.pendingHatches
	local pendingHatches: { [string]: Types.PendingHatch } = {}
	if pendingHatchesRaw ~= nil then
		if type(pendingHatchesRaw) ~= "table" then
			return false, nil, "invalid pendingHatches"
		end
		for hatchId, entry in pendingHatchesRaw :: { [string]: any } do
			if
				type(hatchId) ~= "string"
				or type(entry) ~= "table"
				or type(entry.Id) ~= "string"
				or not Rarities.IsValid(entry.Rarity)
				or type(entry.StartedAt) ~= "number"
				or type(entry.FinishAt) ~= "number"
				or (entry.Position ~= nil and not isValidPosition(entry.Position))
			then
				return false, nil, "invalid pendingHatches entry for " .. tostring(hatchId)
			end
			-- Position is additive too (pending hatches created before this change won't have
			-- one) -- default to the origin rather than reject.
			pendingHatches[hatchId] = {
				Id = entry.Id,
				Rarity = entry.Rarity,
				StartedAt = entry.StartedAt,
				FinishAt = entry.FinishAt,
				Position = if entry.Position then toPosition(entry.Position) else ZERO_POSITION,
			}
		end
	end

	local dragonsRaw = rawProfile.dragons
	local dragons: { [string]: Types.DragonRecord } = {}
	if dragonsRaw ~= nil then
		if type(dragonsRaw) ~= "table" then
			return false, nil, "invalid dragons"
		end
		for dragonId, entry in dragonsRaw :: { [string]: any } do
			if
				type(dragonId) ~= "string"
				or type(entry) ~= "table"
				or type(entry.Id) ~= "string"
				or not Rarities.IsValid(entry.Rarity)
				or type(entry.HatchedAt) ~= "number"
			then
				return false, nil, "invalid dragons entry for " .. tostring(dragonId)
			end
			dragons[dragonId] = {
				Id = entry.Id,
				Rarity = entry.Rarity,
				HatchedAt = entry.HatchedAt,
			}
		end
	end

	local lastPosition: Types.Position? = nil
	if rawProfile.lastPosition ~= nil then
		if not isValidPosition(rawProfile.lastPosition) then
			return false, nil, "invalid lastPosition"
		end
		lastPosition = toPosition(rawProfile.lastPosition)
	end

	local meta = rawProfile.meta
	if type(meta) ~= "table" or type(meta.schemaVersion) ~= "number" then
		return false, nil, "invalid meta"
	end

	local session = meta.session
	local sessionJobId: string? = nil
	local sessionUpdatedAt = 0
	if type(session) == "table" then
		if type(session.jobId) == "string" then
			sessionJobId = session.jobId
		end
		if type(session.updatedAt) == "number" then
			sessionUpdatedAt = session.updatedAt
		end
	end

	local nextEntityId = 1
	if type(meta.nextEntityId) == "number" and meta.nextEntityId >= 1 then
		nextEntityId = meta.nextEntityId
	end

	return true,
		{
			gold = gold,
			inventory = inventory :: Types.Inventory,
			pendingHatches = pendingHatches,
			dragons = dragons,
			lastPosition = lastPosition,
			meta = {
				schemaVersion = meta.schemaVersion,
				session = {
					jobId = sessionJobId,
					updatedAt = sessionUpdatedAt,
				},
				nextEntityId = nextEntityId,
			},
		},
		nil
end

return ProfileSchema
