--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local PointerService = require(StarterPlayerScripts.Services.PointerService)
local GridService = require(ReplicatedStorage.Services.GridService)

local ClipboardMode = {}

local GATES_FOLDER = workspace:WaitForChild("Gates")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local HIDDEN_CFRAME = CFrame.new(0, -1000, 0)

type TSerializedVector3 = {
	X: number,
	Y: number,
	Z: number,
}

type TSerializedCFrame = {
	Position: TSerializedVector3,
	R00: number?,
	R01: number?,
	R02: number?,
	R10: number?,
	R11: number?,
	R12: number?,
	R20: number?,
	R21: number?,
	R22: number?,
}

type TPreviewGate = {
	CFrame: TSerializedCFrame,
}

type TPreviewData = {
	BaseCFrame: TSerializedCFrame,
	Gates: { TPreviewGate },
}

local selectionPart: Part?
local selectionOutline: SelectionBox?
local renderConnection: RBXScriptConnection?

local selectedHighlights: { SelectionBox } = {}
local selectedGateIds: { number } = {}
local previewFolder: Folder?
local previewGhosts: { BasePart } = {}
local previewData: TPreviewData?

local rotationSteps = 0
local inputConnection: RBXScriptConnection?

local anchorPoint: Vector3?
local lockedPoint: Vector3?
local dragging = false
local loadPlacementArmed = false

local function getSnappedPointerPosition(): Vector3?
	local hitPosition = PointerService.HitPosition
	if hitPosition == nil then
		return nil
	end

	return GridService.fromCFrame(CFrame.new(hitPosition)).Position
end

local function getActivePoint(): Vector3?
	if lockedPoint ~= nil then
		return lockedPoint
	end
	if dragging then
		return getSnappedPointerPosition()
	end
	return nil
end

local function deserializeVector3(data: TSerializedVector3): Vector3
	return Vector3.new(data.X or 0, data.Y or 0, data.Z or 0)
end

local function deserializeCFrame(data: TSerializedCFrame?): CFrame
	if data == nil or data.Position == nil then
		return CFrame.new()
	end

	local position = deserializeVector3(data.Position)
	if data.R00 == nil then
		return CFrame.new(position)
	end

	return CFrame.new(
		position.X, position.Y, position.Z,
		data.R00, data.R01 or 0, data.R02 or 0,
		data.R10 or 0, data.R11 or 1, data.R12 or 0,
		data.R20 or 0, data.R21 or 0, data.R22 or 1
	)
end

local function getSelectionExtents(): (Vector3?, Vector3?)
	local pointA = anchorPoint
	local pointB = getActivePoint()
	if pointA == nil or pointB == nil then
		return nil, nil
	end

	return Vector3.new(
		math.min(pointA.X, pointB.X),
		math.min(pointA.Y, pointB.Y),
		math.min(pointA.Z, pointB.Z)
	), Vector3.new(
		math.max(pointA.X, pointB.X),
		math.max(pointA.Y, pointB.Y),
		math.max(pointA.Z, pointB.Z)
	)
end

local function containsPoint(minBounds: Vector3, maxBounds: Vector3, point: Vector3): boolean
	return point.X >= minBounds.X
		and point.X <= maxBounds.X
		and point.Y >= minBounds.Y
		and point.Y <= maxBounds.Y
		and point.Z >= minBounds.Z
		and point.Z <= maxBounds.Z
end

local function isGateModel(instance: Instance): boolean
	return instance:IsA("Model")
		and instance:GetAttribute("GateId") ~= nil
		and instance:FindFirstChild("Base") ~= nil
		and instance:FindFirstChild("Decoration") ~= nil
		and instance:FindFirstChild("Nodes") ~= nil
end

local function clearHighlights()
	for _, highlight in ipairs(selectedHighlights) do
		highlight:Destroy()
	end
	table.clear(selectedHighlights)
	table.clear(selectedGateIds)
end

local function clearPreviewGhosts()
	for _, ghost in ipairs(previewGhosts) do
		ghost:Destroy()
	end
	table.clear(previewGhosts)
