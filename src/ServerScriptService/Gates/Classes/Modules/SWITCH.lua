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

local SwitchClass = {}
SwitchClass.__index = SwitchClass
setmetatable(SwitchClass, GateClass)

SwitchClass.name = "SWITCH"
SwitchClass.inputs = { "Input" }
SwitchClass.output = "Output"

function SwitchClass.new(id: number, ownerId: number, gateModel: Types.TGateModel): TGate
	local gate = setmetatable(GateClass.new(id, ownerId, gateModel), SwitchClass) :: TGate

	gate.Class = SwitchClass

	-- Set nodes
	gate.Inputs = { ["Input"] = {} }
	gate.Output = false
	gate.Connections = {}

	gate.OriginalColor = gate.Model.Decoration.Main.Color
	gate.State = false
	gate.LastInputState = false

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.Parent = gate.Model
	clickDetector.MouseClick:Connect(function(player) SwitchClass.toggle(gate, player) end)

	return gate
end

function SwitchClass.toggle(gate: TGate, player: Player)
	if player and not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Interact") then return end
	
	gate.State = not gate.State

	local main: BasePart = gate.Model.Decoration.Main
	if gate.State then
		main.Color = Color3.fromRGB(255, 208, 99)
		main.Position = main.Position - Vector3.new(0, 0.2, 0)
	else
		main.Color = gate.OriginalColor
		main.Position = main.Position + Vector3.new(0, 0.2, 0)
	end
	
	UpdateService.propagate(gate)
end

function SwitchClass.Update(gate: TGate): TSignal
	local currentInput = Gate.getBooleanInput(gate.Inputs.Input)

	if currentInput and not gate.LastInputState then
		gate.toggle(gate, nil)
	end

	gate.LastInputState = currentInput

	return gate.State
end

return SwitchClass