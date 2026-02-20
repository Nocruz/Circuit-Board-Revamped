--!strict
--[[ MOVER
		Moves around gate instances.
]]

-- Requires and services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

-- Debugger
local Logger = require(ReplicatedStorage.Shared.LoggerService)
local log = Logger.new("Move")

local Mover = {}

-- ----------------------------- ----------- HELPER METHODS ----------- ---------------------------

-- ----------------------------- ------------- MOVE GATE -------------- ---------------------------

function Mover.Move(gate: Model, cframe: CFrame)
	gate:PivotTo(cframe)
end

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return Mover