end

local function ensurePreviewFolder(): Folder?
	if previewFolder and previewFolder.Parent ~= nil then
		return previewFolder
	end

	previewFolder = Instance.new("Folder")
	previewFolder.Name = "ClipboardGhostPreview"
	previewFolder.Parent = PointerService.RaycastFilter
	return previewFolder
end

local function hidePreviewGhosts()
	for _, ghost in ipairs(previewGhosts) do
		ghost:PivotTo(HIDDEN_CFRAME)
	end
end

-- Compute bounding box from preview data gates
-- Returns: minX, minY, minZ, maxX, maxY, maxZ
local function computePreviewBoundingBox(data: TPreviewData?): (number, number, number, number, number, number)
	if data == nil or data.Gates == nil or #data.Gates == 0 then
		return 0, 0, 0, 0, 0, 0
	end

	local first = true
	local minX, minY, minZ, maxX, maxY, maxZ = 0, 0, 0, 0, 0, 0

	for _, gatePreview in ipairs(data.Gates) do
		local gateCFrame = deserializeCFrame(gatePreview.CFrame)
		local pos = gateCFrame.Position

		if first then
			minX, minY, minZ = pos.X, pos.Y, pos.Z
			maxX, maxY, maxZ = pos.X, pos.Y, pos.Z
			first = false
		else
			if pos.X < minX then minX = pos.X end
			if pos.Y < minY then minY = pos.Y end
			if pos.Z < minZ then minZ = pos.Z end
			if pos.X > maxX then maxX = pos.X end
			if pos.Y > maxY then maxY = pos.Y end
			if pos.Z > maxZ then maxZ = pos.Z end
		end
	end

	return minX, minY, minZ, maxX, maxY, maxZ
end

-- Get the pivot offset from BaseCFrame to bottom-center of bounding box
-- Returns: Vector3 offset (BaseCFrame.Position -> bottom-center pivot)
local function getPivotOffset(data: TPreviewData?): Vector3
	if data == nil then
		return Vector3.new(0, 0, 0)
	end

	local baseCFrame = deserializeCFrame(data.BaseCFrame)
	local minX, minY, minZ, maxX, maxY, maxZ = computePreviewBoundingBox(data)

	-- Bottom-center pivot: (centerX, minY, centerZ)
	local centerX = (minX + maxX) / 2
	local centerZ = (minZ + maxZ) / 2
	local bottomCenterPivot = Vector3.new(centerX, minY, centerZ)

	-- Offset from BaseCFrame position to bottom-center
	return bottomCenterPivot - baseCFrame.Position
end

local function rebuildPreviewGhosts()
	clearPreviewGhosts()

	if previewData == nil then
		return
	end

	local ghostPrefab = ReplicatedStorage:WaitForChild("Ghost")
	if ghostPrefab == nil or not ghostPrefab:IsA("BasePart") then
		return
	end

	local folder = ensurePreviewFolder()
	if folder == nil then
		return
	end

	for index, _ in ipairs(previewData.Gates) do
		local ghost = ghostPrefab:Clone() :: BasePart
		ghost.Name = "ClipboardGhost_" .. tostring(index)
		ghost.Anchored = true
		ghost.CanCollide = false
		ghost.CanTouch = false
		ghost.CanQuery = false
		ghost:PivotTo(HIDDEN_CFRAME)
		ghost.Parent = folder
		table.insert(previewGhosts, ghost)
	end
end

