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

local CounterClass = {} :: TGateClass
CounterClass.__index = CounterClass
setmetatable(CounterClass, GateClass)

CounterClass.name = "COUNTER"
CounterClass.inputs = { "Down", "Reset", "Up", "Increment", "ResetTo" }
CounterClass.output = "Output"

CounterClass.validAttributes = {
	["Min"] = AttributeService.new(-1000, {}, {}),
	["Max"] = AttributeService.new(1000, {}, {}),
	["Increment"] = AttributeService.new(1, {}, {}),
	["ResetTo"] = AttributeService.new(0, {}, {})
}

function CounterClass.new(id: number, ownerId: number, gateModel: Types.TGateModel): TGate
	local gate = setmetatable(GateClass.new(id, ownerId, gateModel), CounterClass) :: TGate

	gate.Class = CounterClass
	
	-- Set nodes
	gate.Inputs = { ["Down"] = {}, ["Reset"] = {}, ["Up"] = {}, ["Increment"] = {}, ["ResetTo"] = {} }
	gate.Connections = {}
	
	gate.Attributes = { ["Min"] = CounterClass.validAttributes["Min"].Default, ["Max"] = CounterClass.validAttributes["Max"].Default, ["Increment"] = CounterClass.validAttributes["Increment"].Default, ["ResetTo"] = CounterClass.validAttributes["ResetTo"].Default }
	gate.Output = Gate.getAttribute(gate, "ResetTo")
	
	gate.state = gate.Output
	gate.LastStates = {
		CountDown = false,
		CountUp = false,
		Reset = false
	}

	return gate
end

function CounterClass.Update(gate: TGate): TSignal
	local isDownActive	= Gate.getBooleanInput(gate.Inputs.Down)
	local isUpActive	= Gate.getBooleanInput(gate.Inputs.Up)
	local isResetActive	= Gate.getBooleanInput(gate.Inputs.Reset)

	local increment = Gate.getAttribute(gate, "Increment", gate.Inputs.Increment)
	local resetTo = Gate.getAttribute(gate, "ResetTo", gate.Inputs.ResetTo)

	local currentCount = gate.Output
	local nextCount = currentCount

	if isResetActive and not gate.LastStates.Reset then
		return resetTo
	else
		if isUpActive and not gate.LastStates.CountUp then
			nextCount += increment
		end

		if isDownActive and not gate.LastStates.CountDown then
			nextCount -= increment
		end
	end

	local min = Gate.getAttribute(gate, "Min")
	local max = Gate.getAttribute(gate, "Max")
	nextCount = math.clamp(nextCount, min, max)

	gate.LastStates.CountDown = isDownActive
	gate.LastStates.CountUp = isUpActive
	gate.LastStates.Reset = isResetActive

	return nextCount
end

return CounterClass