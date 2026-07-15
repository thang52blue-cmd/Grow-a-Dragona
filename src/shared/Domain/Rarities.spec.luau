local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local Rarities = require("./Rarities")

local passed = Check.runAll({
	{
		name = "List contains exactly the 5 known rarities in a fixed order",
		run = function()
			Check.equal(#Rarities.List, 5)
			Check.equal(Rarities.List[1], "Common")
			Check.equal(Rarities.List[2], "Rare")
			Check.equal(Rarities.List[3], "Epic")
			Check.equal(Rarities.List[4], "Legendary")
			Check.equal(Rarities.List[5], "Mythic")
		end,
	},
	{
		name = "IsValid accepts every known rarity",
		run = function()
			for _, rarity in Rarities.List do
				Check.isTrue(Rarities.IsValid(rarity))
			end
		end,
	},
	{
		name = "IsValid rejects unknown strings, non-strings, and nil",
		run = function()
			Check.isFalse(Rarities.IsValid("NotARarity"))
			Check.isFalse(Rarities.IsValid("common")) -- case-sensitive
			Check.isFalse(Rarities.IsValid(1))
			Check.isFalse(Rarities.IsValid(nil))
			Check.isFalse(Rarities.IsValid({}))
		end,
	},
})

process.exit(if passed then 0 else 1)
