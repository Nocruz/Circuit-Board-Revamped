--!strict

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local Gate = require(ServerScriptService.Gates.Definitions.Gate)

local SignalService = require(ServerScriptService.Gates.Services.SignalService)
local AttributeService = require(ServerScriptService.Gates.Services.AttributeService)
local UpdateService = require(ServerScriptService.Gates.Services.UpdateService)

local Factory = require(ServerScriptService.Gates.Classes.Factory)

local function Update(gate: Factory.TGate, origin: "Signal" | "Schedule"): Factory.TSignal
	local inputSignal = Gate.getSignalInput(gate.Inputs.Input)
	local inputActive = SignalService.toBoolean(inputSignal)
	local delayTime = Gate.getAttribute(gate, "Delay") :: number

	-- Bypass instantáneo
	if delayTime <= 0 then return inputSignal end

	if origin == "Signal" then
		UpdateService.schedule(gate, delayTime)

		return gate.Output
	end

	if origin == "Schedule" then
		return inputSignal
	end

	return gate.Output
end

local schema: Factory.TGateSchema = {
	name = script.Name,
	inputs = { "Input" },
	hasOutput = true,
	Update = Update,
	Attributes = {
		["Delay"] = AttributeService.new(0.5, {}, {function(value) return value >= 0 end}),
	},
	
	Color = Color3.fromRGB(0, 0, 34),
	Material = Enum.Material.DiamondPlate
}

return Factory.create(schema)