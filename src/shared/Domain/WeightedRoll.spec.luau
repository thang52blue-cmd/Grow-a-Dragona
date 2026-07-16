local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local WeightedRoll = require("./WeightedRoll")
local Rarities = require("./Rarities")

local passed = Check.runAll({
	{
		name = "picks the key whose cumulative range contains rollValue",
		run = function()
			-- Cumulative bounds: Common [0, .5) Rare [.5, .8) Epic [.8, .95) Legendary [.95, .999)
			-- Mythic [.999, 1). Sample points sit clearly inside each bucket, not on the exact
			-- theoretical boundary -- summing float odds (e.g. 0.5+0.3+0.15) doesn't land on an
			-- exact boundary value, so asserting AT a boundary is flaky by construction.
			local odds = { Common = 0.5, Rare = 0.3, Epic = 0.15, Legendary = 0.049, Mythic = 0.001 }
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 0), "Common")
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 0.3), "Common")
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 0.55), "Rare")
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 0.75), "Rare")
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 0.85), "Epic")
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 0.9), "Epic")
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 0.96), "Legendary")
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 0.9999), "Mythic")
		end,
	},
	{
		name = "a 100%-single-key odds table always returns that key",
		run = function()
			local odds = { Common = 0, Rare = 0, Epic = 0, Legendary = 0, Mythic = 1.0 }
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 0), "Mythic")
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 0.5), "Mythic")
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 0.999), "Mythic")
		end,
	},
	{
		name = "rollValue at or past 1 falls back to the last key instead of erroring",
		run = function()
			local odds = { Common = 0.99, Rare = 0.01, Epic = 0, Legendary = 0, Mythic = 0 }
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 1), "Mythic")
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 1.5), "Mythic")
		end,
	},
	{
		name = "missing odds entries default to 0 weight rather than erroring",
		run = function()
			local odds = { Common = 1.0 }
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 0), "Common")
			Check.equal(WeightedRoll.pick(Rarities.List, odds, 0.999), "Common")
		end,
	},
	{
		name = "works with a different ordered key list (e.g. Elements)",
		run = function()
			local elementOdds = { Fire = 0.2, Water = 0.2, Earth = 0.2, Light = 0.2, Dark = 0.2 }
			Check.equal(WeightedRoll.pick({ "Fire", "Water", "Earth", "Light", "Dark" }, elementOdds, 0), "Fire")
			Check.equal(WeightedRoll.pick({ "Fire", "Water", "Earth", "Light", "Dark" }, elementOdds, 0.85), "Dark")
		end,
	},
})

process.exit(if passed then 0 else 1)
