-- [[ CLASSIC : SHARED ]]
-- Holds the shared functions and constants for all Classic ModelTypes.

-- ----------------------------- ---------- MODULE DEFINITION ------------ -----------------------------

local Shared = {}

Shared.NODE_PREFAB = script.Parent.Prefabs.Node
assert(Shared.NODE_PREFAB, '"Classic" style has no Node prefab.')

Shared.BASE_SIZE = script.Parent.Prefabs.Basic.Base.Size

Shared.nodeRotations = {
	front = CFrame.Angles(0, 0, 0),
	back  = CFrame.Angles(0, math.rad(180), 0),
	left  = CFrame.Angles(0, math.rad(90), 0),
	right = CFrame.Angles(0, math.rad(270), 0)
}

-- ----------------------------- ------------ EDGE DETECTION ------------- -----------------------------

function Shared.SnapToEdge(coordinate: Vector2): (Vector2, string)
	if math.abs(coordinate.X) > math.abs(coordinate.Y) then
		if coordinate.X < 0 then
			return Vector2.new(-0.5, coordinate.Y), "left"
		else
			return Vector2.new( 0.5, coordinate.Y), "right"
		end
	else
		if coordinate.Y < 0 then
			return Vector2.new(coordinate.X, -0.5), "front"
		else
			return Vector2.new(coordinate.X,  0.5), "back"
		end
	end
end

function Shared.NodeOffset(base: BasePart)
	return CFrame.new(0, base.Size.Y + Shared.NODE_PREFAB.Size.Y / 2, Shared.NODE_PREFAB.Size.Z / 2)
end

-- ----------------------------- ------------ NODE PLACEMENT ------------- -----------------------------

function Shared.PlaceNodes(model, visuals)
	local activeEdges = { front = false, back = false, left = false, right = false }
	-- Visual's node offsets
	for _, node in ipairs(model.Instance.Nodes.Inputs:GetChildren()) do
		local i = node:GetAttribute("ID")
		
		local offset, edge = Shared.SnapToEdge(visuals.InputOffsets[i])
		activeEdges[edge] = true
		
		local transform = CFrame.new(offset.X * Shared.BASE_SIZE.X, 0, offset.Y * Shared.BASE_SIZE.Z)
		node.CFrame = model.Instance:GetPivot() * transform * Shared.nodeRotations[edge] * Shared.NodeOffset(model.Instance.Base)
	end
	
	for _, node in ipairs(model.Instance.Nodes.Outputs:GetChildren()) do
		local i = node:GetAttribute("ID")
		
		local offset, edge = Shared.SnapToEdge(visuals.OutputOffsets[i])
		activeEdges[edge] = true
		
		local transform = CFrame.new(offset.X * Shared.BASE_SIZE.X, 0, offset.Y * Shared.BASE_SIZE.Z)
		node.CFrame = model.Instance:GetPivot() * transform * Shared.nodeRotations[edge] * Shared.NodeOffset(model.Instance.Base)
	end

	return activeEdges
end

-- ----------------------------- ------------ PART RESIZING -------------- -----------------------------

function Shared.ResizeAndCenter(part: BasePart, prefabPart: BasePart, pivot: CFrame, activeEdges, yBase: number?)
	yBase = yBase or Shared.BASE_SIZE.Y; assert(yBase)
	
	local originalSize = prefabPart.Size
	local nodeDepth = Shared.NODE_PREFAB.Size.Z
	
	local dX = math.max(0, nodeDepth - (Shared.BASE_SIZE.X - originalSize.X) / 2)
	local dZ = math.max(0, nodeDepth - (Shared.BASE_SIZE.Z - originalSize.X) / 2)
	
	-- Resize main
	local shrinkL = if activeEdges.left  then dX else 0
	local shrinkR = if activeEdges.right then dX else 0
	local shrinkF = if activeEdges.front then dZ else 0
	local shrinkB = if activeEdges.back  then dZ else 0
	
	part.Size = Vector3.new(
		math.max(0, originalSize.X - (shrinkL + shrinkR)),
		originalSize.Y,
		math.max(0, originalSize.Z - (shrinkF + shrinkB))
	)
	
	-- Offset center
	local offsetX = (shrinkL - shrinkR) / 2
	local offsetZ = (shrinkF - shrinkB) / 2
	part.CFrame = pivot * CFrame.new(offsetX, yBase + part.Size.Y / 2, offsetZ)
end

-- ----------------------------- ------- HANDLER IMPLEMENTATIONS --------- -----------------------------

function Shared.Instantiate(prefab, nodes)
	local instance = prefab:Clone()
	
	-- Pre-instantiate all physical nodes based on the Specification.
	-- We don't position them yet; UpdateVisuals handles that.
	for i, inputName in ipairs(nodes.Inputs) do
		local node = Shared.NODE_PREFAB:Clone()
		node.Name = inputName
		node.Material = Enum.Material.Plastic
		node.Color = Color3.new(0.5, 0.5, 0.5)
		node.NodeName.TextLabel.Text = inputName
		node.NodeName.TextLabel.TextColor3 = Color3.new(0.1, 0.4, 0.8)
		node:SetAttribute("Type", "Input")
		node:SetAttribute("ID", i)
		node.Parent = instance.Nodes.Inputs
	end
	
	for i, outputName in ipairs(nodes.Outputs) do
		local node = Shared.NODE_PREFAB:Clone()
		node.Name = outputName
		node.Material = Enum.Material.SmoothPlastic
		node.Color = Color3.new(1, 1, 1)
		node.NodeName.TextLabel.Text = outputName
		node.NodeName.TextLabel.TextColor3 = Color3.new(0.8, 0.1, 0.15)
		node:SetAttribute("Type", "Output")
		node:SetAttribute("ID", i)
		node.Parent = instance.Nodes.Outputs
	end
	
	return { Instance = instance }
end

function Shared.Destroy(model)
	assert(model.Instance, "Can't destroy model. Reason: Instance is nil.")
	model.Instance:Destroy()
	table.clear(model)
end

-- ----------------------------- ------------ END OF MODULE -------------- -----------------------------

return Shared
