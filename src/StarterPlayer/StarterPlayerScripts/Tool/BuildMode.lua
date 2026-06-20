--[[ BUILD MODE
		Singleton that handles the "Building" state Supplies and Tweezers use.
		That means spawning the preview model, rotating it,
			snapping it to the grid, confirming the build,
			cancelling or destroying.
]]

-- Requires and services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local LocalServices = StarterPlayerScripts.Services

local PointerService = require(LocalServices.PointerService)
local GridService = require(ReplicatedStorage.GridService)

-- References
local Terrain = workspace:WaitForChild("Terrain")
local Baseplate = Terrain.Baseplate

-- Visuals
local BuildModeGuis = ReplicatedStorage.Client.UI.BuildMode
local baseHighlightPrefab: SelectionBox = BuildModeGuis.MoveBaseHighlight
local nameGuiPrefab: BillboardGui = BuildModeGuis.MoveNamePopup
local texture: Texture = BuildModeGuis.Grid

-- State
local rotation: number = 0
local preview: Model? = nil

local baseHighlight: SelectionBox? = nil
local nameGui : BillboardGui? = nil

local renderConnection: RBXScriptConnection? = nil

local BuildMode = { active = false}

-- ----------------------------- --------- HELPER METHODS -------- ------------------------------

local function showVisuals(model: Model)
	texture.Parent = Baseplate

	nameGui = nameGuiPrefab:Clone() :: any
	nameGui.Adornee = model
	nameGui.TextLabel.Text = model.Name
	nameGui.Parent = model
	nameGui.Enabled = true

	baseHighlight = baseHighlightPrefab:Clone() :: any
	baseHighlight.Adornee = model.PrimaryPart
	baseHighlight.Parent = model
	baseHighlight.Visible = true
end

local function hideVisuals()
	texture.Parent = nil

	if nameGui then
		nameGui:Destroy()
		nameGui = nil
	end

	if baseHighlight then
		baseHighlight:Destroy()
		baseHighlight = nil
	end
end

-- ----------------------------- ------ ON RENDER STEP EVENT ----- ------------------------------

local function movePreviewToCursor(preview: Model?)
	if not preview then
		log.info("No preview model?")
		return
	end
	
	if not PointerService.HitPosition then
		log.info("Pointing to the skybox")
		preview:PivotTo(CFrame.new(0, -100, 0))
		return
	end
	
	local cframe = GridService.fromCFrame(CFrame.new(PointerService.HitPosition) * CFrame.Angles(0, math.rad(rotation), 0))
	if PointerService.HoveredGate then
		cframe = GridService.Move(cframe, cframe.Position + GridService.getSurfaceNormal(PointerService.HitPosition, GridService.fromCFrame(PointerService.HoveredGate:GetPivot())))
	end
	preview:PivotTo(cframe._cframe)
	
	log.info("Moving model to " .. tostring(cframe.Position))
end

-- ----------------------------- ------------ ROTATION ----------- ------------------------------

game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
	if gp or not BuildMode.active then return end

	if input.KeyCode == Enum.KeyCode.R then 
		rotation = (rotation + 90) % 360
	end
end)

-- ----------------------------- ----------- LIFECYCLE ----------- ------------------------------

function BuildMode.Activate(gate: Model)
	preview = gate
	preview.Parent = PointerService.RaycastFilter
	
	do -- Rotate the preview model
		local _, radians = GridService.fromCFrame(preview:GetPivot())._cframe:ToOrientation()
		rotation = math.deg(radians)
	end
	
	showVisuals(preview)
		
	renderConnection = game:GetService("RunService").RenderStepped:Connect(function() movePreviewToCursor(preview) end )
	
	BuildMode.active = true
	log.info("BuildMode activated")
end

function BuildMode.Deactivate(): Model?
	local returnedPreview = preview
	
	hideVisuals()
	
	rotation = 0
	preview = nil
	
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	
	BuildMode.active = false
	log.info("BuildMode deactivated")
	
	return returnedPreview
end

-- ----------------------------- --------- END OF MODULE ---------- -----------------------------

return BuildMode
