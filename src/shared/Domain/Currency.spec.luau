local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local Currency = require("./Currency")

local MAX_GOLD = 1000

local passed = Check.runAll({
	{
		name = "add increases balance by amount",
		run = function()
			local ok, newBalance = Currency.add(10, 5, MAX_GOLD)
			Check.isTrue(ok)
			Check.equal(newBalance, 15)
		end,
	},
	{
		name = "add clamps at maxGold",
		run = function()
			local ok, newBalance = Currency.add(MAX_GOLD - 2, 10, MAX_GOLD)
			Check.isTrue(ok)
			Check.equal(newBalance, MAX_GOLD)
		end,
	},
	{
		name = "add rejects a negative amount and leaves balance unchanged",
		run = function()
			local ok, newBalance = Currency.add(10, -5, MAX_GOLD)
			Check.isFalse(ok)
			Check.equal(newBalance, 10)
		end,
	},
	{
		name = "add rejects a non-integer amount",
		run = function()
			local ok = Currency.add(10, 1.5, MAX_GOLD)
			Check.isFalse(ok)
		end,
	},
	{
		name = "add rejects NaN",
		run = function()
			local ok = Currency.add(10, 0 / 0, MAX_GOLD)
			Check.isFalse(ok)
		end,
	},
	{
		name = "spend decreases balance by amount",
		run = function()
			local ok, newBalance = Currency.spend(10, 4)
			Check.isTrue(ok)
			Check.equal(newBalance, 6)
		end,
	},
	{
		name = "spend the exact balance succeeds and reaches zero",
		run = function()
			local ok, newBalance = Currency.spend(10, 10)
			Check.isTrue(ok)
			Check.equal(newBalance, 0)
		end,
	},
	{
		name = "spend more than the balance is rejected and leaves balance unchanged",
		run = function()
			local ok, newBalance = Currency.spend(10, 11)
			Check.isFalse(ok)
			Check.equal(newBalance, 10)
		end,
	},
	{
		name = "spend rejects a negative amount",
		run = function()
			local ok = Currency.spend(10, -1)
			Check.isFalse(ok)
		end,
	},
})

process.exit(if passed then 0 else 1)
