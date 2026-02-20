--!strict
--[[ GATE MODEL
		This defines the structure of a GateModel.
		It's the visual representation of a Gate object.
]]

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local GateVisuals = require(ReplicatedStorage.Gates.GateVisuals)

-- Types
local Types = require(ServerScriptService.Gates.Definitions.Types)
export type TGateModel = Types.TGateModel

-- Prefabs
local PrefabsFolder = ReplicatedStorage.Gates.Prefabs
local GatePrefabsFolder = PrefabsFolder.Gates

local BasicGatePrefab = GatePrefabsFolder.BasicGate
local NodePrefab = PrefabsFolder.Node

-- Default Node Offsets
local DefaultNodeOffsets = {
	{ Vector2.new(0, 0.5) },
	{ Vector2.new(-0.2, 0.5), Vector2.new(0.2, 0.5) },
	{ Vector2.new(-0.25, 0.5), Vector2.new(0, 0.5), Vector2.new(0.25, 0.5) },
	{ Vector2.new(-0.25, 0.5), Vector2.new(0, 0.5), Vector2.new(0.25, 0.5), Vector2.new(0.5, 0) },
	{ Vector2.new(-0.25, 0.5), Vector2.new(0, 0.5), Vector2.new(0.25, 0.5), Vector2.new(0.5, -0.2), Vector2.new(0.5, 0.2) },
}

-- ----------------------------- ---------- HELPER FUNCTIONS ---------- ---------------------------

type range = { Min: number, Max: number }
type edge = "front" | "back" | "left" | "right"
local function getCFrameOffsetAndEdge(offset: Vector2, limits: { X: range, Z: range }, edgeZ: number ): (CFrame, edge)
	local nodeYOffset = (NodePrefab.Size.Y + BasicGatePrefab.Base.Size.Y) / 2
	
	local x = math.clamp(offset.X, limits.X.Min, limits.X.Max)
	local z = math.clamp(offset.Y, limits.Z.Min, limits.Z.Max)
	local direction: Vector3
	local edge: edge

	local distanceLeft = math.abs(x - limits.X.Min)
	local distanceRight = math.abs(x - limits.X.Max)
	local distanceZ = math.abs(z - edgeZ)
	local minDistance = math.min(distanceLeft, distanceRight, distanceZ)
	
	if minDistance == distanceZ then 
		z = edgeZ
		if math.sign(z) <= 0 then
			direction = Vector3.zAxis
			edge = "front"
		else
			direction = -Vector3.zAxis
			edge = "back"
		end
	elseif minDistance == distanceLeft then 
		x = limits.X.Min
		direction = Vector3.xAxis
		edge = "left"
	elseif minDistance == distanceRight then 
		x = limits.X.Max
		direction = -Vector3.xAxis
		edge = "right"
	end
	
	local offset = Vector3.new(x * BasicGatePrefab.Base.Size.X, nodeYOffset, z * BasicGatePrefab.Base.Size.Z)
	return CFrame.new(offset, offset + direction) * CFrame.new(0, 0, -NodePrefab.Size.Z / 2), edge
end
local function getInputCFrameOffsetAndEdge(offset: Vector2): (CFrame, edge)
	return getCFrameOffsetAndEdge(offset, { X = { Min = -0.5, Max = 0.5}, Z = { Min = -0.2, Max = 0.5} }, 0.5) end
local function getOutputCFrameOffsetAndEdge(offset: Vector2): (CFrame, edge)
	return getCFrameOffsetAndEdge(offset, { X = { Min = -0.5, Max = 0.5}, Z = { Min = -0.5, Max = -0.3} }, -0.5) end


