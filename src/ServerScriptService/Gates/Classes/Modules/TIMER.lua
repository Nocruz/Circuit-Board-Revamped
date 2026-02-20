-- Requires and services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AttributeService = require(ServerScriptService.Gates.Services.AttributeService)
local SignalService = require(ServerScriptService.Gates.Services.SignalService)
local UpdateService = require(ServerScriptService.Gates.Services.UpdateService)
local PermissionService = require(ServerScriptService.Players.PermissionService)

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- -----------------------------

local Gate = require(ServerScriptService.Gates.Definitions.Gate)
local GateClass = require(ServerScriptService.Gates.Definitions.GateClass)
local Types = require(ServerScriptService.Gates.Definitions.Types)

type TGate = Types.TGate
type TGateClass = Types.TGateClass
type TGateVisuals = Types.TGateVisuals
type TSignal = Types.TSignal

-- ----------------------------- -------- GATE CLASS DEFINITION ------- -----------------------------

local TimerClass = {}
TimerClass.__index = TimerClass
setmetatable(TimerClass, GateClass)

TimerClass.name = "TIMER"
TimerClass.inputs = { "Input" }
TimerClass.output = "Output"

TimerClass.validAttributes = {
	["Delay"]	 = AttributeService.new(0.5, {}, { function(value) return value >= 0 end }),
	["Duration"] = AttributeService.new(0.5, {}, { function(value) return value >= 0 end })
}

function TimerClass.new(id: number, ownerId: number, gateModel: Types.TGateModel): TGate
	local gate = setmetatable(GateClass.new(id, ownerId, gateModel), TimerClass) :: TGate

	gate.Class = TimerClass

	-- Set nodes
	gate.Inputs = { ["Input"] = {} }
	gate.Output = false
	gate.Connections = {}
	
	gate.Attributes = {
		["Delay"] = AttributeService.getDefault(TimerClass.validAttributes["Delay"]),
		["Duration"] = AttributeService.getDefault(TimerClass.validAttributes["Duration"])
	}
	
	gate.timerMode = "IDLE" -- "IDLE" | "WAITING_ON" | "WAITING_OFF"

	return gate
end

function TimerClass.Update(gate: TGate, origin: "Signal" | "Schedule"): TSignal
	local inputActive = Gate.getBooleanInput(gate.Inputs.Input)
	local delay = Gate.getAttribute(gate, "Delay")
	local duration = Gate.getAttribute(gate, "Duration")

	if origin == "Signal" then
		if not inputActive then
			UpdateService.cancel(gate)
			gate.timerMode = "IDLE"
			return false
		end

		if gate.timerMode == "IDLE" then
			gate.timerMode = "WAITING_ON"
			UpdateService.schedule(gate, delay)
			return false
		end

		-- To reset after a change on input
		-- UpdateService.schedule(gate, delay)

		return gate.Output
	end

	if origin == "Schedule" then
		if gate.timerMode == "WAITING_ON" then
			gate.timerMode = "WAITING_OFF"
			UpdateService.schedule(gate, duration)
			return true

		elseif gate.timerMode == "WAITING_OFF" then
			gate.timerMode = "IDLE"
			return false
		end
	end

	return gate.Output
end

return TimerClass