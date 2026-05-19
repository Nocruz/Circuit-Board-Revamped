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
	Style.UpdateVisuals(model, visuals)
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
