-- Requires and services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

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

local DisplayClass = {}
DisplayClass.__index = DisplayClass
setmetatable(DisplayClass, GateClass)

DisplayClass.name = "DISPLAY"
DisplayClass.inputs = { "Input" }
DisplayClass.output = nil

function DisplayClass.new(id: number, ownerId: number, gateModel: Types.TGateModel): TGate
	local gate = setmetatable(GateClass.CreateGate(id, ownerId, gateModel), DisplayClass) :: TGate

	gate.Class = DisplayClass

	-- Set nodes
	gate.Inputs = { ["Input"] = {} }

	gate.TextLabel = gate.Model.Decoration.Screen.SurfaceGui.TextLabel
	
	return gate
end

function DisplayClass.Update(gate: TGate): TSignal
	local finalValue = Gate.getStringInput(gate.Inputs.Input)

	if gate.TextLabel then gate.TextLabel.Text = if finalValue == "false" then "" else finalValue end

	return false
end

return DisplayClass
