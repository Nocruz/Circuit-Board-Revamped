--!strict

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local Gate = require(ServerScriptService.Gates.Definitions.Gate)

local AttributeService = require(ServerScriptService.Gates.Services.AttributeService)

local Factory = require(ServerScriptService.Gates.Classes.Factory)

local function Update(gate: Factory.TGate): Factory.TSignal
	local min, max = Gate.getAttribute(gate, "Min", gate.Inputs.Min) :: number, Gate.getAttribute(gate, "Max", gate.Inputs.Max) :: number
	if min > max then min, max = max, min end
	
	return math.clamp(Gate.getNumericInput(gate.Inputs.Input), min, max)
end

local schema: Factory.TGateSchema = {
	name = script.Name,
	inputs = { "Min", "Input", "Max" },
	hasOutput = true,
	Update = Update,
	Attributes = {
		["Min"] = AttributeService.new(0, {}, {}),
		["Max"] = AttributeService.new(10, {}, {})
	},
	
	Color = Color3.fromRGB(0, 85, 255),
	Material = Enum.Material.DiamondPlate,
	InputOffsets = { ["Min"] = Vector3.new(-0.5, 0, 0), ["Max"] = Vector3.new(0.5, 0, 0) }
}

return Factory.create(schema)