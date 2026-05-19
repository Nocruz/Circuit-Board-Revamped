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
	Style.UpdateVisuals(model, visuals)
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
