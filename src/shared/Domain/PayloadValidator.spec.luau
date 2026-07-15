local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local PayloadValidator = require("./PayloadValidator")

local passed = Check.runAll({
	{
		name = "IsFiniteNumber accepts an ordinary number",
		run = function()
			Check.isTrue(PayloadValidator.IsFiniteNumber(5))
		end,
	},
	{
		name = "IsFiniteNumber rejects NaN",
		run = function()
			Check.isFalse(PayloadValidator.IsFiniteNumber(0 / 0))
		end,
	},
	{
		name = "IsFiniteNumber rejects math.huge and -math.huge",
		run = function()
			Check.isFalse(PayloadValidator.IsFiniteNumber(math.huge))
			Check.isFalse(PayloadValidator.IsFiniteNumber(-math.huge))
		end,
	},
	{
		name = "IsFiniteNumber rejects non-numbers",
		run = function()
			Check.isFalse(PayloadValidator.IsFiniteNumber("5"))
			Check.isFalse(PayloadValidator.IsFiniteNumber(nil))
			Check.isFalse(PayloadValidator.IsFiniteNumber({}))
		end,
	},
	{
		name = "IsIntegerInRange accepts an integer within bounds",
		run = function()
			Check.isTrue(PayloadValidator.IsIntegerInRange(5, 0, 10))
		end,
	},
	{
		name = "IsIntegerInRange rejects a decimal",
		run = function()
			Check.isFalse(PayloadValidator.IsIntegerInRange(5.5, 0, 10))
		end,
	},
	{
		name = "IsIntegerInRange rejects a value below the minimum",
		run = function()
			Check.isFalse(PayloadValidator.IsIntegerInRange(-1, 0, 10))
		end,
	},
	{
		name = "IsIntegerInRange rejects a value above the maximum",
		run = function()
			Check.isFalse(PayloadValidator.IsIntegerInRange(11, 0, 10))
		end,
	},
	{
		name = "IsPositiveInteger accepts 1 and rejects 0",
		run = function()
			Check.isTrue(PayloadValidator.IsPositiveInteger(1, 10))
			Check.isFalse(PayloadValidator.IsPositiveInteger(0, 10))
		end,
	},
	{
		name = "IsPositiveInteger rejects a negative amount",
		run = function()
			Check.isFalse(PayloadValidator.IsPositiveInteger(-1, 10))
		end,
	},
	{
		name = "IsPositiveInteger rejects an amount over the given maximum",
		run = function()
			Check.isFalse(PayloadValidator.IsPositiveInteger(999999, 10))
		end,
	},
	{
		name = "IsPositiveInteger rejects NaN",
		run = function()
			Check.isFalse(PayloadValidator.IsPositiveInteger(0 / 0, 10))
		end,
	},
})

process.exit(if passed then 0 else 1)
