--!strict
--[[ WIRE SERVICE
		Manages visual representation of connections (Beams).
		Throttles visual updates to prevent network/render saturation.
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Types
local Types = require(game:GetService("ServerScriptService").Gates.Definitions.Types)
local SignalService = require(game:GetService("ServerScriptService").Gates.Services.SignalService)

-- Constants
local COLOR_ON = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
local COLOR_OFF = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0))

-- References
local wirePrefab: Beam = ReplicatedStorage.Wire

local WiresFolder = Instance.new("Folder")
WiresFolder.Name = "Wires"
WiresFolder.Parent = workspace

-- State
-- [GateId]: { Wire }
local WiresRegistry: { [number]: { Beam } } = {	}
local WireUpdateQueue: { [number]: boolean } = { }

local WireService = {}

function WireService.new(from: Types.TGate, to: Types.TGate, node: string)
	local fromModel = from.Model
	local output = fromModel:FindFirstChild("Nodes"):FindFirstChild("Output") :: Part
	
	local toModel = to.Model
	local input = toModel:FindFirstChild("Nodes"):FindFirstChild(node) :: Part
	
	local wire = wirePrefab:Clone()
	wire.Attachment0 = output:FindFirstChildWhichIsA("Attachment")
	wire.Attachment1 = input:FindFirstChildWhichIsA("Attachment")
	wire.Parent = WiresFolder

	local part = Instance.new("Part")
	part.Name = "WireHitbox"
	part.Parent = wire
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1

	WireService.UpdateWireHitbox(wire, part)
	
	wire:SetAttribute("In", from.Id)
	wire:SetAttribute("Out", to.Id)
	wire:SetAttribute("Node", node)
	
	if from.Output ~= nil and SignalService.toBoolean(from.Output) then
		wire.Color = COLOR_ON
		wire.LightEmission = 1
	else
		wire.Color = COLOR_OFF
		wire.LightEmission = 0
	end
	
	WiresRegistry[from.Id] = WiresRegistry[from.Id] or {}
	table.insert(WiresRegistry[from.Id], wire)
	
	return wire
end

function WireService.destroy(fromId: number, wire: Beam)
	table.remove(WiresRegistry[fromId], table.find(WiresRegistry[fromId], wire))
	wire:Destroy()
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
