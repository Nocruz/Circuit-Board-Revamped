--[[ DELAY CLASS
		Rules:
		- Input FALSE: OFF immediately (Signal).
		- Output TRUE: Follows input immediately (Signal).
		- Input TRUE (while Output is FALSE): Wait DelayAttribute seconds (Schedule).
]]

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

local DelayClass = {}
DelayClass.__index = DelayClass
setmetatable(DelayClass, GateClass)

DelayClass.name = "DELAY"
DelayClass.inputs = { "Input" }
DelayClass.output = "Output"

DelayClass.validAttributes = { ["Delay"] = AttributeService.new(0.5, {}, {function(value) return value >= 0 end }) }

function DelayClass.new(id: number, ownerId: number, gateModel: Types.TGateModel): TGate
	local gate = setmetatable(GateClass.new(id, ownerId, gateModel), DelayClass) :: TGate

	gate.Class = DelayClass
	
	gate.Attributes = { ["Delay"] = DelayClass.validAttributes["Delay"].Default }
	
	-- Set nodes
	gate.Inputs = { ["Input"] = {} }
	gate.Output = false
	gate.Connections = {}

	return gate
end

function DelayClass.Update(gate: TGate, origin: "Signal" | "Schedule"): TSignal
	local inputSignal = Gate.getSignalInput(gate.Inputs.Input)
	local inputActive = SignalService.toBoolean(inputSignal)
	local delayTime = Gate.getAttribute(gate, "Delay") :: number

	if origin == "Signal" then
		if not inputActive then
			UpdateService.cancel(gate)
			return false
		end
		
		-- Changes in input restart delay
		if inputActive and not SignalService.toBoolean(gate.Output) then
			UpdateService.schedule(gate, delayTime)
			return false
		end

		return inputSignal
	end

	if origin == "Schedule" then
		if inputActive then
			return inputSignal
		end
	end

	return gate.Output
end

return DelayClass