--[[ WIRE TOOL
		Point to a gate's node to start a connection using this node.
		Click again another node to connect both.
		
		Signals will travel from Output nodes to Input nodes.
		Unequip to cancel.
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalServices = StarterPlayer.StarterPlayerScripts.Services
local PointerService = require(LocalServices.PointerService)
local MessageService = require(LocalServices.MessageService)

-- References
local pointerBallPrefab = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("PointerBall")
local wirePrefab = ReplicatedStorage:WaitForChild("Wire")

-- Events
local permissionQuery: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Queries"):WaitForChild("Permission", 1)
local connectEvent: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("Connect", 1)

-- State definition
local State = {}
State.__index = State

-- ----------------------------- ----------- HELPER FUNCTIONS ------------ -----------------------------

function State:SetNodeLabels(value: boolean)
	if value and not self.IsEquipped or not self.HoveredGate then return end
	
	local nodes = self.HoveredGate:FindFirstChild("Nodes")
	local inputs = nodes:FindFirstChild("Inputs")
	local outputs = nodes:FindFirstChild("Outputs")
	if not inputs or not outputs then warn("No Inputs / Outputs in gate!"); return end
	
	for _, node in ipairs(inputs:GetChildren()) do
		local billboardGui = node:FindFirstChildWhichIsA("BillboardGui")
		if billboardGui then billboardGui.Enabled = value end
	end
	
	for _, node in ipairs(outputs:GetChildren()) do
		local billboardGui = node:FindFirstChildWhichIsA("BillboardGui")
		if billboardGui then billboardGui.Enabled = value end
	end
end

function State:CreatePointer()
	if not self.IsEquipped then return end
	
	self.PointerBall = pointerBallPrefab:Clone()
	self.PointerBall.Parent = Workspace
	
	self.PointerMoveConnection = RunService.RenderStepped:Connect(function()
		local hit, node, gate = PointerService.HitPosition, PointerService.HoveredNode, PointerService.HoveredGate
		
		if hit == nil and (not node or not node.Parent) then
			if self.PointerBall then self.PointerBall.Parent = nil end
			return
		end
		
		if self.PointerBall then
			self.PointerBall.Parent = Workspace
			self.PointerBall.Position = if (node and node.Parent and gate:GetAttribute("OwnerID") ~= 0) then node.Position else hit
		end
	end)
end

function State:DestroyPointer()
	if self.PointerBall then
		self.PointerBall:Destroy()
		self.PointerBall = nil
	end
	
	if self.PointerMoveConnection then
		self.PointerMoveConnection:Disconnect()
		self.PointerMoveConnection = nil
	end
end

function State:CreateWire()
	if not self.IsEquipped or not self.StartNode or not self.StartNode.Parent or not self.PointerBall then return end
	
	local startAttachment = self.StartNode:FindFirstChild("WireAttachment")
	local endAttachment = self.PointerBall:FindFirstChild("WireAttachment")
	if not startAttachment or not endAttachment then return end
	
	self.Wire = wirePrefab:Clone()
	self.Wire.Attachment0 = startAttachment
	self.Wire.Attachment1 = endAttachment
	self.Wire.Parent = self.StartNode
end

function State:DestroyWire()
	if self.Wire then
		self.Wire:Destroy()
		self.Wire = nil
	end
end

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new(player: Player)
	local self = setmetatable({}, State)
	self.Player = player
	
	self.LabelsConnection = nil
	
	self.HoveredGate = nil
	self.StartGate = nil
	self.StartNode = nil
	
	self.Wire = nil
	
	self.PointerBall = nil
	self.PointerMoveConnection = nil
	
	self.Active = false
	self.IsEquipped = true
	
	return self
end

function State:Enter()
	self:CreatePointer()
	
	self.HoveredGate = PointerService.HoveredGate
	if self.HoveredGate ~= nil and self.HoveredGate:GetAttribute("OwnerID") == 0 then self.HoveredGate = nil end
	if self.HoveredGate then self:SetNodeLabels(true) end
	self.LabelsConnection = PointerService.OnHoverChanged:Connect(function(_, gate, _)
		if self.HoveredGate and gate ~= self.HoveredGate then
			self:SetNodeLabels(false)
		end
		
		local isServerOwned = gate and gate:GetAttribute("OwnerID") == 0
		self.HoveredGate = if isServerOwned then nil else gate
		
		if gate ~= nil and not isServerOwned then self:SetNodeLabels(true) end
	end)
end

function State:Activated()
	if not self.IsEquipped then return end
	
	if self.Active then
		local gate, node = PointerService.HoveredGate, PointerService.HoveredNode
		if gate == nil or node == nil or not self.StartNode or not self.StartNode.Parent then return end
		
		local startType = self.StartNode:GetAttribute("NodeType")
		local endType = node:GetAttribute("NodeType")
		
		if startType == endType then
			MessageService.SendMessage("Can not connect two nodes of the same type!")
			return
		end
		
		local fromGate, toGate = nil, nil
		local fromNode, toNode = nil, nil
		if startType == "Input" then
			fromGate, toGate = gate, self.StartGate
			fromNode, toNode = node.Name, self.StartNode.Name
		else
			fromGate, toGate = self.StartGate, gate
			fromNode, toNode = self.StartNode.Name, node.Name
		end
		
		local fromGateID = fromGate and fromGate:GetAttribute("GateID")
		local toGateID = toGate and toGate:GetAttribute("GateID")
		if not fromGateID or not toGateID then return end
		
		self.StartGate = nil
		self.StartNode = nil
		self.Active = false
		
		local wire = self.Wire
		self.Wire = nil
		wire.Attachment1 = node:FindFirstChild("WireAttachment")
		
		task.spawn(function()
			local success, message = connectEvent:InvokeServer(fromGateID, toGateID, fromNode, toNode)
			if wire then wire:Destroy() end
			if not self.IsEquipped then return end
			
			if not success then MessageService.SendMessage(message) end
		end)
	
	else
		local gate = self.HoveredGate
		if gate == nil then return end
		
		local node = PointerService.HoveredNode
		if node == nil then return end

		local gateID = gate and gate:GetAttribute("GateID")
		if not gateID then return end
		
		self.StartGate = gate
		self.StartNode = node
		self:CreateWire()
		self.Active = true
		
		local currentStartNode = self.StartNode
		
		task.spawn(function()
			local success, message = permissionQuery:InvokeServer(gateID, "Wire")
			if not self.IsEquipped then return end
			
			if self.StartNode == currentStartNode and not success then
				MessageService.SendMessage(message)
				
				self.StartGate = nil
				self.StartNode = nil
				self:DestroyWire()
				self.Active = false
			end
		end)
	
	end
end

function State:Deactivated()
end

function State:Exit()
	if not self.IsEquipped then return end
	self.IsEquipped = false
	
	self:DestroyPointer()
	self:DestroyWire()
	
	if self.HoveredGate then
		self:SetNodeLabels(false)
		self.HoveredGate = nil
	end
	
	if self.LabelsConnection then
		self.LabelsConnection:Disconnect()
		self.LabelsConnection = nil
	end
	
	table.clear(self)
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
