local Types = require("../Types/Types")

local SessionLock = {}

function SessionLock.canClaim(
	existingSession: Types.Session,
	jobId: string,
	now: number,
	timeoutSeconds: number
): boolean
	if existingSession.jobId == nil then
		return true
	end

	if existingSession.jobId == jobId then
		return true
	end

	return (now - existingSession.updatedAt) >= timeoutSeconds
end

return SessionLock
