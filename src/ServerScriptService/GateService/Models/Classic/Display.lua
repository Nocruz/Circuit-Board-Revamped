--[[ CLASSIC : DISPLAY
	A ModelType that renders text.
	See BASIC ModelType for more documented comments.
	
	Instance
		├── Nodes  - Folder with Inputs & Outputs	folders where the Nodes live.
		├── Base   - Square at the bottom. 2 × 0.2 × 2.
		├── Main   - Resizable part with nodes attached to walls.
		├── Top    - Fixed-size colored square. Decoration.
		└── Screen - Renders text. Holds a SurfaceGui -> TextLabel.
	
	All other Styles will fallback to this implementation if no ModelType is defined.
]]

local Shared = require(script.Parent.Shared)
local Prefab = script.Parent.Prefabs.Display

local Handler = {}

-- ----------------------------- ------- REQUIRED IMPLEMENTATIONS -------- -----------------------------

function Handler.Instantiate(nodes)
	local model = Shared.Instantiate(Prefab, nodes)
	model.LogicalState = { Text = "" }
	return model
end

function Handler.UpdateVisuals(model, visuals)
	local top = model.Instance.Top
	local main = model.Instance.Main
	local pivot = model.Instance:GetPivot()
	
	main.Color = visuals.MainColor
	main.Material = visuals.MainMaterial
	top.Color = visuals.MainColor
	top.Material = visuals.MainMaterial
	
	local activeEdges = Shared.PlaceNodes(model, visuals)
	Shared.ResizeAndCenter(main, Prefab.Main, pivot, activeEdges)
end

function Handler.Destroy(model)
	return Shared.Destroy(model)
end

-- ----------------------------- -------------- TRIGGERS ----------------- -----------------------------

function Handler.UpdateText(model, action)
	model.LogicalState.Text = action.Text
	model.Instance.Screen.SurfaceGui.TextLabel.Text = action.Text
end

local Dispatch = {
	Text = Handler.UpdateText
}

function Handler.Trigger(model, action)
	if not action then return end
	local actionHandler = Dispatch[action.Source]
	if actionHandler then actionHandler(model, action) end
end

-- ----------------------------- ---------- STATE RESTORATION ------------ -----------------------------

function Handler.ApplyLogicalState(model, state)
	model.Instance.Screen.SurfaceGui.TextLabel.Text = state.Text or ""
end

-- ----------------------------- ------------ END OF MODULE -------------- -----------------------------

return Handler
