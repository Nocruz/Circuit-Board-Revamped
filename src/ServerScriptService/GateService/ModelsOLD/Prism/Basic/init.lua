--[[ BASIC ]]

-- Requires and services
local Style = require(script.Parent)

-- Prefabs
local prefab = script.Prefab

-- -----------------------------------------------------------------------------------------------------

local Type = {}

-- -----------------------------------------------------------------------------------------------------

function Type.Instantiate(nodes)
	return Style.Instantiate(prefab, nodes, "Basic")
end

function Type.UpdateVisuals(model, visuals)
	Style.UpdateVisuals(model, visuals)
	
	model.Main.DisplayNameGui.TextLabel.Text = visuals.DisplayName
end

function Type.Trigger(model, action)
	if action and action.Source == "Signal" and action.Active == true then
		model.Main.DisplayNameGui.TextLabel.UIStroke.Color = Style.onStrokeColor
		
	elseif action and action.Source == "Signal" and action.Active == false then
		model.Main.DisplayNameGui.TextLabel.UIStroke.Color = Style.offStrokeColor
	end
end

function Type.Destroy(model)
	Style.Destroy(model)
end

-- ----------------------------- ------------ END OF MODULE -------------- -----------------------------

return Type
