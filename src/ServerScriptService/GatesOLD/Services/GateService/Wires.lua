--!strict
--[[ GATE SERVICE WIRES
		Owns wire visual creation, destruction, and hitbox updates.
]]

local SignalService = require(script.Parent.Parent.SignalService)

local Wires = {}

local COLOR_OFF = Color3.fromRGB(120, 120, 120)
local COLOR_ON = Color3.fromRGB(255, 221, 84)

-- ----------------------------- ------------ HELPERS ------------------- -----------------------------

local function getNodeAttachment(model: Model, nodeName: string): Attachment
	local nodes = model:FindFirstChild("Nodes")
	assert(nodes and nodes:IsA("Folder"), "Gate model had no Nodes folder")

	local node = nodes:FindFirstChild(nodeName)
	assert(node and node:IsA("BasePart"), "Gate model had no node named '" .. nodeName .. "'")

	local attachment = node:FindFirstChildWhichIsA("Attachment")
	assert(attachment ~= nil, "Node '" .. nodeName .. "' had no attachment")
	return attachment
end

local function addWireLookup(state: any, gateId: number, wireId: number)
	state.WiresByGate[gateId] = state.WiresByGate[gateId] or {}
	state.WiresByGate[gateId][wireId] = true
end

local function removeWireLookup(state: any, gateId: number, wireId: number)
	local gateWires = state.WiresByGate[gateId]
	if gateWires == nil then
		return
	end

	gateWires[wireId] = nil
	if next(gateWires) == nil then
		state.WiresByGate[gateId] = nil
	end
end

local function setWireMetadata(instance: Instance, wire: any)
	instance:SetAttribute("WireId", wire.Id)
	instance:SetAttribute("FromGateId", wire.FromGateId)
	instance:SetAttribute("ToGateId", wire.ToGateId)
	instance:SetAttribute("InputName", wire.InputName)
end

-- ----------------------------- ------------ VISUALS ------------------- -----------------------------

function Wires.ApplyState(wire: any, isActive: boolean)
	wire.Beam.Color = ColorSequence.new(if isActive then COLOR_ON else COLOR_OFF)
	wire.Beam.LightEmission = if isActive then 1 else 0
end

function Wires.UpdateHitbox(state: any, wireId: number)
	local wire = state.WiresById[wireId]
	if wire == nil then
		return
	end

	local attachment0 = wire.Beam.Attachment0
	local attachment1 = wire.Beam.Attachment1
	if attachment0 == nil or attachment1 == nil then
		return
	end

	local fromPosition = attachment0.WorldPosition
	local toPosition = attachment1.WorldPosition
	local length = math.max((toPosition - fromPosition).Magnitude, 0.2)

	wire.Hitbox.Size = Vector3.new(0.2, 0.2, length)
	wire.Hitbox.CFrame = CFrame.lookAt(fromPosition, toPosition) * CFrame.new(0, 0, -length / 2)
end

function Wires.EnqueueColour(state: any, gateId: number, value: any)
	state.WireColourQueue[gateId] = SignalService.toBoolean(value)
end

function Wires.FlushColours(state: any)
	for gateId, value in pairs(state.WireColourQueue) do
		local gateWires = state.WiresByGate[gateId]
		if gateWires ~= nil then
			for wireId in pairs(gateWires) do
				local wire = state.WiresById[wireId]
				if wire ~= nil and wire.FromGateId == gateId then
					Wires.ApplyState(wire, value)
				end
			end
		end
	end

	table.clear(state.WireColourQueue)
end

-- ----------------------------- ------------- LIFECYCLE ------------- -----------------------------

function Wires.Create(state: any, fromGate: any, toGate: any, inputName: string): number
	state.NextWireId += 1
	local wireId = state.NextWireId

	local container = Instance.new("Model")
	container.Name = string.format("Wire_%d", wireId)
	container.Parent = state.WiresRoot

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
	beam.Attachment0 = getNodeAttachment(fromGate.Model, "Output")
	beam.Attachment1 = getNodeAttachment(toGate.Model, inputName)
	beam.Parent = container

	local wire = {
		Id = wireId,
		FromGateId = fromGate.Id,
		ToGateId = toGate.Id,
		InputName = inputName,
		Container = container,
		Beam = beam,
		Hitbox = hitbox,
	}

	setWireMetadata(container, wire)
	setWireMetadata(hitbox, wire)
	setWireMetadata(beam, wire)

	state.WiresById[wireId] = wire
	addWireLookup(state, fromGate.Id, wireId)
	addWireLookup(state, toGate.Id, wireId)

	Wires.ApplyState(wire, SignalService.toBoolean(fromGate.Output or false))
	Wires.UpdateHitbox(state, wireId)

	return wireId
end

function Wires.Destroy(state: any, wireId: number)
	local wire = state.WiresById[wireId]
	if wire == nil then
		return
	end

	state.WiresById[wireId] = nil
	removeWireLookup(state, wire.FromGateId, wireId)
	removeWireLookup(state, wire.ToGateId, wireId)
	wire.Container:Destroy()
end

return Wires
