local process = require("@lune/process")
local Check = require("../TestSupport/Check")
local ProductionRules = require("./ProductionRules")

local CONFIG = { productionIntervalSeconds = 180, nestCapacity = 12, startingFarmSlots = 3 }

local function slotAt(uncollected: number, startedAt: number?, paused: boolean?)
	return {
		SlotId = 1,
		AssignedDragonUID = "dragon-1",
		ProductionStartedAt = startedAt,
		UncollectedEggCount = uncollected,
		IsProductionPaused = if paused ~= nil then paused else false,
	}
end

local passed = Check.runAll({
	{
		name = "an unassigned slot (no dragon) is returned unchanged",
		run = function()
			local slot = {
				SlotId = 1,
				AssignedDragonUID = nil,
				ProductionStartedAt = nil,
				UncollectedEggCount = 0,
				IsProductionPaused = false,
			}
			local advanced = ProductionRules.Advance(slot, 1000, CONFIG)
			Check.equal(advanced.UncollectedEggCount, 0)
			Check.equal(advanced.AssignedDragonUID, nil)
		end,
	},
	{
		name = "less than one full interval elapsed creates no eggs",
		run = function()
			local slot = slotAt(0, 1000)
			local advanced = ProductionRules.Advance(slot, 1000 + 179, CONFIG)
			Check.equal(advanced.UncollectedEggCount, 0)
			Check.equal(advanced.ProductionStartedAt, 1000)
		end,
	},
	{
		name = "exactly one completed interval creates exactly one egg and advances ProductionStartedAt",
		run = function()
			local slot = slotAt(0, 1000)
			local advanced = ProductionRules.Advance(slot, 1000 + 180, CONFIG)
			Check.equal(advanced.UncollectedEggCount, 1)
			Check.equal(advanced.ProductionStartedAt, 1180)
			Check.isFalse(advanced.IsProductionPaused)
		end,
	},
	{
		name = "multiple completed intervals create multiple eggs in one Advance call",
		run = function()
			local slot = slotAt(0, 1000)
			local advanced = ProductionRules.Advance(slot, 1000 + (180 * 5) + 10, CONFIG)
			Check.equal(advanced.UncollectedEggCount, 5)
			Check.equal(advanced.ProductionStartedAt, 1000 + 180 * 5)
		end,
	},
	{
		name = "production pauses exactly at nestCapacity and never exceeds it",
		run = function()
			local slot = slotAt(10, 1000)
			local advanced = ProductionRules.Advance(slot, 1000 + (180 * 5), CONFIG)
			Check.equal(advanced.UncollectedEggCount, 12)
			Check.isTrue(advanced.IsProductionPaused)
		end,
	},
	{
		name = "excess elapsed cycles past capacity are not banked -- only capacity-filling eggs are created",
		run = function()
			local slot = slotAt(11, 1000)
			local advanced = ProductionRules.Advance(slot, 1000 + (180 * 10), CONFIG)
			Check.equal(advanced.UncollectedEggCount, 12)
			-- ProductionStartedAt only advances by the 1 cycle actually applied, not all 10 elapsed
			Check.equal(advanced.ProductionStartedAt, 1180)
		end,
	},
	{
		name = "an already-full Nest creates no further eggs",
		run = function()
			local slot = slotAt(12, 1000, true)
			local advanced = ProductionRules.Advance(slot, 1000 + (180 * 3), CONFIG)
			Check.equal(advanced.UncollectedEggCount, 12)
			Check.equal(advanced.ProductionStartedAt, 1000)
		end,
	},
	{
		name = "Advance does not mutate the input slot",
		run = function()
			local slot = slotAt(0, 1000)
			ProductionRules.Advance(slot, 1000 + 180, CONFIG)
			Check.equal(slot.UncollectedEggCount, 0)
			Check.equal(slot.ProductionStartedAt, 1000)
		end,
	},
})

process.exit(if passed then 0 else 1)
