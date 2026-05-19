--[[ MODERN : DISPLAY ]]

local Shared = require(script.Parent.Shared)

local Prefab = script.Parent.Prefabs.Display
local handler = {}

function handler.Instantiate(nodes)
	local model = Shared.Instantiate(Prefab, nodes)
	model.LogicalState = { Text = "" }
	return model
end

function handler.UpdateVisuals(model, visuals)
	local main = model.Instance.Main
	
	-- Apply main visuals
	main.Color = visuals.MainColor
	main.Material = visuals.MainMaterial
	
	local activeEdges = { front = false, back = false, left = false, right = false }
	-- Visual's node offsets
	for _, node in ipairs(model.Instance.Nodes.Inputs:GetChildren()) do
		local i = node:GetAttribute("ID")
		
		local offset, edge = Shared.SnapToEdge(visuals.InputOffsets[i])
		activeEdges[edge] = true
		
		local transform = CFrame.new(offset.X * Shared.baseSize.X, 0, offset.Y * Shared.baseSize.Z)
		node.CFrame = model.Instance:GetPivot() * transform * Shared.nodeRotations[edge] * Shared.NodeOffset(model.Instance.Base)
	end
	
	for _, node in ipairs(model.Instance.Nodes.Outputs:GetChildren()) do
		local i = node:GetAttribute("ID")
		
		local offset, edge = Shared.SnapToEdge(visuals.OutputOffsets[i])
		activeEdges[edge] = true
		
		local transform = CFrame.new(offset.X * Shared.baseSize.X, 0, offset.Y * Shared.baseSize.Z)
		node.CFrame = model.Instance:GetPivot() * transform * Shared.nodeRotations[edge] * Shared.NodeOffset(model.Instance.Base)
	end

	-- Resize main
	local shrinkVector = Vector2.new(math.max(0, Shared.NODE_PREFAB.Size.Z - (Shared.baseSize.X - main.Size.X) / 2), math.max(0, Shared.NODE_PREFAB.Size.Z - (Shared.baseSize.z - main.Size.Z) / 2))
	local shrinkL = if activeEdges.left  then shrinkVector.X else 0
	local shrinkR = if activeEdges.right then shrinkVector.X else 0
	local shrinkF = if activeEdges.front then shrinkVector.Y else 0
	local shrinkB = if activeEdges.back  then shrinkVector.Y else 0
	
	main.Size = Vector3.new(math.max(0, main.Size.X - (shrinkL + shrinkR)), main.Size.Y, math.max(0, main.Size.Z - (shrinkF + shrinkB)))
	
	-- Offset center
	local offsetX = (shrinkL - shrinkR) / 2
	local offsetZ = (shrinkF - shrinkB) / 2
	main.CFrame = model.Instance:GetPivot() * CFrame.new(offsetX, Shared.baseSize.Y + main.Size.Y / 2, offsetZ)
	
	return activeEdges
end

function handler.Destroy(model)
	return Shared.Destroy(model)
end

function handler.Trigger(model, action)
	if action and action.Source == "Text" and action.Text then
		model.LogicalState.Text = tostring(action.Text)
	end
end

function handler.ApplyLogicalState(model, state)
	model.Instance.Screen.SurfaceGui.TextLabel.Text = state.Text
end

--[[
handler.DefaultVisuals = {
	-- Default visuals for this ModelType only, on this Style only.
}
]]

return handler