local function updatePreviewVisual()
	if not loadPlacementArmed then
		hidePreviewGhosts()
		return
	end

	if previewData == nil or #previewGhosts == 0 then
		return
	end

	local hitPosition = PointerService.HitPosition
	if hitPosition == nil then
		hidePreviewGhosts()
		return
	end

	-- compute anchor and base as before (grid-aligned)
	local anchorCFrame = GridService.fromCFrame(CFrame.new(hitPosition))._cframe
	local baseCFrame = deserializeCFrame(previewData.BaseCFrame)

	-- Get the pivot offset (from BaseCFrame to bottom-center)
	local pivotOffset = getPivotOffset(previewData)

	-- Translation: position so bottom-center is at anchor
	local translation = anchorCFrame.Position - baseCFrame.Position - pivotOffset
	local offsetCFrame = CFrame.new(translation)

	-- rotation about the anchor's local Y axis
	local rot = ClipboardMode.getRotationCFrame() -- rotation relative to anchor's local axes
	local rotateAroundAnchor = anchorCFrame * rot * anchorCFrame:Inverse()

	-- apply rotation-around-anchor to each ghost
	for index, gatePreview in ipairs(previewData.Gates) do
    local ghost = previewGhosts[index]
    if ghost then
      local gateLocal = deserializeCFrame(gatePreview.CFrame)
      local worldCFrame = offsetCFrame * gateLocal
      ghost:PivotTo(rotateAroundAnchor * worldCFrame)
    end
	end
end

local function updateSelectionVisual()
	if selectionPart == nil then
		return
	end

	if loadPlacementArmed then
		selectionPart.Parent = nil
		if selectionOutline then
			selectionOutline.Visible = false
		end
		return
	end

	local minBounds, maxBounds = getSelectionExtents()
	if minBounds == nil or maxBounds == nil then
		selectionPart.Parent = nil
		if selectionOutline then
			selectionOutline.Visible = false
		end
		return
	end

	local expandedMin = minBounds - Vector3.new(0.5, 0.5, 0.5)
	local expandedMax = maxBounds + Vector3.new(0.5, 0.5, 0.5)

	selectionPart.Size = expandedMax - expandedMin
	selectionPart.CFrame = CFrame.new((expandedMin + expandedMax) * 0.5)
	selectionPart.Parent = PointerService.RaycastFilter
	if selectionOutline then
		selectionOutline.Visible = true
	end
end

local function updateVisuals()
	updateSelectionVisual()
	updatePreviewVisual()
end

local function rebuildSelection()
	clearHighlights()

	local minBounds, maxBounds = getSelectionExtents()
	if minBounds == nil or maxBounds == nil then
		return
	end

	local gateModels = {}
	for _, instance in ipairs(GATES_FOLDER:GetDescendants()) do
		if isGateModel(instance) then
			table.insert(gateModels, instance)
		end
	end

	table.sort(gateModels, function(a, b)
		return (a:GetAttribute("GateId") :: number) < (b:GetAttribute("GateId") :: number)
	end)

	for _, gateModel in ipairs(gateModels) do
		local pivot = GridService.fromCFrame(gateModel:GetPivot()).Position
		if containsPoint(minBounds, maxBounds, pivot) then
			local gateId = gateModel:GetAttribute("GateId")
			if type(gateId) == "number" then
				local highlight = Instance.new("SelectionBox")
				highlight.Name = "ClipboardGateHighlight"
				highlight.Adornee = gateModel
				highlight.Color3 = Color3.fromRGB(75, 255, 135)
				highlight.SurfaceTransparency = 1
				highlight.LineThickness = 0.05
				highlight.Parent = playerGui

				table.insert(selectedHighlights, highlight)
				table.insert(selectedGateIds, gateId)
			end
		end
	end
end

local function rotateSteps(delta)
	rotationSteps = (rotationSteps + delta) % 4
	updateVisuals()
end

function ClipboardMode.Start()
	if selectionPart ~= nil then
		return
	end

	anchorPoint = nil
	lockedPoint = nil
	dragging = false
	loadPlacementArmed = false
	clearHighlights()

	selectionPart = Instance.new("Part")
	selectionPart.Name = "ClipboardSelection"
	selectionPart.Anchored = true
	selectionPart.CanCollide = false
	selectionPart.CanTouch = false
	selectionPart.CanQuery = false
	selectionPart.Material = Enum.Material.ForceField
	selectionPart.Color = Color3.fromRGB(255, 214, 102)
	selectionPart.Transparency = 0.82

	selectionOutline = Instance.new("SelectionBox")
	selectionOutline.Name = "ClipboardSelectionOutline"
	selectionOutline.Color3 = Color3.fromRGB(255, 214, 102)
	selectionOutline.LineThickness = 0.05
	selectionOutline.SurfaceTransparency = 1
	selectionOutline.Adornee = selectionPart
	selectionOutline.Parent = playerGui

	renderConnection = RunService.RenderStepped:Connect(updateVisuals)
	if not inputConnection then
    inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
	    if gameProcessed then return end
	    if not loadPlacementArmed then return end

	    if input.KeyCode == Enum.KeyCode.Q then
        rotateSteps(-1)
	    elseif input.KeyCode == Enum.KeyCode.E then
        rotateSteps(1)
	    end
    end)
	end
	updateVisuals()
