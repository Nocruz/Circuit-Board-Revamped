--!strict

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local Gate = require(ServerScriptService.Gates.Definitions.Gate)

local Factory = require(ServerScriptService.Gates.Classes.Factory)

local function Update(gate: Factory.TGate): Factory.TSignal
	return not (Gate.getBooleanInput(gate.Inputs.A) or Gate.getBooleanInput(gate.Inputs.B))
end

local schema: Factory.TGateSchema = {
	name = script.Name,
	inputs = { "A", "B" },
	hasOutput = true,
	Update = Update,
	
	Color = Color3.fromRGB(164, 189, 71),
}

return Factory.create(schema)