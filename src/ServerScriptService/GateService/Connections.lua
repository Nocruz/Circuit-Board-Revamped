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
	wiresFolder.Parent = workspace
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

local function GetHitboxTraslation(attachment0: Attachment, attachment1: Attachment): (Vector3, CFrame)
	local fromPosition = attachment0.WorldPosition
	local toPosition = attachment1.WorldPosition
	local length = (toPosition - fromPosition).Magnitude
	
	return Vector3.new(0.2, 0.2, length), CFrame.lookAt(fromPosition, toPosition) * CFrame.new(0, 0, -length / 2)
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
	
	return wire
end

-- ----------------------------- ---------------- QUERIES ---------------- -----------------------------

function Connections.Get(fromGate: number, toGate: number, fromNode: string, toNode: string): Instance?
	return if outgoing[fromGate] and
						outgoing[fromGate][fromNode] and
						outgoing[fromGate][fromNode][toGate]
	then outgoing[fromGate][fromNode][toGate][toNode]
	else nil
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
