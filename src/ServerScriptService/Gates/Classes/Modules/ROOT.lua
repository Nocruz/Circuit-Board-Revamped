--!strict

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local Gate = require(ServerScriptService.Gates.Definitions.Gate)

local Factory = require(ServerScriptService.Gates.Classes.Factory)

local function Update(gate: Factory.TGate): Factory.TSignal
	return Gate.getNumericInput(gate.Inputs.Input) ^ (1 / Gate.getNumericInput(gate.Inputs.Root))
end

local schema: Factory.TGateSchema = {
	name = script.Name,
	inputs = { "Input", "Root" },
	hasOutput = true,
	Update = Update,
	
	Color = Color3.fromRGB(166, 99, 31),
	Material = Enum.Material.DiamondPlate,
	DisplayName = "√x",
}

return Factory.create(schema)