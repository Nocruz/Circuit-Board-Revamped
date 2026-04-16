--!strict

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local Gate = require(ServerScriptService.Gates.Definitions.Gate)

local AttributeService = require(ServerScriptService.Gates.Services.AttributeService)

local Factory = require(ServerScriptService.Gates.Classes.Factory)

local function Update(gate: Factory.TGate): Factory.TSignal
	local input = Gate.getNumericInput(gate.Inputs.Input)
	local tens = Gate.getAttribute(gate, "Tens", gate.Inputs.Tens) :: number
	local strategy = Gate.getAttribute(gate, "Strategy")
	
	local factor = 10 ^ (-tens)
	local scaledInput = input * factor
	
	local roundedValue
	if strategy == "Floor" then
		roundedValue = math.floor(scaledInput)
	elseif strategy == "Ceil" then
		roundedValue = math.ceil(scaledInput)
	else
		roundedValue = math.round(scaledInput)
	end
	
	return roundedValue / factor
end

local schema: Factory.TGateSchema = {
	name = script.Name,
	inputs = { "Input", "Tens" },
	hasOutput = true,
	Update = Update,
	Attributes = {
		["Strategy"] = AttributeService.new("Closest", { "Closest", "Floor", "Ceil" }, {}),
		["Tens"] = AttributeService.new(0, {}, { function(value: number) return value % 1 == 0 end })
	},
	
	Color = Color3.fromRGB(189, 195, 68),
	Material = Enum.Material.DiamondPlate,
	InputOffsets = { ["Input"] = Vector3.new(0, 0, 0.5), ["Tens"] = Vector3.new(0.5, 0, 0) }
}

return Factory.create(schema)