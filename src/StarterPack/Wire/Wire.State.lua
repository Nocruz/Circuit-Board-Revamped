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
	local nodes = self.HoveredGate:FindFirstChild("Nodes")
	local inputs = nodes:FindFirstChild("Inputs")
	local outputs = nodes:FindFirstChild("Outputs")
	
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
	self.PointerBall = pointerBallPrefab:Clone()
	self.PointerBall.Parent = Workspace
	
	self.PointerMoveConnection = RunService.RenderStepped:Connect(function()
		local hit, node = PointerService.HitPosition, PointerService.HoveredNode
		
		if hit == nil then
			self.PointerBall.Parent = nil
		end
		
		if hit ~= nil or node ~= nil then
			self.PointerBall.Parent = Workspace
			self.PointerBall.Position = if node then node.Position else hit
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
	self.Wire = wirePrefab:Clone()
	self.Wire.Parent = self.StartNode
	self.Wire.Attachment0 = self.StartNode.WireAttachment
	self.Wire.Attachment1 = self.PointerBall.WireAttachment
end

function State:DestroyWire()
	if self.Wire then
		self.Wire:Destroy()
		self.Wire = nil
	end
end

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new(player: Player, character: Model)
	local self = setmetatable({}, State)
	self.Player = player
	
	self.LabelsConnection = nil
	
	self.HoveredGate = nil
	self.StartGate = nil
	self.StartNode = nil
	
	self.Active = false
	
	return self
end

function State:Enter()
	self:CreatePointer()
	
	self.HoveredGate = PointerService.HoveredGate
	if self.HoveredGate then self:SetNodeLabels(true) end
	self.LabelsConnection = PointerService.OnHoverChanged:Connect(function(_, gate, _)
		if self.HoveredGate and gate ~= self.HoveredGate then
			self:SetNodeLabels(false)
			self.HoveredGate = gate
		end
		
		self.HoveredGate = gate
		
		if gate then
			self:SetNodeLabels(true)
		end
	end)
end

function State:Activated()
	if self.Active then
		local gate, node = PointerService.HoveredGate, PointerService.HoveredNode
		if gate == nil or node == nil then return end
		
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
		
		local success, message = connectEvent:InvokeServer(fromGate:GetAttribute("GateID"), toGate:GetAttribute("GateID"), fromNode, toNode)
		if not success then
			MessageService.SendMessage(message)
			return
		end
		
		self.StartGate = nil
		self.StartNode = nil
		
		self:DestroyWire()
		
		self.Active = false
	else
		local gate, node = PointerService.HoveredGate, PointerService.HoveredNode
		if gate == nil or node == nil then return end
		
		local success, message = permissionQuery:InvokeServer(gate:GetAttribute("GateID"), "Wire")
		if not success then
			MessageService.SendMessage(message)
			return
		end
		
		self.StartGate = gate
		self.StartNode = node
		
		self:CreateWire()
		
		self.Active = true
	end
end

function State:Deactivated()
end

function State:Exit()
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
