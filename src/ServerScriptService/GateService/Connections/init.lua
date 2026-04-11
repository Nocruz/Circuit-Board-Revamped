--[[ CONNECTIONS
		Owns wire visual creation, destruction, and hitbox updates.
		Handles connections between gates
]]

-- Requires
local Signals = require(script.Parent.Signals)

-- API
local Connections = {}

-- Prefab
local WirePrefab: TWire = script.Wire

-- Constants
local COLOR_ON = Color3.new(0.9, 0.9, 1)
local COLOR_OFF = Color3.new(0, 0, 0.1)

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
	
	return wire
end

-- ----------------------------- ---------------- MODEL ------------------ ----------------------------

function Connections.UpdateCFrame(wire: TWire)
	assert(wire.Attachment0 and wire.Attachment1, "Invalid wire instance")
	wire.Hitbox.Size, wire.Hitbox.CFrame = GetHitboxTraslation(wire.Attachment0, wire.Attachment1)
end

function Connections.UpdateColor(wire: TWire, signal: Signals.TSignal)
	local on_off = Signals.toBoolean(signal)
	wire.Color = ColorSequence.new(if on_off then COLOR_ON else COLOR_OFF)
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Connections