local function ResizeMainWithInset(gateModel: TGateModel, edges: { [edge]: boolean } )
	local main = gateModel.Decoration.Main
	local base = gateModel.Base

	-- Store original relative position
	local relativeCFrame = base.CFrame:ToObjectSpace(main.CFrame)

	-- Calculate how much to shrink on each axis
	local originalInsetX = (base.Size.X - main.Size.X) / 2
	local originalInsetZ = (base.Size.Z - main.Size.Z) / 2
	local shrinkX = NodePrefab.Size.X - originalInsetX
	local shrinkZ = NodePrefab.Size.Z - originalInsetZ

	-- Calculate size and position changes
	local sizeChange = Vector3.zero
	local offsetChange = Vector3.new(0, relativeCFrame.Y, 0)

	-- Apply edge-specific changes
	if edges.left then
		sizeChange += Vector3.new(shrinkX, 0, 0)
		offsetChange += Vector3.new(shrinkX / 2, 0, 0)
	end
	if edges.right then
		sizeChange += Vector3.new(shrinkX, 0, 0)
		offsetChange += Vector3.new(-shrinkX / 2, 0, 0)
	end
	if edges.front then
		sizeChange += Vector3.new(0, 0, shrinkZ)
		offsetChange += Vector3.new(0, 0, shrinkZ / 2)
	end
	if edges.back then
		sizeChange += Vector3.new(0, 0, shrinkZ)
		offsetChange += Vector3.new(0, 0, -shrinkZ / 2)
	end

	-- Apply changes
	local localSizeChange = relativeCFrame:VectorToObjectSpace(sizeChange)
	main.Size -= Vector3.new(math.abs(localSizeChange.X), 0, math.abs(localSizeChange.Z))
	main.CFrame = base.CFrame * CFrame.new(offsetChange) * relativeCFrame.Rotation
end

-- ----------------------------- ----- GATE MODEL INSTANTIATION ----- -----------------------------

local GateModel = {}

function GateModel.instantiate(class: Types.TGateClass, visuals: Types.TGateVisuals, gridCFrame: CFrame): Types.TGateModel
	local prefab = PrefabsFolder.Gates:FindFirstChild(visuals.PrefabName)
	if not prefab then prefab = BasicGatePrefab end
	
	local model = (prefab :: Model):Clone()
	model:PivotTo(gridCFrame)
	model.Name = class.name
	
	local gateModel = model :: TGateModel
	local main = gateModel.Decoration.Main
	local base = gateModel.Base
	
	-- Decorate the gate
	main.Color = visuals.MainColor
	main.Material = visuals.MainMaterial
	local surfaceGui = main:FindFirstChildWhichIsA("SurfaceGui")
	if surfaceGui then
		local textLabel = surfaceGui:FindFirstChildWhichIsA("TextLabel")
		if textLabel then textLabel.Text = visuals.DisplayName end
	end
	
	-- Nodes
	local nodesOnEdge: { [edge]: boolean } = { front = false, back = false, left = false, right = false }
	
	-- Instantiate the Output node
	if class.output then
		local outNode = NodePrefab:Clone() :: Part
		outNode.Name = "Output"
		outNode.Parent = gateModel.Nodes
		outNode.Material = Enum.Material.Neon
		local billboardGui = outNode:FindFirstChildWhichIsA("BillboardGui")
		if billboardGui then
			local textLabel = billboardGui:FindFirstChildWhichIsA("TextLabel")
			if textLabel then textLabel.Text = "Output"; textLabel.TextColor3 = Color3.new(0.8, 0.1, 0.15) end
		end
		outNode:SetAttribute("Type", "Output")
		
		local outputOffset, edge = getOutputCFrameOffsetAndEdge(visuals.OutputOffset)
		outNode.CFrame = base.CFrame:ToWorldSpace(outputOffset)
		nodesOnEdge[edge] = true
	end
	
	-- Instantiate the Input nodes
	local defaultOffsets = DefaultNodeOffsets[#class.inputs]
	for i, inputName in class.inputs do
		local node = NodePrefab:Clone() :: Part
		node.Name = inputName
		node.Parent = gateModel.Nodes
		node.Material = Enum.Material.SmoothPlastic
		local billboardGui = node:FindFirstChildWhichIsA("BillboardGui")
		if billboardGui then
			local textLabel = billboardGui:FindFirstChildWhichIsA("TextLabel")
			if textLabel then textLabel.Text = inputName; textLabel.TextColor3 = Color3.new(0.1, 0.4, 0.8) end
		end
		node:SetAttribute("Type", "Input")
		
		local inputOffset = visuals.InputOffsets[inputName] or defaultOffsets[i] or error("Gate has more inputs than default can account for!")
		local nodeOffset, edge = getInputCFrameOffsetAndEdge(inputOffset)
		node.CFrame = base.CFrame:ToWorldSpace(nodeOffset)
		
		nodesOnEdge[edge] = true
	end
	
	ResizeMainWithInset(gateModel, nodesOnEdge)
	
	return gateModel
end

return GateModel