--!strict

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local Gate = require(ServerScriptService.Gates.Definitions.Gate)

local Factory = require(ServerScriptService.Gates.Classes.Factory)

local function Update(gate: Factory.TGate): Factory.TSignal
	if not Gate.getBooleanInput(gate.Inputs.Bridge) then
		return ""
	else
		return Gate.getSignalInput(gate.Inputs.Input)
	end
end

local schema: Factory.TGateSchema = {
	name = script.Name,
	inputs = { "Input", "Bridge" },
	hasOutput = true,
	Update = Update,
	
	Color = Color3.fromRGB(0, 85, 0),
	InputOffsets = { ["Input"] = Vector3.new(0, 0, 0.5), ["Bridge"] = Vector3.new(0.5, 0, 0) }
}

return Factory.create(schema)