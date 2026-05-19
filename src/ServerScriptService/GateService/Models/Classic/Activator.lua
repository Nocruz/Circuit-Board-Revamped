--[[ CLASSIC : ACTIVATOR
	A ModelType with two states. Used for BUTTON and SWITCH.
	See BASIC ModelType for more documented comments.
	
	Instance
		├── Nodes     - Folder with Inputs & Outputs	folders where the Nodes live.
		├── Base      - Square at the bottom. 2 × 0.2 × 2.
		├── GreenBase - Resizable green square at the bottom. Nodes sit here
		├── Main      - Fixed-size colored square. Holds the DisplayNameGui -> TextLabel.
		└── Stem      - Decoration. Joins the Main part with the Base.
	
	All other Styles will fallback to this implementation if no ModelType is defined.
]]

local TweenService = game:GetService("TweenService")

local TW_PRESS_INFO   = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TW_RELEASE_INFO = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local Shared = require(script.Parent.Shared)
local Prefab = script.Parent.Prefabs.Activator

local Handler = {}

-- ----------------------------- ------- REQUIRED IMPLEMENTATIONS -------- -----------------------------

function Handler.Instantiate(nodes)
	local model = Shared.Instantiate(Prefab, nodes)
	model.LogicalState = { IsAnyOutputActive = false, IsToggled = false }
	return model
end

function Handler.UpdateVisuals(model, visuals)
	local main = model.Instance.Main
	
	main.Color = visuals.MainColor
	main.Material = visuals.MainMaterial

	local greenBase = model.Instance.GreenBase
	local pivot = model.Instance:GetPivot()
	
	local activeEdges = Shared.PlaceNodes(model, visuals)
	Shared.ResizeAndCenter(greenBase, Prefab.GreenBase, pivot, activeEdges)
end

function Handler.Destroy(model)
	return Shared.Destroy(model)
end

-- ----------------------------- -------------- TRIGGERS ----------------- -----------------------------

local function MainTargetY(instance, toggled: boolean)
	return instance.Stem:GetPivot().Position.Y + instance.Main.Size.Y / 2
		+ if toggled
		then 0.201
		else 0.5
end

function Handler.OnStateChanged(model, action)
	model.LogicalState.IsToggled = action.Active

	local main = model.Instance.Main
	local info = if action.Active then TW_PRESS_INFO else TW_RELEASE_INFO
	model.Tracks.Start("toggle", function()
		local tween = TweenService:Create(main, info, { Position = Vector3.new(main.Position.X, MainTargetY(model.Instance, action.Active), main.Position.Z) })
		tween:Play()
		return function()
			tween:Cancel()
			tween:Destroy()
		end
	end)
end

function Handler.OnOutputSignalChanged(model, action)
	model.LogicalState.IsAnyOutputActive = action.AnyActive
	
	-- No animations, just a glow. No need for a track here.
	model.Instance.Main.DisplayNameGui.TextLabel.TextStrokeTransparency = if action.AnyActive then 0 else 1
end

local Dispatch = {
	OutputSignals = Handler.OnOutputSignalChanged,
	Activator = Handler.OnStateChanged,
}

function Handler.Trigger(model, action)
	if not action then return end
	local actionHandler = Dispatch[action.Source]
	if actionHandler then actionHandler(model, action) end
end

-- ----------------------------- ---------- STATE RESTORATION ------------ -----------------------------

function Handler.ApplyLogicalState(model, state)
	-- Set text stroke
	model.Instance.Main.DisplayNameGui.TextLabel.TextStrokeTransparency = if state.IsAnyOutputActive then 0 else 1
	
	-- Set main position
	local main = model.Instance.Main
	main.Position = Vector3.new(
		main.Position.X,
		MainTargetY(model.Instance, state.IsToggled),
		main.Position.Z
	)
end

-- ----------------------------- ------------ END OF MODULE -------------- -----------------------------

return Handler
