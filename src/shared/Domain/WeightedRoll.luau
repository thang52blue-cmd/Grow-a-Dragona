-- Pure weighted pick over an explicit ordered key list: given the list (e.g. Rarities.List or
-- Elements.List), an odds table (e.g. a hatching tier's `.odds`, or DragonConfig.elementOdds),
-- and a rollValue in [0, 1), walks the list accumulating weight and returns the key whose
-- cumulative range contains rollValue. rollValue is an explicit parameter (not read from
-- math.random() internally) so callers/specs can inject an exact value and assert a
-- deterministic outcome; the server-side caller passes math.random() itself. Generalized
-- (was Rarity-only) once a second axis (Element) needed the same weighted-pick logic.
local WeightedRoll = {}

function WeightedRoll.pick(orderedKeys: { string }, odds: { [string]: number }, rollValue: number): string
	local cumulative = 0
	for _, key in orderedKeys do
		cumulative += odds[key] or 0
		if rollValue < cumulative then
			return key
		end
	end
	-- Odds not summing to exactly 1 (float drift) or rollValue landing past the last
	-- boundary -- fall back to the last key in the fixed order rather than error.
	return orderedKeys[#orderedKeys]
end

return WeightedRoll
