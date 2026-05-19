--[[ CLASSIC : BASIC
	Simplest ModelType. Used for simple gates, e.g. AND, NOT, OR, XOR.
	
	Instance
		├── Nodes - Folder with Inputs & Outputs	folders where the Nodes live.
		├── Base  - Square at the bottom. 2 × 0.2 × 2.
		└── Main  - Resizable part with nodes attached to walls. Holds the DisplayNameGui -> TextLabel.
	
	All other Styles will fallback to this implementation if no ModelType is defined.
]]

local Shared = require(script.Parent.Shared)
local Prefab = script.Parent.Prefabs.Basic

local Handler = {}

-- ----------------------------- ------- REQUIRED IMPLEMENTATIONS -------- -----------------------------

function Handler.Instantiate(nodes)
	local model = Shared.Instantiate(Prefab, nodes)
	model.LogicalState = { IsAnyOutputActive = false }
	return model
end

function Handler.UpdateVisuals(model, visuals)
	local main = model.Instance.Main
	local pivot = model.Instance:GetPivot()
	
	main.Color = visuals.MainColor
	main.Material = visuals.MainMaterial
	main.DisplayNameGui.TextLabel.Text = visuals.DisplayName

	local activeEdges = Shared.PlaceNodes(model, visuals)
	Shared.ResizeAndCenter(main, Prefab.Main, pivot, activeEdges)
end

function Handler.Destroy(model)
	return Shared.Destroy(model)
end

--[[ --------------------------- -------------- TRIGGERS ----------------- -----------------------------
	The Handler table has named functions that handle specific actions. If that action is not handled,
		then we just don't act on it. We build a Dispatch map from sources to ActionHandlers.
	
	The LogicalState is just a store of the current state of the model, used by SwapStyle.
	
	I will add Documentation on action sources eventually, but for now the Classic implementations should do.
	For an example of animations and tracks, see ACTIVATOR ModelType.
]]

function Handler.OnOutputSignalChanged(model, action)
	model.LogicalState.IsAnyOutputActive = action.AnyActive
	
	-- No animations, just a glow. No need for a track here.
	model.Instance.Main.DisplayNameGui.TextLabel.TextStrokeTransparency = if action.AnyActive then 0 else 1
end

local Dispatch = {
	OutputSignals = Handler.OnOutputSignalChanged
}

function Handler.Trigger(model, action)
	if not action then return end
	local actionHandler = Dispatch[action.Source]
	if actionHandler then actionHandler(model, action) end
end

--[[ --------------------------- ---------- STATE RESTORATION ------------ -----------------------------
	Called by SwapStyle to mantain visual continuity when changing models.
	Could be used by the Save system if I ever decide to store state there.
	
	The handlers here should have no animations whatsoever, to make the transition as cleanely as possible.
]]

function Handler.ApplyLogicalState(model, state)
	model.Instance.Main.DisplayNameGui.TextLabel.TextStrokeTransparency = if state.IsAnyOutputActive then 0 else 1
end

-- ----------------------------- ------------ END OF MODULE -------------- -----------------------------

return Handler
