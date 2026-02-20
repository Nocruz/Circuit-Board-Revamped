-- Gemini AI for this one
--[[ CLOCK (ASYMMETRIC) CLASS
		Behavior:
		- Input FALSE: OFF immediately and stops.
		- Input TRUE: 
			1. Stays ON for 'Duration' seconds.
			2. Stays OFF for 'Delay' seconds.
			3. Repeats.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local SignalService = require(ServerScriptService.Gates.Services.SignalService)
local UpdateService = require(ServerScriptService.Gates.Services.UpdateService)
local AttributeService = require(ServerScriptService.Gates.Services.AttributeService)

local Gate = require(ServerScriptService.Gates.Definitions.Gate)
local GateClass = require(ServerScriptService.Gates.Definitions.GateClass)
local Types = require(ServerScriptService.Gates.Definitions.Types)

type TGate = Types.TGate
type TSignal = Types.TSignal

-- ----------------------------- -------- GATE CLASS DEFINITION ------- -----------------------------

local ClockClass = {}
ClockClass.__index = ClockClass
setmetatable(ClockClass, GateClass)

ClockClass.name = "CLOCK"
ClockClass.inputs = { "Enable" }
ClockClass.output = "Output"

ClockClass.validAttributes = {
	["Delay"] = AttributeService.new(0.5, {}, {function(value) return value >= 0 end }),
	["Duration"] = AttributeService.new(0.5, {}, {function(value) return value >= 0 end })
}

function ClockClass.new(id: number, ownerId: number, gateModel: Types.TGateModel): TGate
	local gate = setmetatable(GateClass.new(id, ownerId, gateModel), ClockClass) :: TGate

	gate.Class = ClockClass
	gate.Inputs = { ["Enable"] = {} }
	gate.Output = false	
	gate.Connections = {}
	
	gate.Attributes = { ["Delay"] = ClockClass.validAttributes["Delay"].Default, ["Duration"] = ClockClass.validAttributes["Duration"].Default }

	return gate
end

function ClockClass.Update(gate: TGate, origin: "Signal" | "Schedule"): TSignal
	local enable = Gate.getBooleanInput(gate.Inputs.Enable)
	local delay = Gate.getAttribute(gate, "Delay")
	local duration = Gate.getAttribute(gate, "Duration")
	local currentOutput = SignalService.toBoolean(gate.Output)

	if origin == "Signal" and not enable then
		UpdateService.cancel(gate)
		return false
	end

	if origin == "Signal" and enable then
		UpdateService.schedule(gate, duration)
		return true
	end

	if origin == "Schedule" then
		if not enable then return false end

		if currentOutput == true then
			UpdateService.schedule(gate, delay)
			return false
		else
			UpdateService.schedule(gate, duration)
			return true
		end
	end

	return gate.Output
end

return ClockClass