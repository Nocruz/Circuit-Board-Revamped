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

local ButtonClass = {} :: TGateClass
ButtonClass.__index = ButtonClass
setmetatable(ButtonClass, GateClass)

ButtonClass.name = "BUTTON"
ButtonClass.inputs = {}
ButtonClass.output = "Output"

ButtonClass.validAttributes = {
	["Duration"] = AttributeService.new(0.5, {}, { function(value) return value >= 0 end })
}

local PRESSED_COLOR = Color3.fromRGB(255, 245, 112)

function ButtonClass.new(id: number, ownerId: number, gateModel: Types.TGateModel): TGate
	local gate = setmetatable(GateClass.CreateGate(id, ownerId, gateModel), ButtonClass) :: TGate

	gate.Class = ButtonClass
	
	-- Set nodes
	gate.Inputs = {}
	gate.Output = false
	gate.Connections = {}
	
	gate.Attributes = { 
		["Duration"] = AttributeService.getDefault(ButtonClass.validAttributes["Duration"])
	}
	
	gate.State = false
	gate.OriginalColor = gate.Model.Decoration.Main.Color
	local clickDetector = Instance.new("ClickDetector")
	clickDetector.Parent = gate.Model
	clickDetector.MouseClick:Connect(function(player) ButtonClass.onClicked(gate, player) end)

	return gate
end

function ButtonClass.onClicked(gate: TGate, player: Player)
	if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Interact") then return end
	
	if gate.State == true then return end
	
	gate.State = true
	
	UpdateService.propagate(gate)
	
	local main: Part = gate.Model.Decoration.Main
	main.Color = PRESSED_COLOR
	main.Position = main.Position - Vector3.new(0, 0.2, 0)
	
	UpdateService.propagate(gate)
	
	UpdateService.schedule(gate, Gate.getAttribute(gate, "Duration"))
end

function ButtonClass.Update(gate: TGate, origin: "Signal" | "Schedule"): TSignal
	if origin == "Schedule" then
		gate.State = false
		
		local main: Part = gate.Model.Decoration.Main
		main.Color = gate.OriginalColor
		main.Position = main.Position + Vector3.new(0, 0.2, 0)
		
		return gate.State
	end
	
	return gate.State
end

return ButtonClass
