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

local LightClass = {}
LightClass.__index = LightClass
setmetatable(LightClass, GateClass)

LightClass.name = "LIGHT"
LightClass.inputs = { "R", "G", "B" }
LightClass.output = nil

function LightClass.new(id: number, ownerId: number, gateModel: Types.TGateModel): TGate
	local gate = setmetatable(GateClass.new(id, ownerId, gateModel), LightClass) :: TGate

	gate.Class = LightClass

	-- Set nodes
	gate.Inputs = { ["R"] = {}, ["G"] = {}, ["B"] = {} }

	gate.Top = gate.Model.Decoration.Top
	gate.Light = gate.Top.PointLight
	
	return gate
end

function LightClass.Update(gate: TGate): TSignal
	local finalColor = Color3.new(Gate.getNumericInput(gate.Inputs.R), Gate.getNumericInput(gate.Inputs.G), Gate.getNumericInput(gate.Inputs.B))
	
	if gate.Top then gate.Top.Color = finalColor end
	if gate.Light then 
		gate.Light.Color = finalColor
		gate.Light.Enabled = finalColor ~= Color3.new(0, 0, 0)
	end

	return false
end

return LightClass