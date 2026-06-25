--[[ CONNECTIONS
		Owns wire visual creation, destruction, and hitbox updates.
		Handles connections between gates.
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- References
local wiresFolder = Workspace:FindFirstChild("Wires")
if not (wiresFolder and wiresFolder:IsA("Folder")) then
	wiresFolder = Instance.new("Folder")
	wiresFolder.Name = "Wires"
	wiresFolder.Parent = Workspace
end

local wirePrefab = ReplicatedStorage.Wire
assert(wirePrefab, "No wire prefab!")

-- Module
local Connections = {}

-- ----------------------------- ---------- HANDLER DEFINITIONS ---------- -----------------------------

-- { [fromGateID]: { [fromOutputNodeName]: { [toGateID]: { [toInputNodeName]: wire } } } }
local outgoing = {}
local incoming = {}

-- ----------------------------- ---------------- HELPERS ---------------- -----------------------------

local function updateHitbox(wire: Beam & { Hitbox: BasePart })
	if wire == nil or wire.Attachment0 == nil or wire.Attachment1 == nil then return end
	
	local fromPosition = wire.Attachment0.WorldPosition
	local toPosition = wire.Attachment1.WorldPosition
	local length = (toPosition - fromPosition).Magnitude
	
	local newSize, newCFrame = Vector3.new(0.2, 0.2, length), CFrame.lookAt(fromPosition, toPosition) * CFrame.new(0, 0, -length / 2)
	wire.Hitbox.Size = newSize
	wire.Hitbox.CFrame = newCFrame
end

-- ----------------------------- ----------- MODULE DEFINITION ----------- -----------------------------

function Connections.new(fromID: number, toID: number, fromNode: BasePart, toNode: BasePart)
	local fromAttachment, toAttachment = fromNode:FindFirstChildWhichIsA("Attachment"), toNode:FindFirstChildWhichIsA("Attachment")
	assert(fromAttachment, "Node " .. fromNode.Name .. " has no attachment for wires")
	assert(toAttachment, "Node " .. toNode.Name .. " has no attachment for wires")
	
	local wire = wirePrefab:Clone()
	wire.Attachment0 = fromAttachment
	wire.Attachment1 = toAttachment
	wire.Parent = wiresFolder
	
	wire:SetAttribute("FromGate", fromID)
	wire:SetAttribute("ToGate", toID)
	wire:SetAttribute("FromNode", fromNode.Name)
	wire:SetAttribute("ToNode", toNode.Name)
	
	outgoing[fromID] = outgoing[fromID] or {}
	outgoing[fromID][fromNode.Name] = outgoing[fromID][fromNode.Name] or {}
	outgoing[fromID][fromNode.Name][toID] = outgoing[fromID][fromNode.Name][toID] or {}
	outgoing[fromID][fromNode.Name][toID][toNode.Name] = wire
	
	incoming[toID] = incoming[toID] or {}
	incoming[toID][toNode.Name] = incoming[toID][toNode.Name] or {}
	incoming[toID][toNode.Name][fromID] = incoming[toID][toNode.Name][fromID] or {}
	incoming[toID][toNode.Name][fromID][fromNode.Name] = wire
	
	updateHitbox(wire)
	return wire
end

function Connections.Destroy(fromID, toID, fromNode, toNode)
	local wire = Connections.Get(fromID, toID, fromNode, toNode)
	if not wire then return end
	
	wire:Destroy()
	
	outgoing[fromID][fromNode][toID][toNode] = nil
	if next(outgoing[fromID][fromNode][toID]) == nil then
		outgoing[fromID][fromNode][toID] = nil
		if next(outgoing[fromID][fromNode]) == nil then
			outgoing[fromID][fromNode] = nil
			if next(outgoing[fromID]) == nil then
				outgoing[fromID] = nil
			end
		end
	end
	
	incoming[toID][toNode][fromID][fromNode] = nil
	if next(incoming[toID][toNode][fromID]) == nil then
		incoming[toID][toNode][fromID] = nil
		if next(incoming[toID][toNode]) == nil then
			incoming[toID][toNode] = nil
			if next(incoming[toID]) == nil then
				incoming[toID] = nil
			end
		end
	end
end

function Connections.DestroyAll(gateID)
	local connections = {}
	local affected = {}
	
	-- Gets all connections
	for fromNode, layer1 in pairs(outgoing[gateID] or {}) do
		for toGate, layer2 in pairs(layer1) do
			table.insert(affected, toGate)
			for toNode, wire in pairs(layer2) do
				table.insert(connections, {
					fromID = gateID,
					toID = toGate,
					fromNode = fromNode,
					toNode = toNode
				})
			end
		end
	end
	
	for toNode, layer1 in pairs(incoming[gateID] or {}) do
		for fromGate, layer2 in pairs(layer1) do
			for fromNode, wire in pairs(layer2) do
				table.insert(connections, {
					fromID = fromGate,
					toID = gateID,
					fromNode = fromNode,
					toNode = toNode
				})
			end
		end
	end
	
	-- Destroys all
	for _, connection in ipairs(connections) do
		Connections.Destroy(connection.fromID, connection.toID, connection.fromNode, connection.toNode)
	end
	
	return affected
end

function Connections.UpdateAllWireHitboxes(gateID)
	for toNode, layer1 in pairs(incoming[gateID] or {}) do
		for fromGate, layer2 in pairs(layer1) do
			for fromNode, wire in pairs(layer2) do
				updateHitbox(wire)
			end
		end
	end
	
	for fromNode, layer1 in pairs(outgoing[gateID] or {}) do
		for toGate, layer2 in pairs(layer1) do
			for toNode, wire in pairs(layer2) do
				updateHitbox(wire)
			end
		end
	end
end

-- ----------------------------- ---------------- QUERIES ---------------- -----------------------------

function Connections.Get(fromGate: number, toGate: number, fromNode: string, toNode: string): Instance?
	return if outgoing[fromGate] and
						outgoing[fromGate][fromNode] and
						outgoing[fromGate][fromNode][toGate]
	then outgoing[fromGate][fromNode][toGate][toNode]
	else nil
end

function Connections.GetAllOutgoing(fromGate: number, fromNode: string)
	return if outgoing[fromGate] and
						outgoing[fromGate][fromNode]
	then outgoing[fromGate][fromNode]
	else {}
end

function Connections.GetAllIncoming(toGate: number, toNode: string)
	return if incoming[toGate] and
						incoming[toGate][toNode]
	then incoming[toGate][toNode]
	else {}
end

-- ----------------------------- --------------- DEBUGGIN ---------------- -----------------------------

function Connections.Debug(gateID: number)
	print("Debugging gate " .. gateID .. " connections:")
	print("\tOutgoing:")
	for outputNode, gateConnections in pairs(outgoing[gateID] or {}) do
		print("\t\tNode \"" .. outputNode .. "\"")
		for gate, nodeConnections in pairs(gateConnections) do
			print("\t\t\tGate " .. gate)
			for nodeName, wireInstance in pairs(nodeConnections) do
				print("\t\t\t\tNode \"" .. nodeName .. "\"")
			end
		end
	end
	print("\tIncoming:")
	for inputNode, gateConnections in pairs(incoming[gateID] or {}) do
		print("\t\tNode \"" .. inputNode .. "\"")
		for gate, nodeConnections in pairs(gateConnections) do
			print("\t\t\tGate " .. gate)
			for nodeName, wireInstance in pairs(nodeConnections) do
				print("\t\t\t\tNode \"" .. nodeName .. "\"")
			end
		end
	end
end
-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Connections
