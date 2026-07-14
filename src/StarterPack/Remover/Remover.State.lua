--[[ REMOVER TOOL
		Click a gate to destroy it.
		
		Drag the cursor to form a bounding box.
		Use the bounding box to delete circuits.
]]

-- Requires and services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local MessageService = require(StarterPlayer.StarterPlayerScripts.Services.MessageService)
local PointerService = require(StarterPlayer.StarterPlayerScripts.Services.PointerService)

-- References
local highlightPrefab: SelectionBox = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("PliersHighlight")
local serverGatesFolder = Workspace:WaitForChild("Gates"):WaitForChild("Server")

-- Events
local destroyEvent: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("Destroy")

-- State definition
local State = {}
State.__index = State

-- ----------------------------- ------------ HELPER METHODS ------------- -----------------------------

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

function State:UpdateHighlights(instance: Instance?, gate: Model?)
	if not self.IsEquipped then return end
	
	if not gate or not gate.Parent then
		self:ResetHighlight()
	elseif self.SelectedGate ~= gate then
		self:ResetHighlight()
		self:SetHighlight(gate)
	end
end

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new()
	local self = setmetatable({}, State)
	
	self.HoverConnection = nil
	
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
end

function State:Activated()
	if not self.IsEquipped then return end
	if not self.SelectedGate or not self.SelectedGate.Parent then return end
	
	local gateID = self.SelectedGate:GetAttribute("GateID")
	if not gateID then return end
	local success, message = destroyEvent:InvokeServer(gateID)
	if not self.IsEquipped then return end
	if not success then MessageService.SendMessage(message)
	else self:ResetHighlight() end
end

function State:Deactivated()
end

function State:Exit()
	if not self.IsEquipped then return end
	self.IsEquipped = false
	
	self:ResetHighlight()
	
	if self.SelectedGateHighlight then
		self.SelectedGateHighlight:Destroy()
		self.SelectedGateHighlight = nil
	end
	table.clear(self)
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
