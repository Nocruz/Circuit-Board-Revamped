local Shared = {}

Shared.GATE_PREFAB = script.Parent.Prefabs.Basic
assert(Shared.GATE_PREFAB, '"Classic" style has no Basic Gate prefab.')

Shared.NODE_PREFAB = script.Parent.Prefabs.Node
assert(Shared.NODE_PREFAB, '"Classic" style has no Node prefab.')

Shared.baseSize = Shared.GATE_PREFAB.Base.Size

Shared.nodeRotations = {
	front = CFrame.Angles(0, 0, 0),
	back  = CFrame.Angles(0, math.rad(180), 0),
	left  = CFrame.Angles(0, math.rad(90), 0),
	right = CFrame.Angles(0, math.rad(270), 0)
}

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

function Shared.Instantiate(prefab, nodes)
	local model = prefab:Clone()
	
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
		node.Parent = model.Nodes.Inputs
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
		node.Parent = model.Nodes.Outputs
	end
	
	return { Instance = model }
end

function Shared.Destroy(model)
	assert(model.Instance, "Can't destroy model. Reason: Model is nil.")
	model.Instance:Destroy()
	table.clear(model)
end

return Shared
