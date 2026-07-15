local Rarities = require("./Rarities")

-- Pure weighted pick over the 5 rarities: given an odds table (e.g. a hatching tier's
-- `.odds`) and a rollValue in [0, 1), walks Rarities.List accumulating weight and returns
-- the rarity whose cumulative range contains rollValue. rollValue is an explicit parameter
-- (not read from math.random() internally) so callers/specs can inject an exact value and
-- assert a deterministic outcome; the server-side caller passes math.random() itself.
local WeightedRoll = {}

function WeightedRoll.pick(odds: { [string]: number }, rollValue: number): string
	local cumulative = 0
	for _, rarity in Rarities.List do
		cumulative += odds[rarity] or 0
		if rollValue < cumulative then
			return rarity
		end
	end
	-- Odds not summing to exactly 1 (float drift) or rollValue landing past the last
	-- boundary -- fall back to the last rarity in the fixed order rather than error.
	return Rarities.List[#Rarities.List]
end

return WeightedRoll
