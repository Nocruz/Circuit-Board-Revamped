--!strict
--[[ WIRE SERVICE
		Manages visual representation of connections.
]]

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")

local SignalService = require(ServerScriptService.Gates.Services.SignalService)
local GateRegistry = require(ServerScriptService.Gates.Definitions.GateRegistry)

-- References
local WiresFolder = workspace:FindFirstChild("Wires")
if not (WiresFolder and WiresFolder:IsA("Folder")) then
	WiresFolder = Instance.new("Folder")
	WiresFolder.Name = "Wires"
	WiresFolder.Parent = workspace
end

-- Constants
local COLOR_OFF = Color3.fromRGB(120, 120, 120)
local COLOR_ON = Color3.fromRGB(255, 221, 84)

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- -----------------------------

type TWireContainer = Model & {
	Beam: Beam,
	WireHitbox: Part,
}

export type TWire = {
	id: number,
	from: number,
	to: number,
	node: string,
	container: TWireContainer,
	beam: Beam,
	hitbox: Part,
}

-- ----------------------------- --------- REGISTRY DEFINITION --------- ---------------------------

local LastID = 0
local WiresRegistry: { [number]: TWire } = {}
local GateWireMap: { [number]: { [number]: true } } = {}
local WireUpdateQueue: { [number]: boolean } = {}

local function nextId(): number
	LastID += 1
	return LastID
end

local function getNodeAttachment(model: Model, nodeName: string): Attachment
	local nodes = model:FindFirstChild("Nodes")
	assert(nodes and nodes:IsA("Folder"), "Gate model had no Nodes folder")

	local node = nodes:FindFirstChild(nodeName)
	assert(node and node:IsA("BasePart"), "Gate model had no node named '" .. nodeName .. "'")

	local attachment = node:FindFirstChildWhichIsA("Attachment")
	assert(attachment ~= nil, "Node '" .. nodeName .. "' had no attachment")
	return attachment
end

local function applyWireState(wire: TWire, isActive: boolean)
	wire.beam.Color = ColorSequence.new(if isActive then COLOR_ON else COLOR_OFF)
	wire.beam.LightEmission = if isActive then 1 else 0
end

local function updateHitbox(wire: TWire)
	local attachment0 = wire.beam.Attachment0
	local attachment1 = wire.beam.Attachment1
	if attachment0 == nil or attachment1 == nil then
		return
	end

	local fromPosition = attachment0.WorldPosition
	local toPosition = attachment1.WorldPosition
	local delta = toPosition - fromPosition
	local length = delta.Magnitude

	wire.hitbox.Size = Vector3.new(0.2, 0.2, math.max(length, 0.2))
	wire.hitbox.CFrame = CFrame.lookAt(fromPosition, toPosition) * CFrame.new(0, 0, -wire.hitbox.Size.Z / 2)
end

local function registerWire(wire: TWire)
	assert(WiresRegistry[wire.id] == nil, "Wire " .. wire.id .. " already exists")
	WiresRegistry[wire.id] = wire
	GateWireMap[wire.from] = GateWireMap[wire.from] or {}
	GateWireMap[wire.from][wire.id] = true
end

local function unregisterWire(wireId: number)
	local wire = WiresRegistry[wireId]
	if wire == nil then
		return
	end

	WiresRegistry[wireId] = nil

	local gateWires = GateWireMap[wire.from]
	if gateWires ~= nil then
		gateWires[wireId] = nil
		if next(gateWires) == nil then
			GateWireMap[wire.from] = nil
		end
	end
end

local function setWireMetadata(instance: Instance, wireId: number, fromId: number, toId: number, node: string)
	instance:SetAttribute("ID", wireId)
	instance:SetAttribute("In", fromId)
	instance:SetAttribute("Out", toId)
	instance:SetAttribute("Node", node)
end

-- ----------------------------- --------- WIRE INSTANTIATION ---------- ---------------------------

