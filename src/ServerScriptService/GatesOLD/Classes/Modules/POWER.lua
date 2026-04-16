--!strict

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local Gate = require(ServerScriptService.Gates.Definitions.Gate)

local Factory = require(ServerScriptService.Gates.Classes.Factory)

local function Update(gate: Factory.TGate): Factory.TSignal
	return Gate.getNumericInput(gate.Inputs.Input) ^ (Gate.getNumericInput(gate.Inputs.Power))
end

local schema: Factory.TGateSchema = {
	name = script.Name,
	inputs = { "Input", "Power" },
	hasOutput = true,
	Update = Update,
	
	Color = Color3.fromRGB(166, 99, 31),
	Material = Enum.Material.DiamondPlate,
	DisplayName = "xⁿ",
}

return Factory.create(schema)