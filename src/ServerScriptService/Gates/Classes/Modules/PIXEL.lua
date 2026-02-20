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

local PixelClass = {}
PixelClass.__index = PixelClass
setmetatable(PixelClass, GateClass)

PixelClass.name = "PIXEL"
PixelClass.inputs = { "R", "G", "B" }
PixelClass.output = nil

function PixelClass.new(id: number, ownerId: number, gateModel: Types.TGateModel): TGate
	local gate = setmetatable(GateClass.new(id, ownerId, gateModel), PixelClass) :: TGate

	gate.Class = PixelClass

	-- Set nodes
	gate.Inputs = { ["R"] = {}, ["G"] = {}, ["B"] = {} }

	gate.Screen = gate.Model.Decoration.Screen
	
	return gate
end

function PixelClass.Update(gate: TGate): TSignal
	local finalColor = Color3.new(Gate.getNumericInput(gate.Inputs.R), Gate.getNumericInput(gate.Inputs.G), Gate.getNumericInput(gate.Inputs.B))
	
	if gate.Screen then gate.Screen.Color = finalColor end

	return false
end

return PixelClass