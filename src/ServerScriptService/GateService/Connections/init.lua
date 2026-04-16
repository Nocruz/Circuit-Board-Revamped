--[[ CONNECTIONS
		Owns wire visual creation, destruction, and hitbox updates.
		Handles connections between gates
]]

-- Requires
local Signals = require(script.Parent.Signals)

-- API
local Connections = {}

-- References
local WiresFolder = workspace:FindFirstChild("Wires")
if not (WiresFolder and WiresFolder:IsA("Folder")) then
	WiresFolder = Instance.new("Folder")
	WiresFolder.Name = "Wires"
	WiresFolder.Parent = workspace
end
local WirePrefab: TWire = script.Wire

-- Constants
local COLOR_ON = Color3.new(0.9, 0.9, 1)
local COLOR_OFF = Color3.new(0, 0, 0.1)

-- ----------------------------- ----------- TYPE DEFINITIONS ------------ ----------------------------

export type TWire = Beam & { Hitbox: BasePart }

-- ----------------------------- --------- REGISTRY DEFINITION --------- ---------------------------

local Wires = {}
local Outgoing = {}
local Incoming = {}

-- ----------------------------- --------------- HELPERS ----------------- ----------------------------

local function GetHitboxTraslation(attachment0: Attachment, attachment1: Attachment): (Vector3, CFrame)
	local fromPosition = attachment0.WorldPosition
	local toPosition = attachment1.WorldPosition
	local length = (toPosition - fromPosition).Magnitude
	
	return Vector3.new(0.2, 0.2, length), CFrame.lookAt(fromPosition, toPosition) * CFrame.new(0, 0, -length / 2)
end

-- ----------------------------- -------------- LIFECYCLE ---------------- ----------------------------

function Connections.new(fromID: number, toID: number, fromNode: BasePart, toNode: BasePart): TWire
	local fromAttachment, toAttachment = fromNode:FindFirstChildWhichIsA("Attachment"), toNode:FindFirstChildWhichIsA("Attachment")	
	assert(fromAttachment, "Node " .. fromNode.Name .. " had no attachment for wires")
	assert(toAttachment, "Node " .. toNode.Name .. " had no attachment for wires")
	
	local wire: TWire  = WirePrefab:Clone()
	wire.Attachment0 = fromAttachment
	wire.Attachment1 = toAttachment
	wire.Parent = WiresFolder
	
	wire:SetAttribute("FromGate", fromID)
	wire:SetAttribute("ToGate", toID)
	wire:SetAttribute("FromNode", fromNode.Name)
	wire:SetAttribute("ToNode", toNode.Name)
	
	Wires[wire] = {
		fromID = fromID,
		toID = toID,
		fromNode = fromNode.Name,
		toNode = toNode.Name
	}
	
	Outgoing[fromID] = Outgoing[fromID] or {}
	Outgoing[fromID][fromNode.Name] = Outgoing[fromID][fromNode.Name] or {}
	table.insert(Outgoing[fromID][fromNode.Name], wire)
	
	Incoming[toID] = Incoming[toID] or {}
	Incoming[toID][toNode.Name] = Incoming[toID][toNode.Name] or {}
	table.insert(Incoming[toID][toNode.Name], wire)
	
	return wire
end

function Connections.Destroy(wire: TWire)
	local data = Wires[wire]
	if not data then return end
	
	-- Remove from Outgoing
	local outList = Outgoing[data.fromID][data.fromNode]
	for i, w in ipairs(outList) do
		if w == wire then
			table.remove(outList, i)
			break
		end
	end
	
	-- Remove from Incoming
	local inList = Incoming[data.toID][data.toNode]
	for i, w in ipairs(inList) do
		if w == wire then
			table.remove(inList, i)
			break
		end
	end
	
	Wires[wire] = nil
	wire:Destroy()
end

-- ----------------------------- ---------------- MODEL ------------------ ----------------------------

function Connections.UpdateCFrame(wire: TWire)
	assert(wire and wire.Attachment0 and wire.Attachment1, "Invalid wire instance")
	wire.Hitbox.Size, wire.Hitbox.CFrame = GetHitboxTraslation(wire.Attachment0, wire.Attachment1)
end

function Connections.UpdateColor(wire: TWire, signal: Signals.TSignal)
	local isOn = Signals.toBoolean(signal)
	wire.Color = ColorSequence.new(if isOn then COLOR_ON else COLOR_OFF)
end

-- ----------------------------- --------------- UTILITY ----------------- ----------------------------

function Connections.GetOutgoing(gateID, outputName)
	return if Outgoing[gateID] and Outgoing[gateID][outputName] then
		Outgoing[gateID][outputName]
		else {}
end

function Connections.GetIncoming(gateID, outputName)
	return if Incoming[gateID] and Incoming[gateID][outputName] then
		Incoming[gateID][outputName]
		else {}
end
-- ----------------------------- ------------ END OF MODULE -------------- ----------------------------

return Connections
