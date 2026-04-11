--[[ CONNECTIONS
		Owns wire visual creation, destruction, and hitbox updates.
		Handles connections between gates
]]

local Connections = {}

-- Prefab
local WirePrefab: TWire = script.Wire

-- ----------------------------- ----------- TYPE DEFINITIONS ------------ ----------------------------

export type TWire = Beam & { Hitbox: BasePart }

-- ----------------------------- --------------- HELPERS ----------------- ----------------------------

local function GetHitboxTraslation(attachment0: Attachment, attachment1: Attachment): (Vector3, CFrame)
	local fromPosition = attachment0.WorldPosition
	local toPosition = attachment1.WorldPosition
	local length = (toPosition - fromPosition).Magnitude
	
	return Vector3.new(0.2, 0.2, length), CFrame.lookAt(fromPosition, toPosition) * CFrame.new(0, 0, -length / 2)
end

-- ----------------------------- -------------- LIFECYCLE ---------------- ----------------------------

function Connections.new(fromNode: BasePart, toNode: BasePart): TWire
	local fromAttachment, toAttachment = fromNode:FindFirstChildWhichIsA("Attachment"), toNode:FindFirstChildWhichIsA("Attachment")	
	assert(fromAttachment, "Node " .. fromNode.Name .. " had no attachment for wires")
	assert(toAttachment, "Node " .. toNode.Name .. " had no attachment for wires")
	
	local wire: TWire  = WirePrefab:Clone()
	wire.Attachment0 = fromAttachment
	wire.Attachment1 = toAttachment
	wire.Hitbox.Size, wire.Hitbox.CFrame = GetHitboxTraslation(fromAttachment, toAttachment)
	
	return wire
end

function Connections.UpdateCFrame(wire: TWire)
	assert(wire.Attachment0 and wire.Attachment1, "Invalid wire instance")
	wire.Hitbox.Size, wire.Hitbox.CFrame = GetHitboxTraslation(wire.Attachment0, wire.Attachment1)
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Connections
