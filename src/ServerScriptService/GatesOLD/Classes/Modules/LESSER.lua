--!strict

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local Gate = require(ServerScriptService.Gates.Definitions.Gate)

local Factory = require(ServerScriptService.Gates.Classes.Factory)

local function Update(gate: Factory.TGate): Factory.TSignal
	local inputA, inputB = Gate.getNumericInput(gate.Inputs.A), Gate.getNumericInput(gate.Inputs.B)
	return if inputA < inputB then true else false
end

local schema: Factory.TGateSchema = {
	name = script.Name,
	inputs = { "A", "B" },
	hasOutput = true,
	Update = Update,
	
	Color = Color3.fromRGB(116, 139, 87),
	DisplayName = "<"
}

return Factory.create(schema)