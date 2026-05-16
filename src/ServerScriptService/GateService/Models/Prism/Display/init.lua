--[[ DISPLAY ]]

-- Requires and services
local Style = require(script.Parent)

-- Prefabs
local prefab = script.Prefab

-- -----------------------------------------------------------------------------------------------------

local Type = {}

-- -----------------------------------------------------------------------------------------------------

function Type.Instantiate(nodes)
	return Style.Instantiate(prefab, nodes, "Display")
end

function Type.UpdateVisuals(model, visuals)
	local activeEdges = Style.UpdateVisuals(model, visuals)
	
	-- Resize main
	local main = model.Main	
	local shrinkVector = Vector2.new(math.max(0, Style.nodePrefab.Size.Z - (model.Base.Size.X - main.Size.X) / 2), math.max(0, Style.nodePrefab.Size.Z - (model.Base.Size.z - main.Size.Z) / 2))
	local shrinkL = if activeEdges.left  then shrinkVector.X else 0
	local shrinkR = if activeEdges.right then shrinkVector.X else 0
	local shrinkF = if activeEdges.front then shrinkVector.Y else 0
	local shrinkB = if activeEdges.back  then shrinkVector.Y else 0
	
	main.Size = Vector3.new(math.max(0, main.Size.X - (shrinkL + shrinkR)), main.Size.Y, math.max(0, main.Size.Z - (shrinkF + shrinkB)))
	
	-- Offset center
	local offsetX = (shrinkL - shrinkR) / 2
	local offsetZ = (shrinkF - shrinkB) / 2
	main.CFrame = model.Instance:GetPivot() * CFrame.new(offsetX, prefab.Base.Size.Y + main.Size.Y / 2, offsetZ)
end

function Type.Trigger(model, action)
	if action and action.Source == "Text" then
		model.Decoration.Screen.SurfaceGui.TextLabel.Text = action.Text
	end
end

function Type.Destroy(model)
	Style.Destroy(model)
end

-- ----------------------------- ------------ END OF MODULE -------------- -----------------------------

return Type
