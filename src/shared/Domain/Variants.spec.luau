local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local Variants = require("./Variants")

local passed = Check.runAll({
	{
		name = "List contains exactly the 5 known Production Egg variants in a fixed order",
		run = function()
			Check.equal(#Variants.List, 5)
			Check.equal(Variants.List[1], "Normal")
			Check.equal(Variants.List[2], "Mini")
			Check.equal(Variants.List[3], "Heavy")
			Check.equal(Variants.List[4], "Giant")
			Check.equal(Variants.List[5], "Golden")
		end,
	},
	{
		name = "IsValid accepts every known variant",
		run = function()
			for _, variant in Variants.List do
				Check.isTrue(Variants.IsValid(variant))
			end
		end,
	},
	{
		name = "IsValid rejects unknown strings, non-strings, and nil",
		run = function()
			Check.isFalse(Variants.IsValid("NotAVariant"))
			Check.isFalse(Variants.IsValid("normal")) -- case-sensitive
			Check.isFalse(Variants.IsValid(1))
			Check.isFalse(Variants.IsValid(nil))
			Check.isFalse(Variants.IsValid({}))
		end,
	},
})

process.exit(if passed then 0 else 1)
