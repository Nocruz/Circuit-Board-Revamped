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

local clipboardListRemote = queriesFolder:WaitForChild("ClipboardList") :: RemoteFunction
local clipboardPreviewRemote = queriesFolder:WaitForChild("ClipboardPreview") :: RemoteFunction
local clipboardSaveRemote = eventsFolder:WaitForChild("ClipboardSave") :: RemoteFunction
local clipboardLoadRemote = eventsFolder:WaitForChild("ClipboardLoad") :: RemoteFunction
local clipboardDeleteRemote = eventsFolder:WaitForChild("ClipboardDelete") :: RemoteFunction
local destroyAllRemote = eventsFolder:WaitForChild("DestroyAll") :: RemoteFunction

local Tool = script.Parent

local deathConnection: RBXScriptConnection?
local equipped = false

local function disconnectDeathConnection()
	if deathConnection then
		deathConnection:Disconnect()
		deathConnection = nil
	end
end

local function normalizeSaveName(rawName: string): string
	local stripped = rawName:gsub("[%c]", "")
	return string.sub(stripped:match("^%s*(.-)%s*$") or "", 1, 32)
end

local function getIdleStatus(): string
	if ClipboardMode.IsLoadPlacementArmed() then
		local selectedSave = ClipboardUI.GetSelectedSaveName()
		if selectedSave then
			return "Click a point to place '" .. selectedSave .. "'."
		end
		return "Click a point to place the selected save."
	end

	if ClipboardMode.IsDragging() then
		return "Release to finish the selection box."
	end

	local selectionCount = ClipboardMode.GetSelectionCount()
	local saveName = normalizeSaveName(ClipboardUI.GetSaveName())
	local selectedSave = ClipboardUI.GetSelectedSaveName()

	if selectionCount > 0 and saveName ~= "" then
		return string.format("%d gates selected. Save as '%s' or choose a stored save to load.", selectionCount, saveName)
	end
	if selectionCount > 0 then
		return string.format("%d gates selected. Enter a save name to store them.", selectionCount)
	end
	if selectedSave then
		return "Selected save: '" .. selectedSave .. "'."
	end
	if ClipboardMode.HasSelectionBox() then
		return "No gates were inside that box."
	end

	return "Drag across the board to select gates."
end

local function syncUiState(customStatus: string?, isError: boolean?)
	local saveName = normalizeSaveName(ClipboardUI.GetSaveName())
	local selectedSave = ClipboardUI.GetSelectedSaveName()
	local loadArmed = ClipboardMode.IsLoadPlacementArmed()

	local canSave = ClipboardMode.GetSelectionCount() > 0 and saveName ~= "" and not loadArmed
	local canLoad = selectedSave ~= nil and not loadArmed
	local canErase = selectedSave ~= nil and not loadArmed

	ClipboardUI.SetSaveEnabled(canSave)
	ClipboardUI.SetLoadEnabled(canLoad)
	ClipboardUI.SetLoadArmed(loadArmed)
	ClipboardUI.SetEraseEnabled(canErase)
	ClipboardUI.SetStatus(customStatus or getIdleStatus(), isError)
end

local function resetState(customStatus: string?)
	ClipboardMode.Reset()
	syncUiState(customStatus)
end

local function refreshSaves(preferredSelection: string?)
	local success, message, saves = clipboardListRemote:InvokeServer()
	if not success then
		syncUiState(message or "Couldn't refresh clipboard saves.", true)
		return false
	end

	ClipboardUI.SetSaves(saves or {})
	if preferredSelection then
		for _, summary in ipairs(saves or {}) do
			if summary.Title == preferredSelection then
				ClipboardUI.SetSelectedSaveName(preferredSelection)
				break
			end
		end
	end
	syncUiState()
	return true
end

local function onSave(saveName: string)
	local normalizedSaveName = normalizeSaveName(saveName)
	local gateIds = ClipboardMode.GetSelectedGateIds()

	if normalizedSaveName == "" then
		syncUiState("Give the save a name first.", true)
		return
	end
	if #gateIds == 0 then
		syncUiState("Select at least one gate before saving.", true)
		return
	end

	local success, message, saves = clipboardSaveRemote:InvokeServer(normalizedSaveName, gateIds)
	if not success then
		MessageService.SendMessage(message or "Failed to save clipboard build.")
		syncUiState(message or "Failed to save clipboard build.", true)
		return
	end

	ClipboardUI.SetSaves(saves or {})
	ClipboardUI.SetSelectedSaveName(normalizedSaveName)
	syncUiState("Saved '" .. normalizedSaveName .. "'.")
