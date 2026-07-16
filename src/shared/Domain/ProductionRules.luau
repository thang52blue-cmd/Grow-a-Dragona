-- Pure timestamp-based Egg production calculation (backlog item 6). No engine globals or IO
-- (AGENTS.md hard rule) -- `now` is always an explicit parameter, never read from the engine
-- clock. See adr/ADR-004-farm-slot-and-nest-schema.md and docs/prd/core-game-loop.md's
-- "ProductionService" section, whose suggested calculation this implements verbatim.
local Types = require("../Types/Types")

local ProductionRules = {}

-- Advance: returns a new FarmSlot with completed production cycles applied, without mutating
-- the input. An unassigned slot (no dragon, no ProductionStartedAt) is returned unchanged --
-- there is nothing to produce. When the Nest is already at capacity, `eggsToCreate` is 0
-- (availableCapacity is 0), so excess elapsed time is deliberately never banked into extra eggs
-- once collection resumes production -- matches the PRD's "do not bank excess elapsed cycles"
-- rule.
function ProductionRules.Advance(slot: Types.FarmSlot, now: number, config: Types.ProductionConfig): Types.FarmSlot
	if slot.AssignedDragonUID == nil or slot.ProductionStartedAt == nil then
		return table.clone(slot)
	end

	local elapsedTime = now - slot.ProductionStartedAt
	local completedCycles = math.floor(elapsedTime / config.productionIntervalSeconds)
	if completedCycles <= 0 then
		return table.clone(slot)
	end

	local availableCapacity = config.nestCapacity - slot.UncollectedEggCount
	local eggsToCreate = math.min(completedCycles, availableCapacity)
	if eggsToCreate <= 0 then
		return table.clone(slot)
	end

	local newUncollectedEggCount = slot.UncollectedEggCount + eggsToCreate
	local newProductionStartedAt = slot.ProductionStartedAt + (eggsToCreate * config.productionIntervalSeconds)

	return {
		SlotId = slot.SlotId,
		AssignedDragonUID = slot.AssignedDragonUID,
		ProductionStartedAt = newProductionStartedAt,
		UncollectedEggCount = newUncollectedEggCount,
		IsProductionPaused = newUncollectedEggCount >= config.nestCapacity,
	}
end

return ProductionRules
