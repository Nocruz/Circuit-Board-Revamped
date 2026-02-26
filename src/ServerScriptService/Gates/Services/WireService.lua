--!strict
--[[ WIRE SERVICE
		Manages visual representation of connections (Beams).
		Throttles visual updates to prevent network/render saturation.
]]

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")

local SignalService = require(ServerScriptService.Gates.Services.SignalService)

local GateRegistry = require(ServerScriptService.Gates.Definitions.GateRegistry)
local GateModel = require(ServerScriptService.Gates.Definitions.GateModel)

-- References
local WiresFolder: Folder = Instance.new("Folder")
do
	WiresFolder.Name = "Wires"
	WiresFolder.Parent = workspace
end

-- Constants
local COLOR_ON = ColorSequence.new(Color3.new(1, 1, 1))
local COLOR_OFF = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0))

-- State
local LastID: number = 1

-- Module
local WireService = {}

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- -----------------------------

export type TWire = Beam & { Hitbox: Part }

-- ----------------------------- --------- REGISTRY DEFINITION --------- ---------------------------

local WiresRegistry: { [number]: { from: number, to: number, node: string, model: Beam } } = {}
local GateWireMap: { [number]: { [number]: true? } } = {}

local function RegisterWire(id: number, from: number, to: number, node: string, model: Beam)
	assert(WiresRegistry[id] == nil, "Wire of id " .. id .. " already exists")
	WiresRegistry[id] = { from = from, to = to, node = node, model = model }
	GateWireMap[from][id] = true
end

local function UnregisterWire(id: number)
	assert(WiresRegistry[id], "Wire of id " .. id .. " is not registered")
	local from = WiresRegistry[id].from
	assert(GateWireMap[from][id], "Wire of id " .. id .. " is not linked to Gate")
	WiresRegistry[id] = nil
	GateWireMap[from][id] = nil
end

-- ----------------------------- ----------- VISUAL UPDATING ----------- ---------------------------

local WireUpdateQueue: { number } = {}

function WireService.Enqueue(id: number)

-- ----------------------------- --------- WIRE INSTANTIATION ---------- ---------------------------

local function InstantiateWire(): TWire
	local wire = Instance.new("Beam")
	wire.LightInfluence = 0
	wire.Brightness = 1
	wire.Transparency = NumberSequence.new(0)
	wire.FaceCamera = true
	wire.Segments = 1
	wire.Width0 = 0.3
	wire.Width1 = 0.3
	
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.Transparency = 1
	hitbox.Parent = wire

	return wire :: TWire
end

function WireService.CreateWire(from: number, to: number, node: string, state: SignalService.TSignal): number
	local function findAttachment(model: GateModel.TGateModel, nodeName: string): Attachment
		local node = model:FindFirstChild(nodeName)
		assert(node, "FromGate had no Output node")
		local attachment = node:FindFirstChildOfClass("Attachment")
		assert(attachment, "Output node had no WireAttachment???")
		return attachment
	end
	
	local wire = InstantiateWire()
	wire.Attachment0 = findAttachment((GateRegistry.GetGate(from) :: { Model: Model }).Model , "Output")
	wire.Attachment1 = findAttachment(to.Model, node)
	wire.Color = if SignalService.toBoolean(state) then COLOR_ON else COLOR_OFF

	local id = NextID()
	wire:SetAttribute("ID", id)
	RegisterWire(id, from, to, node, wire)

	return id
end

function WireService.CutWire(id: TWireID)
	WiresRegistry[id].model:Destroy()
	UnregisterWire(id)
end

function WireService.CutAllWires(id: TGateID)
	for wireId in pairs(GateWireMap[id]) do
		WiresRegistry[wireId].model:Destroy()
	end
	GateWireMap[id] = nil
end

function WireService.UpdateWireHitbox(wire: Beam)
	local hitbox = wire:FindFirstChildWhichIsA("Part") :: Part

	local fromPosition: Attachment = wire.Attachment0 :: Attachment
	local toPosition: Attachment = wire.Attachment1 :: Attachment

	hitbox.Size = Vector3.new(0.2, 0.2, (toPosition.WorldPosition - fromPosition.WorldPosition).Magnitude)
	hitbox.CFrame = CFrame.new(fromPosition.WorldPosition, toPosition.WorldPosition)
	hitbox.CFrame = hitbox.CFrame:ToWorldSpace(CFrame.new(0, 0, -hitbox.Size.Z/2))
end

function WireService.EnqueueUpdate(gateId: number, value: SignalService.TSignal)
	WireUpdateQueue[gateId] = SignalService.toBoolean(value)
end

function WireService.UpdateWireColours()
	for gateId, value in pairs(WireUpdateQueue) do
		if not WiresRegistry[gateId] then continue end
		for _, wire in ipairs(WiresRegistry[gateId]) do
			if value then
				if wire.Color == COLOR_OFF then
					wire.Color = COLOR_ON
					wire.LightEmission = 1
				end
			else
				if wire.Color == COLOR_ON then
					wire.Color = COLOR_OFF
					wire.LightEmission = 0
				end
			end
		end
	end
end

return WireService
