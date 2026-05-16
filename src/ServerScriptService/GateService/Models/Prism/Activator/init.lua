--[[ ACTIVATOR ]]

-- Requires and services
local Style = require(script.Parent)

-- Prefabs
local prefab = script.Prefab

local function ToggleMain(model)
	model.Main.Position = Vector3.new(
		model.Main.Position.X,
		model.Decoration.Stem.Position.Y + model.Decoration.Stem.Size.Y / 2
		  + if model.TypeInformation.State
		  then -model.Main.Size.Y / 3 + 0.05
		  else  model.Main.Size.Y / 2,
		model.Main.Position.Z
	)
end

-- -----------------------------------------------------------------------------------------------------

local Type = {}

-- -----------------------------------------------------------------------------------------------------

function Type.Instantiate(nodes)
	local model = Style.Instantiate(prefab, nodes, "Activator")
	model.TypeInformation = { State = false }
	
	return model
end

function Type.UpdateVisuals(model, visuals)
	Style.UpdateVisuals(model, visuals)
	
	-- Apply main visuals
	local main = model.Main
	main.DisplayNameGui.TextLabel.Text = visuals.DisplayName
	ToggleMain(model)
end

function Type.Trigger(model, action)
	if action and action.Source == "Signal" and action.Active == true then
		model.Main.DisplayNameGui.TextLabel.UIStroke.Color = Style.onStrokeColor
		model.TypeInformation.State = true
		ToggleMain(model)
		
	elseif action and action.Source == "Signal" and action.Active == false then
		model.Main.DisplayNameGui.TextLabel.UIStroke.Color = Style.offStrokeColor
		model.TypeInformation.State = false
		ToggleMain(model)
	end
end

function Type.Destroy(model)
	Style.Destroy(model)
end

-- ----------------------------- ------------ END OF MODULE -------------- -----------------------------

return Type
