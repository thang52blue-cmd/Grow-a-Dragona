local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local Elements = require("./Elements")

local passed = Check.runAll({
	{
		name = "List contains exactly the 5 known elements in a fixed order",
		run = function()
			Check.equal(#Elements.List, 5)
			Check.equal(Elements.List[1], "Fire")
			Check.equal(Elements.List[2], "Water")
			Check.equal(Elements.List[3], "Earth")
			Check.equal(Elements.List[4], "Light")
			Check.equal(Elements.List[5], "Dark")
		end,
	},
	{
		name = "IsValid accepts every known element",
		run = function()
			for _, element in Elements.List do
				Check.isTrue(Elements.IsValid(element))
			end
		end,
	},
	{
		name = "IsValid rejects unknown strings, non-strings, and nil",
		run = function()
			Check.isFalse(Elements.IsValid("NotAnElement"))
			Check.isFalse(Elements.IsValid("fire")) -- case-sensitive
			Check.isFalse(Elements.IsValid(1))
			Check.isFalse(Elements.IsValid(nil))
			Check.isFalse(Elements.IsValid({}))
		end,
	},
})

process.exit(if passed then 0 else 1)
