--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local PointerService = require(StarterPlayerScripts.Services.PointerService)
local GridService = require(ReplicatedStorage.Services.GridService)

local ClipboardMode = {}

local selectionPart: Part?
local selectionOutline: SelectionBox?
local renderConnection: RBXScriptConnection?

local anchorPoint: Vector3?
local lockedPoint: Vector3?

local function getSnappedPointerPosition(): Vector3?
	local hitPosition = PointerService.HitPosition
	if hitPosition == nil then
		return nil
	end

	return GridService.fromCFrame(CFrame.new(hitPosition)).Position
end

local function getActivePoint(): Vector3?
	return lockedPoint or getSnappedPointerPosition()
end

local function getSelectionExtents(): (Vector3?, Vector3?)
	local pointA = anchorPoint
	local pointB = getActivePoint()
	if pointA == nil or pointB == nil then
		return nil, nil
	end

	return Vector3.new(math.min(pointA.X, pointB.X), math.min(pointA.Y, pointB.Y), math.min(pointA.Z, pointB.Z)),
		Vector3.new(math.max(pointA.X, pointB.X), math.max(pointA.Y, pointB.Y), math.max(pointA.Z, pointB.Z))
end

local function updateSelectionVisual()
	if selectionPart == nil then
		return
	end

	local minBounds, maxBounds = getSelectionExtents()
	if minBounds == nil or maxBounds == nil then
		selectionPart.Parent = nil
		return
	end

	local expandedMin = minBounds - Vector3.new(0.5, 0.5, 0.5)
	local expandedMax = maxBounds + Vector3.new(0.5, 0.5, 0.5)

	selectionPart.Size = expandedMax - expandedMin
	selectionPart.CFrame = CFrame.new((expandedMin + expandedMax) / 2)
	selectionPart.Parent = PointerService.RaycastFilter
end

function ClipboardMode.Start()
	if selectionPart ~= nil then
		return
	end

	anchorPoint = nil
	lockedPoint = nil

	selectionPart = Instance.new("Part")
	selectionPart.Name = "ClipboardSelection"
	selectionPart.Anchored = true
	selectionPart.CanCollide = false
	selectionPart.CanTouch = false
	selectionPart.CanQuery = false
	selectionPart.Material = Enum.Material.ForceField
	selectionPart.Color = Color3.fromRGB(255, 214, 102)
	selectionPart.Transparency = 0.8

	selectionOutline = Instance.new("SelectionBox")
	selectionOutline.Name = "ClipboardSelectionOutline"
	selectionOutline.Color3 = Color3.fromRGB(255, 214, 102)
	selectionOutline.LineThickness = 0.05
	selectionOutline.SurfaceTransparency = 1
	selectionOutline.Adornee = selectionPart
	selectionOutline.Parent = Players.LocalPlayer.PlayerGui

	renderConnection = RunService.RenderStepped:Connect(updateSelectionVisual)
	updateSelectionVisual()
end

function ClipboardMode.Stop()
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end

	if selectionOutline then
		selectionOutline:Destroy()
		selectionOutline = nil
	end

	if selectionPart then
		selectionPart:Destroy()
		selectionPart = nil
	end

	anchorPoint = nil
	lockedPoint = nil
end

function ClipboardMode.AdvanceSelection(): (boolean, string?)
	local point = getSnappedPointerPosition()
	if point == nil then
		return false, "Point at the board to place the selection."
	end

	if anchorPoint == nil then
		anchorPoint = point
		lockedPoint = nil
	elseif lockedPoint == nil then
		lockedPoint = point
	else
		anchorPoint = point
		lockedPoint = nil
	end

	updateSelectionVisual()
	return true, nil
end

function ClipboardMode.ClearSelection()
	anchorPoint = nil
	lockedPoint = nil
	updateSelectionVisual()
end

function ClipboardMode.GetSelectionBounds(): (Vector3?, Vector3?)
	return getSelectionExtents()
end

function ClipboardMode.HasSelection(): boolean
	local minBounds, maxBounds = getSelectionExtents()
	return minBounds ~= nil and maxBounds ~= nil
end

function ClipboardMode.IsLocked(): boolean
	return lockedPoint ~= nil
end

return ClipboardMode