end

function ClipboardMode.Stop()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end

	if inputConnection then
	    inputConnection:Disconnect()
	    inputConnection = nil
	end

	clearHighlights()
	clearPreviewGhosts()

	if selectionOutline then
		selectionOutline:Destroy()
		selectionOutline = nil
	end

	if selectionPart then
		selectionPart:Destroy()
		selectionPart = nil
	end

	if previewFolder then
		previewFolder:Destroy()
		previewFolder = nil
	end

	anchorPoint = nil
	lockedPoint = nil
	dragging = false
	loadPlacementArmed = false
	previewData = nil
end

function ClipboardMode.Reset()
	anchorPoint = nil
	lockedPoint = nil
	dragging = false
	loadPlacementArmed = false
	previewData = nil
	ClipboardMode.ResetRotation()
	clearHighlights()
	clearPreviewGhosts()
	updateVisuals()
end

function ClipboardMode.BeginDrag(): (boolean, string?)
	if loadPlacementArmed then
		return false, "Finish placing the saved draft first."
	end

	local point = getSnappedPointerPosition()
	if point == nil then
		ClipboardMode.Reset()
		return false, "Point at a valid spot to start the selection."
	end

	anchorPoint = point
	lockedPoint = nil
	dragging = true
	clearHighlights()
	updateVisuals()
	return true, nil
end

function ClipboardMode.EndDrag(): (boolean, string?)
	if not dragging then
		return false, nil
	end

	dragging = false

	local point = getSnappedPointerPosition()
	if anchorPoint == nil or point == nil then
		ClipboardMode.Reset()
		return false, "Selection cancelled."
	end

	lockedPoint = point
	updateVisuals()
	rebuildSelection()

	if #selectedGateIds == 0 then
		return true, "No gates were inside that box."
	end

	return true, nil
end

function ClipboardMode.RotateClockwise()
  rotateSteps(1)
end

function ClipboardMode.RotateCounterClockwise()
  rotateSteps(-1)
end

function ClipboardMode.GetRotationSteps(): number
  return rotationSteps
end

function ClipboardMode.ResetRotation()
  rotationSteps = 0
  updateVisuals()
end

function ClipboardMode.getRotationCFrame()
	return CFrame.Angles(0, math.rad(90 * rotationSteps), 0)
end

function ClipboardMode.ArmLoadPlacement(newPreviewData: TPreviewData?)
	loadPlacementArmed = true
	anchorPoint = nil
	lockedPoint = nil
	dragging = false
	previewData = newPreviewData
	clearHighlights()
	if selectionPart then
		selectionPart.Parent = nil
	end
	rebuildPreviewGhosts()
	updateVisuals()
end

function ClipboardMode.CancelLoadPlacement()
	loadPlacementArmed = false
	previewData = nil
	ClipboardMode.ResetRotation()
	clearPreviewGhosts()
	updateVisuals()
end

function ClipboardMode.IsLoadPlacementArmed(): boolean
	return loadPlacementArmed
end

function ClipboardMode.IsDragging(): boolean
	return dragging
end

function ClipboardMode.HasSelectionBox(): boolean
	return anchorPoint ~= nil and lockedPoint ~= nil
end

function ClipboardMode.GetSelectionCount(): number
	return #selectedGateIds
end

function ClipboardMode.GetSelectedGateIds(): { number }
	return table.clone(selectedGateIds)
end

return ClipboardMode
