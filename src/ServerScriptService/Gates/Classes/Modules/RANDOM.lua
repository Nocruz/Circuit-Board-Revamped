--!strict

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local Gate = require(ServerScriptService.Gates.Definitions.Gate)

local AttributeService = require(ServerScriptService.Gates.Services.AttributeService)

local Factory = require(ServerScriptService.Gates.Classes.Factory)

local function Update(gate: Factory.TGate): Factory.TSignal
	local input = Gate.getBooleanInput(gate.Inputs.Generate)
	if input == false then return 0 end
	
	local min, max = Gate.getNumericInput(gate.Inputs.Min), Gate.getNumericInput(gate.Inputs.Max)
	if min > max then min, max = max, min end
	
	return math.random(min, max)
end

local schema: Factory.TGateSchema = {
	name = script.Name,
	inputs = { "Min", "Generate", "Max" },
	hasOutput = true,
	Update = Update,
	Attributes = {
		["Min"] = AttributeService.new(0, {}, {}),
		["Max"] = AttributeService.new(10, {}, {})
	},
	
	Color = Color3.fromRGB(123, 0, 123),
	Material = Enum.Material.DiamondPlate,
	InputOffsets = { ["Min"] = Vector3.new(-0.5, 0, 0), ["Max"] = Vector3.new(0.5, 0, 0) }
}

return Factory.create(schema)