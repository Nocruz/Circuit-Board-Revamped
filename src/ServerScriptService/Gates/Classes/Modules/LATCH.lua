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

local LatchClass = {} :: TGateClass
LatchClass.__index = LatchClass
setmetatable(LatchClass, GateClass)

LatchClass.name = "LATCH"
LatchClass.inputs = { "Input", "Bridge" }
LatchClass.output = "Output"

function LatchClass.new(id: number, ownerId: number, gateModel: Types.TGateModel): TGate
	local gate = setmetatable(GateClass.CreateGate(id, ownerId, gateModel), LatchClass) :: TGate

	gate.Class = LatchClass
	
	-- Set nodes
	gate.Inputs = { ["Input"] = {}, ["Bridge"] = {}}
	gate.Output = false
	gate.Connections = {}
	
	gate.StoredValue = false

	return gate
end

function LatchClass.Update(gate: TGate): TSignal
	if Gate.getBooleanInput(gate.Inputs.Bridge) then
		local inputSignal = Gate.getSignalInput(gate.Inputs.Input)

		gate.StoredValue = inputSignal
		return inputSignal
	end

	return gate.StoredValue
end

return LatchClass
