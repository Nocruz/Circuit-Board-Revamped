--!strict

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local Gate = require(ServerScriptService.Gates.Definitions.Gate)

local Factory = require(ServerScriptService.Gates.Classes.Factory)

local function Update(gate: Factory.TGate): Factory.TSignal
	return math.tan(Gate.getNumericInput(gate.Inputs.Input))
end

local schema: Factory.TGateSchema = {
	name = script.Name,
	inputs = { "Input" },
	hasOutput = true,
	Update = Update,
	
	Color = Color3.fromRGB(159, 161, 172),
	Material = Enum.Material.DiamondPlate
}

return Factory.create(schema)