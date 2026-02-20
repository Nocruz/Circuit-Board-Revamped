--!strict

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local Gate = require(ServerScriptService.Gates.Definitions.Gate)

local AttributeService = require(ServerScriptService.Gates.Services.AttributeService)

local Factory = require(ServerScriptService.Gates.Classes.Factory)

local function Update(gate: Factory.TGate): Factory.TSignal
	return Gate.getAttribute(gate, "Value")
end

local schema: Factory.TGateSchema = {
	name = script.Name,
	inputs = { },
	hasOutput = true,
	Update = Update,
	
	Attributes = { ["Value"] = AttributeService.new("", {}, {}) },
	
	Color = Color3.fromRGB(68, 190, 54),
}

return Factory.create(schema)