local WireService = {}

function WireService.CreateWire(fromId: number, toId: number, node: string): number
	local fromModel = GateRegistry.GetModel(fromId)
	local toModel = GateRegistry.GetModel(toId)
	assert(fromModel ~= nil, "From gate had no model")
	assert(toModel ~= nil, "To gate had no model")

	local wireId = nextId()

	local container = Instance.new("Model")
	container.Name = string.format("Wire_%d", wireId)
	container.Parent = WiresFolder

	local hitbox = Instance.new("Part")
	hitbox.Name = "WireHitbox"
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = true
	hitbox.CanTouch = false
	hitbox.Material = Enum.Material.SmoothPlastic
	hitbox.Transparency = 1
	hitbox.Parent = container

	local beam = Instance.new("Beam")
	beam.Name = "Beam"
	beam.LightInfluence = 0
	beam.Brightness = 1
	beam.Transparency = NumberSequence.new(0)
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Width0 = 0.3
	beam.Width1 = 0.3
	beam.Attachment0 = getNodeAttachment(fromModel, "Output")
	beam.Attachment1 = getNodeAttachment(toModel, node)
	beam.Parent = container

	setWireMetadata(container, wireId, fromId, toId, node)
	setWireMetadata(hitbox, wireId, fromId, toId, node)
	setWireMetadata(beam, wireId, fromId, toId, node)

	local wire: TWire = {
		id = wireId,
		from = fromId,
		to = toId,
		node = node,
		container = container :: TWireContainer,
		beam = beam,
		hitbox = hitbox,
	}

	applyWireState(wire, false)
	updateHitbox(wire)
	registerWire(wire)

	return wireId
end

function WireService.new(fromGate: GateRegistry.TGate, toGate: GateRegistry.TGate, node: string): number
	local wireId = WireService.CreateWire(fromGate.Id, toGate.Id, node)
	WireService.EnqueueUpdate(fromGate.Id, fromGate.Output or false)
	WireService.UpdateWireColours()
	return wireId
end

-- ----------------------------- ----------- WIRE DESTRUCTION ------------ ---------------------------

function WireService.DestroyWire(wireId: number)
	local wire = WiresRegistry[wireId]
	if wire == nil then
		return
	end

	wire.container:Destroy()
	unregisterWire(wireId)
end

function WireService.destroy(_: any, wireId: number)
	WireService.DestroyWire(wireId)
end

function WireService.CutWire(wireId: number)
	WireService.DestroyWire(wireId)
end

function WireService.CutAllWires(gateId: number)
	local gateWires = GateWireMap[gateId]
	if gateWires == nil then
		return
	end

	local wireIds = {}
	for wireId in pairs(gateWires) do
		table.insert(wireIds, wireId)
	end

	for _, wireId in ipairs(wireIds) do
		WireService.DestroyWire(wireId)
	end
end

-- ----------------------------- ------------- WIRE UPDATING ------------- ---------------------------

function WireService.UpdateBeamHitbox(beam: Beam)
	local wireId = beam:GetAttribute("ID")
	if type(wireId) ~= "number" then
		return
	end

	local wire = WiresRegistry[wireId]
	if wire then
		updateHitbox(wire)
	end
end

function WireService.UpdateWireHitbox(wireId: number)
	local wire = WiresRegistry[wireId]
	if wire then
		updateHitbox(wire)
	end
end

function WireService.EnqueueUpdate(gateId: number, value: SignalService.TSignal)
	WireUpdateQueue[gateId] = SignalService.toBoolean(value)
end

function WireService.UpdateWireColours()
	for gateId, value in pairs(WireUpdateQueue) do
		local gateWires = GateWireMap[gateId]
		if gateWires then
			for wireId in pairs(gateWires) do
				local wire = WiresRegistry[wireId]
				if wire then
					applyWireState(wire, value)
				end
			end
		end
	end

	table.clear(WireUpdateQueue)
end

return WireService
