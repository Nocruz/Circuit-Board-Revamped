--[[ PLIERS TOOL
		Tool used to cut wires that connect gates.
		Can also disconnect all Outgoing connections of a gate.
]]

-- Requires and services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local Workspace = game:GetService("Workspace")

local LocalServices = StarterPlayerScripts.Services
local PointerService = require(LocalServices.PointerService)
local MessageService = require(LocalServices.MessageService)

-- References
local serverGatesFolder = Workspace:WaitForChild("Gates"):WaitForChild("Server")
local wiresFolder = Workspace:WaitForChild("Wires")

-- Visuals
local highlightPrefab: SelectionBox = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("PliersHighlight")
local COLOR_SELECTED: ColorSequence = ColorSequence.new(Color3.new(1, 0, 0), Color3.new(1, 0, 0))

-- Events
local disconnectSingleEvent: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("DisconnectSingle")
local disconnectAllOutgoingEvent: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("DisconnectAllOutgoing")

-- State definition
local State = {}
State.__index = State

-- ----------------------------- --------- HELPER METHODS -------- ------------------------------

local function isWire(instance: Instance?): (boolean, Beam?)
	if instance and instance:IsA("Part") and instance.Name == "Hitbox" then
		local parent = instance.Parent
		if parent ~= nil and typeof(parent) == "Instance" and parent:IsA("Beam") then
			return true, parent
		end
	end
	return false, nil
end

function State:ResetHighlight()
	if self.SelectedGate and self.SelectedGateHighlight then
		self.SelectedGateHighlight.Adornee = nil
		self.SelectedGateHighlight.Parent = nil
		self.SelectedGate = nil
	end
end

function State:SetHighlight(gate: Instance)
	if not self.IsEquipped or not gate or not gate.Parent then return end
	if gate:IsDescendantOf(serverGatesFolder) then return end
	
	self.SelectedGate = gate
	self.SelectedGateHighlight.Adornee = gate
	self.SelectedGateHighlight.Parent = gate
end

function State:ResetWire()
	if self.SelectedWire and self.SelectedWire.Parent and self.SelectedWireColor then
		self.SelectedWire.Color = self.SelectedWireColor
		self.SelectedWireColor = nil
		self.SelectedWire = nil
	end
end

function State:SelectWire(wire: Beam)
	if not self.IsEquipped or not wire or not wire.Parent then return end
	
	self.SelectedWire = wire
	self.SelectedWireColor = wire.Color
	self.SelectedWire.Color = COLOR_SELECTED
end

function State:UpdateHighlights(instance: Instance?, gate: Model?)
	if not self.IsEquipped then return end
	
	local validWire, wireInstance = isWire(instance)
	
	if validWire and wireInstance then
		if self.SelectedWire ~= wireInstance then
			self:ResetHighlight()
			self:ResetWire()
			self:SelectWire(wireInstance)
		end
		return
	else
		self:ResetWire()
	end
	
	if not gate or not gate.Parent then
		self:ResetHighlight()
	elseif self.SelectedGate ~= gate then
		self:ResetHighlight()
		self:SetHighlight(gate)
	end
end

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new(player: Player)
	local self = setmetatable({}, State)
	self.Player = player
	
	self.HoverConnection = nil
	
	self.SelectedWire = nil
	self.SelectedWireColor = nil
	
	self.SelectedGate = nil
	self.SelectedGateHighlight = nil
	
	self.IsEquipped = true
	
	return self
end

function State:Enter()
	self.SelectedGateHighlight = highlightPrefab:Clone()
	
	self.HoverConnection = PointerService.OnHoverChanged:Connect(function(instance, gate)
		self:UpdateHighlights(instance, gate)
	end)
	
	self:UpdateHighlights(PointerService.HoveredInstance, PointerService.HoveredGate)
	PointerService.RemoveFromFilter(wiresFolder)
end

function State:Activated()
	if not self.IsEquipped then return end
	
	if self.SelectedWire and self.SelectedWire.Parent then
		local fromGate = self.SelectedWire:GetAttribute("FromGate")
		local fromNode = self.SelectedWire:GetAttribute("FromNode")
		local toGate = self.SelectedWire:GetAttribute("ToGate")
		local toNode = self.SelectedWire:GetAttribute("ToNode")
		
		if not fromGate or not toGate then return end
		
		local success, message = disconnectSingleEvent:InvokeServer(fromGate, toGate, fromNode, toNode)
		if not self.IsEquipped then return end
		
		if not success then MessageService.SendMessage(message) end
	
	elseif self.SelectedGate and self.SelectedGate.Parent then
		local gateID = self.SelectedGate:GetAttribute("GateID")
		if not gateID then return end
		
		local success, message = disconnectAllOutgoingEvent:InvokeServer(gateID)
		if not self.IsEquipped then return end
		
		if not success then MessageService.SendMessage(message) end
	end
end

function State:Deactivated()
end

function State:Exit()
	if not self.IsEquipped then return end
	self.IsEquipped = false
	
	self:ResetHighlight()
	self:ResetWire()
	
	if self.HoverConnection then
		self.HoverConnection:Disconnect()
		self.HoverConnection = nil
	end

	if self.SelectedGateHighlight then
		self.SelectedGateHighlight:Destroy()
		self.SelectedGateHighlight = nil
	end
	
	PointerService.AddToFilter(wiresFolder)
	table.clear(self)
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
