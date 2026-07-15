local Types = require("../Types/Types")

local ProfileSchema = {}

ProfileSchema.CURRENT_SCHEMA_VERSION = 1

function ProfileSchema.default(startingGold: number): Types.Profile
	return {
		gold = startingGold,
		inventory = {},
		meta = {
			schemaVersion = ProfileSchema.CURRENT_SCHEMA_VERSION,
			session = {
				jobId = nil,
				updatedAt = 0,
			},
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

	return true,
		{
			gold = gold,
			inventory = inventory :: Types.Inventory,
			meta = {
				schemaVersion = meta.schemaVersion,
				session = {
					jobId = sessionJobId,
					updatedAt = sessionUpdatedAt,
				},
			},
		},
		nil
end

return ProfileSchema
