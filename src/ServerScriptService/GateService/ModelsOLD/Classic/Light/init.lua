--[[ LIGHT ]]

-- Requires and services
local Style = require(script.Parent)

-- Prefabs
local prefab = script.Prefab

-- -----------------------------------------------------------------------------------------------------

local Type = {}

-- -----------------------------------------------------------------------------------------------------

function Type.Instantiate(nodes)
	return Style.Instantiate(prefab, nodes, "Light")
end

function Type.UpdateVisuals(model, visuals)
	local activeEdges = Style.UpdateVisuals(model, visuals)
	local top = model.Decoration.Top
	
	-- Resize top
	do
		local shrinkVector = Vector2.new(math.max(0, prefab.Decoration.Main.Size.X - top.Size.X), math.max(0, prefab.Decoration.Main.Size.Z - top.Size.Z))
		local shrinkL = if activeEdges.left  then shrinkVector.X else 0
		local shrinkR = if activeEdges.right then shrinkVector.X else 0
		local shrinkF = if activeEdges.front then shrinkVector.Y else 0
		local shrinkB = if activeEdges.back  then shrinkVector.Y else 0

		top.Size = Vector3.new(math.max(0, top.Size.X - (shrinkL + shrinkR)), top.Size.Y, math.max(0, top.Size.Z - (shrinkF + shrinkB)))

		-- Offset center
		local offsetX = (shrinkL - shrinkR) / 2
		local offsetZ = (shrinkF - shrinkB) / 2
		top.CFrame = model.Instance:GetPivot() * CFrame.new(offsetX, prefab.Base.Size.Y + prefab.Decoration.Main.Size.Y + top.Size.Y / 2, offsetZ)
	end
end

function Type.Trigger(model, action)
	if action and action.Source == "Light" then
		model.Decoration.Top.Color = action.Color
		model.Decoration.Top.PointLight.Color = action.Color
		model.Decoration.Top.PointLight.Enabled = action.Color ~= Color3.new()
	end
end

function Type.Destroy(model)
	Style.Destroy(model)
end

-- ----------------------------- ------------ END OF MODULE -------------- -----------------------------

return Type
