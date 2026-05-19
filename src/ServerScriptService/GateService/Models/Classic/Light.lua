--[[ CLASSIC : LIGHT
	A ModelType that emits light.
	See BASIC ModelType for more documented comments.
	
	Instance
		├── Nodes  - Folder with Inputs & Outputs	folders where the Nodes live.
		├── Base   - Square at the bottom. 2 × 0.2 × 2.
		├── Main   - Resizable part with nodes attached to walls.
		└── Top    - Changes color according to the light color. Holds a PointLight.
	
	All other Styles will fallback to this implementation if no ModelType is defined.
]]

local Shared = require(script.Parent.Shared)
local Prefab = script.Parent.Prefabs.Light

local Handler = {}

-- ----------------------------- ------- REQUIRED IMPLEMENTATIONS -------- -----------------------------

function Handler.Instantiate(nodes)
	local model = Shared.Instantiate(Prefab, nodes)
	model.LogicalState = { Text = "" }
	return model
end

function Handler.UpdateVisuals(model, visuals)
	local main = model.Instance.Main
	local pivot = model.Instance:GetPivot()
	
	main.Color = visuals.MainColor
	main.Material = visuals.MainMaterial
	
	local activeEdges = Shared.PlaceNodes(model, visuals)
	Shared.ResizeAndCenter(main, Prefab.Main, pivot, activeEdges)
end

function Handler.Destroy(model)
	return Shared.Destroy(model)
end

-- ----------------------------- -------------- TRIGGERS ----------------- -----------------------------

local function ApplyColor(model, color: Color3)
	local top = model.Instance.Top
	top.Color = color
	top.PointLight.Color   = color
	top.PointLight.Enabled = color ~= Color3.new()
end

function Handler.UpdateLight(model, action)
	model.LogicalState.Color = action.Color
	ApplyColor(model, action.Color)
end

local Dispatch = {
	Light = Handler.UpdateLight
}

function Handler.Trigger(model, action)
	if not action then return end
	local actionHandler = Dispatch[action.Source]
	if actionHandler then actionHandler(model, action) end
end

-- ----------------------------- ---------- STATE RESTORATION ------------ -----------------------------

function Handler.ApplyLogicalState(model, state)
	ApplyColor(model, state.Color or Color3.new())
end

-- ----------------------------- ------------ END OF MODULE -------------- -----------------------------

return Handler
