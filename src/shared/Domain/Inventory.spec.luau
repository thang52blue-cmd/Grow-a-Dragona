local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local Inventory = require("./Inventory")

local MAX_STACK = 100

local passed = Check.runAll({
	{
		name = "get returns 0 for an item never added",
		run = function()
			Check.equal(Inventory.get({}, "Fish"), 0)
		end,
	},
	{
		name = "add creates a new stack for a new item",
		run = function()
			local ok, next = Inventory.add({}, "Fish", 3, MAX_STACK)
			Check.isTrue(ok)
			Check.equal(next.Fish, 3)
		end,
	},
	{
		name = "add accumulates onto an existing stack",
		run = function()
			local ok, next = Inventory.add({ Fish = 5 }, "Fish", 3, MAX_STACK)
			Check.isTrue(ok)
			Check.equal(next.Fish, 8)
		end,
	},
	{
		name = "add does not mutate the input table",
		run = function()
			local original = { Fish = 5 }
			Inventory.add(original, "Fish", 3, MAX_STACK)
			Check.equal(original.Fish, 5)
		end,
	},
	{
		name = "add clamps at maxStack",
		run = function()
			local ok, next = Inventory.add({ Fish = MAX_STACK - 2 }, "Fish", 10, MAX_STACK)
			Check.isTrue(ok)
			Check.equal(next.Fish, MAX_STACK)
		end,
	},
	{
		name = "add rejects a non-positive quantity",
		run = function()
			local ok = Inventory.add({}, "Fish", 0, MAX_STACK)
			Check.isFalse(ok)
		end,
	},
	{
		name = "add rejects an empty itemId",
		run = function()
			local ok = Inventory.add({}, "", 1, MAX_STACK)
			Check.isFalse(ok)
		end,
	},
	{
		name = "remove decreases an existing stack",
		run = function()
			local ok, next = Inventory.remove({ Fish = 5 }, "Fish", 2)
			Check.isTrue(ok)
			Check.equal(next.Fish, 3)
		end,
	},
	{
		name = "remove deletes the key once the stack reaches zero",
		run = function()
			local ok, next = Inventory.remove({ Fish = 5 }, "Fish", 5)
			Check.isTrue(ok)
			Check.equal(next.Fish, nil)
		end,
	},
	{
		name = "remove more than available is rejected and leaves inventory unchanged",
		run = function()
			local ok, next = Inventory.remove({ Fish = 2 }, "Fish", 5)
			Check.isFalse(ok)
			Check.equal(next.Fish, 2)
		end,
	},
	{
		name = "remove rejects a non-positive quantity",
		run = function()
			local ok = Inventory.remove({ Fish = 2 }, "Fish", -1)
			Check.isFalse(ok)
		end,
	},
})

process.exit(if passed then 0 else 1)
