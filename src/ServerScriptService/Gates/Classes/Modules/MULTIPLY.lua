--!strict

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local Gate = require(ServerScriptService.Gates.Definitions.Gate)

local Factory = require(ServerScriptService.Gates.Classes.Factory)

local function Update(gate: Factory.TGate): Factory.TSignal
	return Gate.getNumericInput(gate.Inputs.A) * Gate.getNumericInput(gate.Inputs.B)
end

local schema: Factory.TGateSchema = {
	name = script.Name,
	inputs = { "A", "B" },
	hasOutput = true,
	Update = Update,
	
	Color = Color3.fromRGB(55, 60, 85),
	Material = Enum.Material.DiamondPlate,
	DisplayName = "×"
}

return Factory.create(schema)