end

local function onLoad(saveName: string)
	if ClipboardMode.IsLoadPlacementArmed() then
		ClipboardMode.CancelLoadPlacement()
		syncUiState()
		return
	end

	local normalizedSaveName = normalizeSaveName(saveName)
	if normalizedSaveName == "" then
		syncUiState("Pick a save first.", true)
		return
	end

	local success, message, previewData = clipboardPreviewRemote:InvokeServer(normalizedSaveName)
	if not success then
		MessageService.SendMessage(message or "Couldn't preview that save.")
		syncUiState(message or "Couldn't preview that save.", true)
		return
	end

	ClipboardUI.SetSelectedSaveName(normalizedSaveName)
	ClipboardMode.ArmLoadPlacement(previewData)
	syncUiState()
end

local function onErase(saveName: string)
	local normalizedSaveName = normalizeSaveName(saveName)
	if normalizedSaveName == "" then
		syncUiState("Pick a save first.", true)
		return
	end

	if ClipboardMode.IsLoadPlacementArmed() then
		ClipboardMode.CancelLoadPlacement()
	end

	local success, message, saves = clipboardDeleteRemote:InvokeServer(normalizedSaveName)
	if not success then
		MessageService.SendMessage(message or "Couldn't erase that save.")
		syncUiState(message or "Couldn't erase that save.", true)
		return
	end

	ClipboardUI.SetSaves(saves or {})
	ClipboardUI.SetSelectedSaveName(nil)
	syncUiState("Erased '" .. normalizedSaveName .. "'.")
end

local function onDestroyAll()
	if ClipboardMode.IsLoadPlacementArmed() then
		ClipboardMode.CancelLoadPlacement()
	end
	
	local success, message = destroyAllRemote:InvokeServer()
	if not success then
		MessageService.SendMessage(message or "Failed to destroy all gates.")
		syncUiState(message or "Failed to destroy all gates.", true)
		return
	end
	
	resetState("All gates destroyed.")
end

local function onSelectionChanged(saveName: string?)
	if ClipboardMode.IsLoadPlacementArmed() then
		ClipboardMode.CancelLoadPlacement()
	end

	ClipboardUI.SetSelectedSaveName(saveName)
	syncUiState()
end

local function onSaveNameChanged(_saveName: string)
	syncUiState()
end

local function bindDeathReset(character: Model)
	disconnectDeathConnection()

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid == nil then
		return
	end

	deathConnection = humanoid.Died:Connect(function()
		resetState("Clipboard selection reset.")
	end)
end

local function onEquipped()
	equipped = true
	ClipboardMode.Start()
	ClipboardUI.Open({
		OnSave = onSave,
		OnLoad = onLoad,
		OnErase = onErase,
		OnSelectionChanged = onSelectionChanged,
		OnSaveNameChanged = onSaveNameChanged,
		OnDestroyAll = onDestroyAll,
	})

	local character = player.Character
	if character then
		bindDeathReset(character)
	end

	resetState()
	refreshSaves()
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
		local selectedSave = ClipboardUI.GetSelectedSaveName()
		if selectedSave == nil then
			syncUiState("Pick a save first.", true)
			return
		end

		local hitPosition = PointerService.HitPosition
		if hitPosition == nil then
			MessageService.SendMessage("Point at a valid spot to place the saved build.")
			syncUiState("Point at a valid spot to place the saved build.", true)
			return
		end

		local anchorCFrame = GridService.fromCFrame(CFrame.new(hitPosition))._cframe
		local rotatedAnchor = anchorCFrame * ClipboardMode.getRotationCFrame() -- rotates in anchor's local space
		local success, message = clipboardLoadRemote:InvokeServer(selectedSave, rotatedAnchor)
		resetState()
		if not success then
			MessageService.SendMessage(message or "Failed to load clipboard save.")
			syncUiState(message or "Failed to load clipboard save.", true)
			return
		end

		syncUiState("Loaded '" .. selectedSave .. "' at the clicked point.")
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
