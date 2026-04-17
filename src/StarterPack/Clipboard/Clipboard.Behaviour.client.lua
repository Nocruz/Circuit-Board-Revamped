--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local LocalServices = StarterPlayerScripts.Services

local PointerService = require(LocalServices.PointerService)
local MessageService = require(LocalServices.MessageService)
local ClipboardMode = require(StarterPlayerScripts.Tool.ClipboardMode)
local ClipboardUI = require(StarterPlayerScripts.Tool.ClipboardUI)
local GridService = require(ReplicatedStorage.Services.GridService)

local player = Players.LocalPlayer
local clientFolder = ReplicatedStorage:WaitForChild("Client")
local queriesFolder = clientFolder:WaitForChild("Queries")
local eventsFolder = clientFolder:WaitForChild("Events")

local clipboardHasSaveRemote = queriesFolder:WaitForChild("ClipboardHasSave") :: RemoteFunction
local clipboardPreviewRemote = queriesFolder:WaitForChild("ClipboardPreview") :: RemoteFunction
local clipboardSaveRemote = eventsFolder:WaitForChild("ClipboardSave") :: RemoteFunction
local clipboardLoadRemote = eventsFolder:WaitForChild("ClipboardLoad") :: RemoteFunction

local Tool = script.Parent

local deathConnection: RBXScriptConnection?
local hasStoredSave = false
local equipped = false

local function disconnectDeathConnection()
	if deathConnection then
		deathConnection:Disconnect()
		deathConnection = nil
	end
end

local function getIdleStatus(): string
	if ClipboardMode.IsLoadPlacementArmed() then
		return "Click a point to place the saved draft."
	end
	if ClipboardMode.IsDragging() then
		return "Release to finish the selection box."
	end

	local selectionCount = ClipboardMode.GetSelectionCount()
	if selectionCount > 0 then
		return string.format("%d gates selected. Save the draft or arm load placement.", selectionCount)
	end
	if ClipboardMode.HasSelectionBox() then
		return "No gates were inside that box."
	end

	return "Drag across the board to select gates."
end

local function syncUiState(customStatus: string?, isError: boolean?)
	local canSave = ClipboardMode.GetSelectionCount() > 0 and not ClipboardMode.IsLoadPlacementArmed()
	ClipboardUI.SetSaveEnabled(canSave)
	ClipboardUI.SetLoadArmed(ClipboardMode.IsLoadPlacementArmed())
	ClipboardUI.SetStatus(customStatus or getIdleStatus(), isError)
end

local function resetState(customStatus: string?)
	ClipboardMode.Reset()
	syncUiState(customStatus)
end

local function refreshStoredDraft(): boolean
	local success, result = clipboardHasSaveRemote:InvokeServer()
	if not success then
		hasStoredSave = false
		syncUiState((result :: string?) or "Couldn't check clipboard draft state.", true)
		return false
	end

	hasStoredSave = result == true
	return true
end

local function onSave()
	local gateIds = ClipboardMode.GetSelectedGateIds()
	if #gateIds == 0 then
		syncUiState("Select at least one gate before saving.", true)
		return
	end

	local success, message = clipboardSaveRemote:InvokeServer(gateIds)
	if not success then
		MessageService.SendMessage(message or "Failed to save clipboard draft.")
		syncUiState(message or "Failed to save clipboard draft.", true)
		return
	end

	hasStoredSave = true
	syncUiState(string.format("Saved draft with %d gates.", #gateIds))
end

local function onLoad()
	if ClipboardMode.IsLoadPlacementArmed() then
		ClipboardMode.CancelLoadPlacement()
		syncUiState()
		return
	end

	if not hasStoredSave then
		ClipboardUI.FlashLoadUnavailable()
		syncUiState("Save a draft before loading it.", true)
		return
	end

	local success, message, previewData = clipboardPreviewRemote:InvokeServer()
	if not success then
		if message == "No clipboard draft has been saved yet." then
			hasStoredSave = false
			ClipboardUI.FlashLoadUnavailable()
		end
		syncUiState(message or "Couldn't build clipboard preview.", true)
		return
	end

	ClipboardMode.ArmLoadPlacement(previewData)
	syncUiState()
end

local function bindDeathReset(character: Model)
	disconnectDeathConnection()

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end

	deathConnection = humanoid.Died:Connect(function()
		resetState("Clipboard draft reset.")
	end)
end

local function onEquipped()
	equipped = true
	ClipboardMode.Start()
	ClipboardUI.Open({
		OnSave = onSave,
		OnLoad = onLoad,
	})

	local character = player.Character
	if character then
		bindDeathReset(character)
	end

	resetState()
	refreshStoredDraft()
end

local function onUnequipped()
	equipped = false
	disconnectDeathConnection()
	ClipboardMode.Stop()
	ClipboardUI.Close()
end

local function onActivated()
	if not equipped then
		return
	end

	if ClipboardMode.IsLoadPlacementArmed() then
		local hitPosition = PointerService.HitPosition
		if hitPosition == nil then
			MessageService.SendMessage("Point at a valid spot to place the saved draft.")
			syncUiState("Point at a valid spot to place the saved draft.", true)
			return
		end

		local anchorCFrame = GridService.fromCFrame(CFrame.new(hitPosition))._cframe
		local success, message = clipboardLoadRemote:InvokeServer(anchorCFrame)
		resetState()
		if not success then
			MessageService.SendMessage(message or "Failed to load clipboard draft.")
			if message == "No clipboard draft has been saved yet." then
				hasStoredSave = false
			end
			syncUiState(message or "Failed to load clipboard draft.", true)
			return
		end

		syncUiState("Loaded the saved draft at the clicked point.")
		return
	end

	local success, message = ClipboardMode.BeginDrag()
	if not success then
		MessageService.SendMessage(message or "Couldn't start the clipboard selection.")
		syncUiState(message or "Couldn't start the clipboard selection.", true)
		return
	end

	syncUiState()
end

local function onDeactivated()
	if not equipped or ClipboardMode.IsLoadPlacementArmed() then
		return
	end

	local success, message = ClipboardMode.EndDrag()
	if not success then
		if message then
			MessageService.SendMessage(message)
			syncUiState(message, true)
		end
		return
	end

	syncUiState(message)
end

player.CharacterAdded:Connect(function(character)
	if equipped then
		bindDeathReset(character)
		resetState()
	end
end)

Tool.Equipped:Connect(onEquipped)
Tool.Unequipped:Connect(onUnequipped)
Tool.Activated:Connect(onActivated)
Tool.Deactivated:Connect(onDeactivated)
