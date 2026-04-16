--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local LocalServices = StarterPlayerScripts.Services

local PointerService = require(LocalServices.PointerService)
local MessageService = require(LocalServices.MessageService)
local ClipboardMode = require(StarterPlayerScripts.Tool.ClipboardMode)
local ClipboardUI = require(StarterPlayerScripts.Tool.ClipboardUI)
local GridService = require(ReplicatedStorage.Services.GridService)

local clientFolder = ReplicatedStorage:WaitForChild("Client")
local gatesFolder = clientFolder:WaitForChild("Gates")
local queriesFolder = gatesFolder:WaitForChild("Queries")
local eventsFolder = gatesFolder:WaitForChild("Events")

local clipboardListRemote = queriesFolder:WaitForChild("ClipboardList") :: RemoteFunction
local clipboardSaveRemote = eventsFolder:WaitForChild("ClipboardSave") :: RemoteFunction
local clipboardRestoreRemote = eventsFolder:WaitForChild("ClipboardRestore") :: RemoteFunction

local Tool = script.Parent

local function setStatusForSelection()
	if not ClipboardMode.HasSelection() then
		ClipboardUI.SetStatus("Click once to place the first corner of the box.")
	elseif ClipboardMode.IsLocked() then
		ClipboardUI.SetStatus("Selection locked. Save it, or click again to start a new box.")
	else
		ClipboardUI.SetStatus("Move the cursor to size the box, then click again to lock it.")
	end
end

local function refreshBuilds()
	local success, message, builds = clipboardListRemote:InvokeServer()
	if not success then
		ClipboardUI.SetStatus(message or "Couldn't refresh the clipboard.", true)
		return
	end

	ClipboardUI.SetBuilds(builds or {})
end

local function onSave(title: string)
	local minBounds, maxBounds = ClipboardMode.GetSelectionBounds()
	if minBounds == nil or maxBounds == nil then
		MessageService.SendMessage("Draw a selection box before saving.")
		ClipboardUI.SetStatus("Draw a selection box before saving.", true)
		return
	end

	local success, message, builds = clipboardSaveRemote:InvokeServer(title, minBounds, maxBounds)
	if not success then
		MessageService.SendMessage(message or "Failed to save selection.")
		ClipboardUI.SetStatus(message or "Failed to save selection.", true)
		return
	end

	ClipboardUI.SetBuilds(builds or {})
	ClipboardUI.SetStatus("Saved '" .. title .. "' to the clipboard.")
end

local function onRestore(title: string)
	if PointerService.HitPosition == nil then
		MessageService.SendMessage("Point at the board to choose where to restore the build.")
		ClipboardUI.SetStatus("Point at the board before restoring.", true)
		return
	end

	local anchor = GridService.fromCFrame(CFrame.new(PointerService.HitPosition))._cframe
	local success, message, builds = clipboardRestoreRemote:InvokeServer(title, anchor)
	if not success then
		MessageService.SendMessage(message or "Failed to restore build.")
		ClipboardUI.SetStatus(message or "Failed to restore build.", true)
		return
	end

	ClipboardUI.SetBuilds(builds or {})
	ClipboardUI.SetStatus("Restored '" .. title .. "' at the current cursor position.")
end

local function onReset()
	ClipboardMode.ClearSelection()
	setStatusForSelection()
end

local function equipped()
	ClipboardMode.Start()
	ClipboardUI.Open({
		OnSave = onSave,
		OnRestore = onRestore,
		OnRefresh = refreshBuilds,
		OnReset = onReset,
	})
	refreshBuilds()
	setStatusForSelection()
end

local function unequipped()
	ClipboardUI.Close()
	ClipboardMode.Stop()
end

local function activated()
	local success, message = ClipboardMode.AdvanceSelection()
	if not success then
		MessageService.SendMessage(message or "Couldn't place clipboard selection.")
		ClipboardUI.SetStatus(message or "Couldn't place clipboard selection.", true)
		return
	end

	setStatusForSelection()
end

Tool.Equipped:Connect(equipped)
Tool.Unequipped:Connect(unequipped)
Tool.Activated:Connect(activated)
