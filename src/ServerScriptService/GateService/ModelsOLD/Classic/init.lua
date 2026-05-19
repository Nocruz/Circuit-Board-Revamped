--[[ CLASSIC STYLE ]]

local nodePrefab = script.Node

local Style = {
	nodePrefab = nodePrefab,
	nodeRotations = {
		front = CFrame.Angles(0, 0, 0),
		back  = CFrame.Angles(0, math.rad(180), 0),
		left  = CFrame.Angles(0, math.rad(90), 0),
		right = CFrame.Angles(0, math.rad(270), 0)
	},
	baseSize = script.Basic.Prefab.Base.Size,

	onStrokeTransparency = 0.8,
	offStrokeTransparency = 1,
	
	SnapToEdge = function(coordinate: Vector2): (Vector2, string)
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
	end,
	NodeOffset = function(base: BasePart) return CFrame.new(0, base.Size.Y + nodePrefab.Size.Y / 2, nodePrefab.Size.Z / 2) end,
}

-- -----------------------------------------------------------------------------------------------------

function Style.Instantiate(prefab, nodes, type)
	local model = prefab:Clone()
	 -- Pre-instantiate all physical nodes based on the Specification.
	-- We don't position them yet; UpdateVisuals handles that.
	for i, inputName in ipairs(nodes.Inputs) do
		local node = nodePrefab:Clone()
		node.Name = inputName
		node.Material = Enum.Material.Plastic
		node.Color = Color3.new(0.5, 0.5, 0.5)
		node.NodeName.TextLabel.Text = inputName
		node.NodeName.TextLabel.TextColor3 = Color3.new(0.1, 0.4, 0.8)
		node:SetAttribute("Type", "Input")
		node:SetAttribute("ID", i)
		node.Parent = model.Nodes.Inputs
	end
	
	for i, outputName in ipairs(nodes.Outputs) do
		local node = nodePrefab:Clone()
		node.Name = outputName
		node.Material = Enum.Material.SmoothPlastic
		node.Color = Color3.new(1, 1, 1)
		node.NodeName.TextLabel.Text = outputName
		node.NodeName.TextLabel.TextColor3 = Color3.new(0.8, 0.1, 0.15)
		node:SetAttribute("Type", "Output")
		node:SetAttribute("ID", i)
		node.Parent = model.Nodes.Outputs
	end
	
	return {
		Instance = model,
		Type = type,
		Style = "Classic",
		Decoration = model.Decoration,
		Main = model.Decoration.Main,
		Base = model.Base,
		Nodes = model.Nodes
	}
end

function Style.UpdateVisuals(model, visuals)
	local main = model.Main
	
	-- Apply main visuals
	main.Color = visuals.MainColor
	main.Material = visuals.MainMaterial
	main.DisplayNameGui.TextLabel.Text = visuals.DisplayName
	
	local activeEdges = { front = false, back = false, left = false, right = false }
	-- Visual's node offsets
	for _, node in ipairs(model.Nodes.Inputs:GetChildren()) do
		local i = node:GetAttribute("ID")
		
		local offset, edge = Style.SnapToEdge(visuals.InputOffsets[i])
		activeEdges[edge] = true
		
		local transform = CFrame.new(offset.X * Style.baseSize.X, 0, offset.Y * Style.baseSize.Z)
		node.CFrame = model.Instance:GetPivot() * transform * Style.nodeRotations[edge] * Style.NodeOffset(model.Base)
	end
	
	for _, node in ipairs(model.Nodes.Outputs:GetChildren()) do
		local i = node:GetAttribute("ID")
		
		local offset, edge = Style.SnapToEdge(visuals.OutputOffsets[i])
		activeEdges[edge] = true
		
		local transform = CFrame.new(offset.X * Style.baseSize.X, 0, offset.Y * Style.baseSize.Z)
		node.CFrame = model.Instance:GetPivot() * transform * Style.nodeRotations[edge] * Style.NodeOffset(model.Base)
	end

	-- Resize main
	local shrinkVector = Vector2.new(math.max(0, Style.nodePrefab.Size.Z - (Style.baseSize.X - main.Size.X) / 2), math.max(0, Style.nodePrefab.Size.Z - (Style.baseSize.z - main.Size.Z) / 2))
	local shrinkL = if activeEdges.left  then shrinkVector.X else 0
	local shrinkR = if activeEdges.right then shrinkVector.X else 0
	local shrinkF = if activeEdges.front then shrinkVector.Y else 0
	local shrinkB = if activeEdges.back  then shrinkVector.Y else 0
	
	main.Size = Vector3.new(math.max(0, main.Size.X - (shrinkL + shrinkR)), main.Size.Y, math.max(0, main.Size.Z - (shrinkF + shrinkB)))
	
	-- Offset center
	local offsetX = (shrinkL - shrinkR) / 2
	local offsetZ = (shrinkF - shrinkB) / 2
	main.CFrame = model.Instance:GetPivot() * CFrame.new(offsetX, Style.baseSize.Y + main.Size.Y / 2, offsetZ)

	return activeEdges
end

function Style.SwapStyle_Destroy(model)
	local info = table.clone(model.TypeInformation)
	Style.Destroy(model)
	return info
end

function Style.Destroy(model)
	assert(model.Instance, "Can't destroy model. Reason: Model is nil.")
	model.Instance:Destroy()
	table.clear(model)
	model = nil
end

-- ----------------------------- ------------ END OF MODULE -------------- -----------------------------

return Style
