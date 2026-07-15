-- Thin TransactionService handler for starting a hatch. All real logic (and its spec)
-- lives in the pure src/shared/Domain/StartHatchRules.luau -- this file only adapts it to
-- the Validate/Stage/Commit contract and supplies the server-only config. World-spawn of
-- the visible hatching egg is not this module's job -- it's a Runtime-only side effect
-- triggered from src/server/init.server.luau after a successful Submit, not a profile
-- mutation, so it stays out of Commit (see AGENTS.md's transaction model).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StartHatchRules = require(Shared.Domain.StartHatchRules)
local Types = require(Shared.Types.Types)
local EggConfig = require(Shared.Data.EggConfig) :: Types.EggConfig

local ZERO_POSITION: Types.Position = { X = 0, Y = 0, Z = 0 }

local StartHatchTransaction = {}

function StartHatchTransaction.Validate(_context, payload): (boolean, number?)
	return StartHatchRules.Validate(EggConfig, payload)
end

-- The player's current position is an engine concept (HumanoidRootPart) that
-- StartHatchRules -- pure, no Instance access -- can't read itself, so it's resolved
-- here and passed in explicitly, same as context.TransactionTime.
local function currentPosition(player: Player): Types.Position
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return ZERO_POSITION
	end
	local position = (rootPart :: BasePart).Position
	return { X = position.X, Y = position.Y, Z = position.Z }
end

function StartHatchTransaction.Stage(context, payload): (boolean, number?)
	local ok, staged, code =
		StartHatchRules.Stage(EggConfig, context.Profile, payload, context.TransactionTime, currentPosition(context.Player))
	if not ok then
		return false, code
	end
	context.Staged = staged
	return true, nil
end

function StartHatchTransaction.Commit(context)
	context.ResultData = StartHatchRules.Commit(context.Profile, context.Staged)
end

return StartHatchTransaction
