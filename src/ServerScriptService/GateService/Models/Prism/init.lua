--[[ PRISM STYLE ]]

local nodePrefab = script.Node

local Style = {
	DefaultVisuals = {
		MainMaterial = Enum.Material.SmoothPlastic
	},
	
	nodePrefab = nodePrefab,
	nodeRotations = {
		front = CFrame.Angles(0, 0, 0),
		back  = CFrame.Angles(0, math.rad(180), 0),
		left  = CFrame.Angles(0, math.rad(90), 0),
		right = CFrame.Angles(0, math.rad(270), 0)
	},
	baseSize = script.Basic.Prefab.Base.Size,
	
	onStrokeColor = Color3.new(1, 1, 0.3),
	offStrokeColor = Color3.new(1, 1, 1),
	
	SnapToEdge = function(coordinate: Vector2): Vector2
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
	NodeOffset = function(base: BasePart) return CFrame.new(0, nodePrefab.Size.Y / 2, nodePrefab.Size.Z / 2 - 0.05) end,
}

-- -----------------------------------------------------------------------------------------------------

function Style.Instantiate(prefab, nodes, type)
	local model = prefab:Clone()
	
	-- Pre-instantiate all physical nodes based on the Specification.
	-- We don't position them yet; UpdateVisuals handles that.
	for i, inputName in ipairs(nodes.Inputs) do
		local node = nodePrefab:Clone()
		node.Name = inputName
		node.Material = Enum.Material.SmoothPlastic
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
		node.NodeName.TextLabel.Text = outputName
		node.NodeName.TextLabel.TextColor3 = Color3.new(0.8, 0.1, 0.15)
		node:SetAttribute("Type", "Output")
		node:SetAttribute("ID", i)
		node.Parent = model.Nodes.Outputs
	end
	
	return {
		Instance = model,
		Type = type,
		Style = "Prism",
		
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

	return activeEdges
end

function Style.DestroyInstant(model)
	assert(model.Instance, "Can't destroy model. Reason: Model is nil.")
	model.Instance:Destroy()
	table.clear(model)
	model = nil
end

function Style.Destroy(model)
	Style.DestroyInstant(model)
end

-- ----------------------------- ------------ END OF MODULE -------------- -----------------------------

return Style
