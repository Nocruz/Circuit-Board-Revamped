--[[ CLIPBOARD TOOL
		Drag the cursor to form a bounding box.
		Use the bounding box to save circuits to a named slot.
		
		Load or Erase slots using the Gui.
]]

-- Requires and services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local LocalServices = StarterPlayerScripts.Services
local GridService = require(ReplicatedStorage.GridService)
local PointerService = require(LocalServices.PointerService)
local MessageService = require(LocalServices.MessageService)
local ClipboardRegistry = require(LocalServices.ClipboardRegistry)

-- Visuals
local highlightPrefab: Highlight = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("ClipboardHighlight")
local selectionBoxPrefab: SelectionBox = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("ClipboardSelectionBox")
local guiPrefab: ScreenGui & any = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("ClipboardGui")
local slotPrefab: Frame & any = guiPrefab.SaveSlotPrefab

-- References
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local gatesFolder = Workspace:WaitForChild("Gates")
local serverGatesFolder = gatesFolder:WaitForChild("Server")
local ghostPrefab: Model = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("GhostPrefab")

-- Gate detections
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

-- Events
local saveEvent: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("Save")
local loadEvent: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("Load")
local eraseEvent: RemoteFunction= ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("EraseSave")

-- Cooldown flag
local globalLoadCooldownEnd = 0

-- State definition
local State = {}
State.__index = State

-- ----------------------------- ------------ HELPER METHODS ------------- -----------------------------

local function toGridEdgePosition(position)
	return Vector3.new(math.round(position.X - 1) + 1, math.round(position.Y), math.round(position.Z - 1) + 1)
end

local function getConnectionCount(c)
	--- C is a table of [fromGateID]: { [fromNodeName]: { [toGateID]: { NodeNames } } }
	local count = 0
	for _, outputs in pairs(c) do
		for _, toGates in pairs(outputs) do
			for _, nodes in pairs(toGates) do
				count += #nodes
			end
		end
	end
	return count
end

-- ----------------------------- ------------- SAVE BUTTON --------------- -----------------------------

function State:Save()
	if not self.IsEquipped or not self.gui then return end
	
	if #self.highlights <= 0 then
		MessageService.SendMessage("Select at least 1 gate to save a circuit")
		return
	end
	
	local frame = self.gui:FindFirstChild("Frame")
	local saveButtonFrame = frame and frame:FindFirstChild("4_SaveButton")
	local saveNameInput = saveButtonFrame and saveButtonFrame:FindFirstChild("0_SaveName")
	if not saveNameInput then
		warn("Something happened! [NO_SAVE_NAME_INPUT]")
		return
	end
	
	local saveName = tostring(saveNameInput.Text)
		:gsub("[%c]", "")
		:gsub("^%s+", "")
	local match = string.match(saveName, "^[%a_0-9][%w _%-#()]*$")
	if #saveName < 1 or #saveName > 30 or match == nil then
		MessageService.SendMessage("Save name should start with a letter, be under 30 characters and include only letters, numbers, spaces and some symbols")
		return
	end
	
	MessageService.SendColouredMessage("Saving...", Color3.new(1, 0.4, 0.2))
	
	local targetGates = {}
	for id, val in pairs(self.gates) do targetGates[id] = val end
	
	local success, message, result = saveEvent:InvokeServer(saveName, targetGates)
	if not self.IsEquipped then return end
	
	if not success then
		MessageService.SendMessage(message)
	else
		MessageService.SendColouredMessage("Success!", Color3.new(0, 1, 0))
		ClipboardRegistry:AddSave(saveName, result)
	end
	return success
end

-- ----------------------------- ----------- ERASE SAFEGUARD ------------- -----------------------------

function State:DestroyErasePrompt()
	if self.gui and self.gui:FindFirstChild("Frame") then
		self.gui.Frame.Interactable = true
	end
	
	if self.erasePrompt then
		local frame = self.erasePrompt:FindFirstChild("4_Erase")
		local nameInput = frame and frame:FindFirstChild("0_SaveName")
		if nameInput then nameInput.Text = "" end
		self.erasePrompt.Visible = false
		self.erasePrompt = nil
	end
	
	if self.erasePromptConnection then
		self.erasePromptConnection:Disconnect()
		self.erasePromptConnection = nil
	end
end

function State:CreateErasePrompt(saveIdentifier: string)
	if not self.IsEquipped or not self.gui then return end
	self:DestroyBoundingBox()
	
	local erasePrompt = self.gui:FindFirstChild("ErasePrompt")
	if not erasePrompt then
		warn("Something happened! [NO_ERASE_PROMPT]")
		return
	end
	self.erasePrompt = erasePrompt
	self.erasePrompt.Visible = true
	self.gui.Frame.Interactable = false
	
	local frame = self.erasePrompt:FindFirstChild("4_Erase")
	local eraseButton = frame and frame:FindFirstChild("1_EraseButton") :: TextButton
	if not eraseButton then
		warn("Something happened! [NO_ERASE_PROMPT_BUTTON]")
		return
	end
	
	self.erasePromptConnection = eraseButton.Activated:Connect(function()
		if not self.IsEquipped then return end
		
		local textInput = frame:FindFirstChild("0_SaveName")
		if not textInput then
			warn("Something happened! [NO_ERASE_PROMPT_TEXT_INPUT]")
			return
		end
		
		if textInput.Text ~= saveIdentifier then
			MessageService.SendMessage("Wrong Save Name! Be sure of what you want to delete. Re-equip the tool, or try again with the name.")
		else
			local success, message = eraseEvent:InvokeServer(saveIdentifier)
			if not self.IsEquipped then return end
			
			if not success then
				MessageService.SendMessage(message)
			else
				MessageService.SendColouredMessage("Save erased!", Color3.new(0, 1, 0))
				ClipboardRegistry:RemoveSave(saveIdentifier)
				self:ClearGUISaveSlots()
				self:PopulateGUISaveSlots()
			end
			self:DestroyErasePrompt()
		end
	end)
end

-- ----------------------------- ------------- GHOST STUFF --------------- -----------------------------

function State:DestroyGhost()
	self.isPointingGhost = false
	
	if self.ghostModel then
		self.ghostModel:Destroy()
		self.ghostModel = nil
	end
	
	if self.ghostMouseConnection then
		self.ghostMouseConnection:Disconnect()
		self.ghostMouseConnection = nil
	end
	
	if self.ghostRotationConnection then
		self.ghostRotationConnection:Disconnect()
		self.ghostRotationConnection = nil
	end
	
	if self.gui and self.gui:FindFirstChild("Frame") then
		self.gui.Frame.Interactable = true
	end
	
	self.ghostRotation = nil
end

function State:LoadGhost()
	if not self.IsEquipped or not ClipboardRegistry.IsLoaded or not self.currentSave then return end
	self:DestroyBoundingBox()
	
	local saveData = ClipboardRegistry:GetSave(self.currentSave)
	if not saveData then
		warn("Save name does not match any entry!")
		return
	end
	
	local ghostModel = Instance.new("Model")
	ghostModel.Name = "SaveGhost"
	
	local G = saveData.G
	for _, data in ipairs(G) do
		local ghost: Model & any = ghostPrefab:Clone()
		ghost.Name = "Ghost"
		ghost:PivotTo(data.CFrame._cframe)
		if data.Specification and data.Specification == "SPLITTER" then
			ghost.Base.Size = Vector3.new(6, 0.2, 2)
			ghost.Main.Size = Vector3.new(6, 0.8, 2)
		end
		ghost.Parent = ghostModel
	end
	
	ghostModel.WorldPivot = CFrame.new()
	self.ghostRotation = CFrame.new()
	
	if PointerService.HitPosition then
		ghostModel.Parent = Workspace
		ghostModel:PivotTo(GridService.fromCFrame(CFrame.new(PointerService.HitPosition))._cframe)
	else
		ghostModel.Parent = nil
	end
	
	self.ghostMouseConnection = RunService.RenderStepped:Connect(function()
		if not self.IsEquipped then return end
		
		if PointerService.HitPosition then
			ghostModel.Parent = Workspace
			ghostModel:PivotTo(GridService.fromCFrame(CFrame.new(PointerService.HitPosition))._cframe)
		else
			ghostModel.Parent = nil
		end
	end)
	
	self.ghostRotationConnection = UserInputService.InputBegan:Connect(function(input, gp)
		if not self.IsEquipped or gp then return end
		if input.KeyCode == Enum.KeyCode.R then
			ghostModel.WorldPivot *= CFrame.Angles(0, math.rad(-90), 0)
			self.ghostRotation *= CFrame.Angles(0, math.rad(90), 0)
		end
	end)
	
	self.ghostModel = ghostModel
	self.isPointingGhost = true
	
	if self.gui and self.gui:FindFirstChild("Frame") then
		self.gui.Frame.Interactable = false
	end
end

-- ----------------------------- ------------- GUI METHODS --------------- -----------------------------

function State:UpdateLoadButtonsVisuals(remainingTime)
	if not self.gui then return end
	local frame = self.gui:FindFirstChild("Frame")
	local savesFrame = frame and frame:FindFirstChild("2_SavesFrame")
	local scrollingFrame = savesFrame and savesFrame:FindFirstChild("2_ScrollingFrame")
	if not scrollingFrame then return end

	for _, child in ipairs(scrollingFrame:GetChildren()) do
		if child:IsA("Frame") then
			local loadBtn = child:FindFirstChild("LoadButton") :: TextButton
			if loadBtn then
				if remainingTime > 0 then
					loadBtn.Interactable = false
					loadBtn.Text = "Wait (" .. remainingTime .. "s)"
				else
					loadBtn.Interactable = true
					loadBtn.Text = "Load"
				end
			end
		end
	end
end

function State:StartLoadCooldown()
	globalLoadCooldownEnd = os.clock() + 3
	
	if self.isCoolingDown then return end
	self.isCoolingDown = true
	
	task.spawn(function()
		while self.IsEquipped and os.clock() < globalLoadCooldownEnd do
			local remaining = math.ceil(globalLoadCooldownEnd - os.clock())
			self:UpdateLoadButtonsVisuals(remaining)
			task.wait(0.1)
		end
		
		if self.IsEquipped then
			self.isCoolingDown = false
			self:UpdateLoadButtonsVisuals(0)
		end
	end)
end

function State:DestroyGui()
	self:ClearGUISaveSlots()
	
	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
	
	if self.guiConnections then
		if self.guiConnections.SaveButton then self.guiConnections.SaveButton:Disconnect() end
		if self.guiConnections.SearchBar then self.guiConnections.SearchBar:Disconnect() end
	end
	self.guiConnections = {
		SaveButton = nil,
		SearchBar  = nil,
		LoadButtons = {},
		EraseButtons = {},
	}
	
	self.guiSearchText = nil
end

function State:PopulateGUISaveSlots()
	if not self.IsEquipped or not self.gui or not ClipboardRegistry.IsLoaded then return end
	
	local function get24HrsString(timestamp)
		local d = os.date("*t", timestamp)
		return string.format(
			"%02d/%02d/%02d %02d:%02d:%02d",
			d.day,
			d.month,
			d.year % 100,
			d.hour,
			d.min,
			d.sec
		)
	end

	local frame = self.gui:FindFirstChild("Frame")
	local savesFrame = frame and frame:FindFirstChild("2_SavesFrame")
	local scrollingFrame = savesFrame and savesFrame:FindFirstChild("2_ScrollingFrame")
	if not scrollingFrame then return end
	
	local savesData = ClipboardRegistry:GetAllSaves()
	for name, data in pairs(savesData) do
		if self.guiSearchText ~= nil and name:sub(1, #self.guiSearchText):lower() ~= self.guiSearchText:lower() then continue end
		
		local slot = slotPrefab:Clone()
		slot.Name = name .. "_slot"
		slot.NameLabel.Text = name
		slot.DataLabel.Text = tostring(#data.G) .. " Gates, " .. tostring(getConnectionCount(data.C)) .. " Wires. Saved: " .. get24HrsString(data.timestamp)
		slot.Visible = true
		slot.Parent = scrollingFrame
		
		local loadBtn = slot.LoadButton :: TextButton
		
		if os.clock() < globalLoadCooldownEnd then
			loadBtn.Interactable = false
			loadBtn.Text = "Wait (" .. math.ceil(globalLoadCooldownEnd - os.clock()) .. "s)"
		else
			loadBtn.Interactable = true
			loadBtn.Text = "Load"
		end
		
		self.guiConnections.LoadButtons[name] = loadBtn.Activated:Connect(function()
			if not self.IsEquipped then return end
			self.currentSave = name
			self:LoadGhost(name)
		end)
		
		self.guiConnections.EraseButtons[name] = (slot.EraseButton :: TextButton).Activated:Connect(function()
			if not self.IsEquipped then return end
			self:CreateErasePrompt(name)
		end)
	end
end

function State:ClearGUISaveSlots()
	if self.guiConnections then
		if self.guiConnections.LoadButtons then
			for _, connection in pairs(self.guiConnections.LoadButtons) do
				connection:Disconnect()
				connection = nil
			end
			table.clear(self.guiConnections.LoadButtons)
		end
		if self.guiConnections.EraseButtons then
			for _, connection in pairs(self.guiConnections.EraseButtons) do
				connection:Disconnect()
				connection = nil
			end
			table.clear(self.guiConnections.EraseButtons)
		end
	end
	
	if self.gui and self.gui:FindFirstChild("Frame") then
		local savesFrame = self.gui.Frame:FindFirstChild("2_SavesFrame")
		local scrollingFrame = savesFrame and savesFrame:FindFirstChild("2_ScrollingFrame")
		if not scrollingFrame then
			warn("Something happened! [NO_SAVES_SCROLLING_FRAME]")
			return
		end
		
		for _, child in ipairs(scrollingFrame:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end
end

function State:UpdateGateCounter()
	if not self.IsEquipped or not self.gui then return end
	local frame = self.gui:FindFirstChild("Frame")
	local gateCountFrame = frame and frame:FindFirstChild("3_GateCount")
	local gateCountLabel = gateCountFrame and gateCountFrame:FindFirstChild("Label")
	if not gateCountLabel then
		warn("Something happened! [NO GATE_COUNT_LABEL]")
		return
	end
	gateCountLabel.Text = tostring(#self.highlights) .. " Circuits Selected" 
end

function State:BuildGui()
	if not self.IsEquipped then return end
	
	local gui = guiPrefab:Clone() do
		gui.Enabled = true
		gui.Parent = playerGui
	end
	self.gui = gui
	
	self.guiSearchText = nil
	self:PopulateGUISaveSlots()
	
	local frame = gui:FindFirstChild("Frame")
	local saveButtonFrame = frame and frame:FindFirstChild("4_SaveButton")
	local saveActionButton = 	saveButtonFrame and saveButtonFrame:FindFirstChild("1_SaveButton") :: GuiButton
	if not saveActionButton then
		warn("Something happened! [NO SAVE_ACTION_BUTTON]")
		return
	end
	self.guiConnections.SaveButton = saveActionButton.Activated:Connect(function()
		if not self.IsEquipped then return end
		local success = self:Save()
		if not self.IsEquipped then return end
		if success then
			self:ClearGUISaveSlots()
			self:PopulateGUISaveSlots()
			self:DestroyBoundingBox()
		end
	end)
	
	local savesFrame = frame and frame:FindFirstChild("2_SavesFrame")
	local searchBar = savesFrame and savesFrame:FindFirstChild("1_SearchBar") :: TextBox
	if not searchBar then
		warn("Something happened! [NO SEARCH_BAR]")
		return
	end
	self.guiConnections.SearchBar = searchBar:GetPropertyChangedSignal("Text"):Connect(function()
		if not self.IsEquipped then return end
		self.guiSearchText = searchBar.Text
		self:ClearGUISaveSlots()
		self:PopulateGUISaveSlots()
	end)
	
	self:UpdateGateCounter()
end

-- ----------------------------- --------- BOUNDING BOX METHODS ---------- -----------------------------

function State:UpdateBoundingBox()
	if not self.IsEquipped or not self.boundingBox or not PointerService.HitPosition then return end
	
	local pointA, pointB = self.boundingBoxStartPos, toGridEdgePosition(PointerService.HitPosition)
	if pointB == self.boundingBoxEndPos then return end
	
	self.boundingBoxEndPos = pointB
	local startPoint = Vector3.new(math.min(pointA.X, pointB.X), math.min(pointA.Y, pointB.Y), math.min(pointA.Z, pointB.Z))
	local endPoint = Vector3.new(math.max(pointA.X, pointB.X), math.max(pointA.Y, pointB.Y), math.max(pointA.Z, pointB.Z))
	
	self.boundingBox.Size = endPoint - startPoint
	self.boundingBox.CFrame = CFrame.new((startPoint + endPoint) / 2)
	
	self:UpdateHighlights()
end

function State:StartBoundingBox()
	if not self.IsEquipped or not PointerService.HitPosition then return end
	local startPos = toGridEdgePosition(PointerService.HitPosition)
	local box = Instance.new("Part") do
		box.Name = "ClipboardZone"
		box.Anchored = true
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.Transparency = 1
		
		local visuals = selectionBoxPrefab:Clone()
		visuals.Adornee = box
		visuals.Parent = box
		
		PointerService.AddToFilter(box)
		box.Parent = Workspace
	end
	
	self.boundingBox = box
	self.boundingBoxStartPos = startPos
	
	self:UpdateBoundingBox()
	self.boundingBoxUpdateConnection = RunService.RenderStepped:Connect(function()
		if not self.IsEquipped then return end
		if self.isDragging then
			self:UpdateBoundingBox()
		end
	end)
end

function State:DestroyBoundingBox()
	self:DestroyHighlights()
	if self.boundingBox then
		self.boundingBox:Destroy()
		self.boundingBox = nil
	end
	
	self.boundingBoxStartPos = nil
	
	if self.boundingBoxUpdateConnection then
		self.boundingBoxUpdateConnection:Disconnect()
		self.boundingBoxUpdateConnection = nil
	end
end

-- ----------------------------- -------- GATE HIGHLIGHT METHODS --------- -----------------------------

function State:UpdateHighlights()
	if not self.IsEquipped or not self.boundingBox then return end
	self:DestroyHighlights()
	
	overlapParams.FilterDescendantsInstances = { gatesFolder }
	
	local parts = Workspace:GetPartBoundsInBox(self.boundingBox.CFrame, self.boundingBox.Size, overlapParams)
	for _, part in ipairs(parts) do
		local gate = part:FindFirstAncestorWhichIsA("Model")
		if gate == nil then continue end
		if gate:IsDescendantOf(serverGatesFolder) then continue end
		
		local id = gate:GetAttribute("GateID")
		if id == nil or type(id) ~= "number" then continue end 
		if self.gates[id] then continue end
		
		self.gates[id] = true
		local highlight = highlightPrefab:Clone() do
			highlight.Name = "GateHighlight"
			highlight.Adornee = gate
			highlight.Parent = gate
		end
		table.insert(self.highlights, highlight)
	end
	
	self:UpdateGateCounter()
end

function State:DestroyHighlights()
	if self.highlights ~= nil then
		for _, highlight in ipairs(self.highlights) do
			if highlight then highlight:Destroy() end
		end
		table.clear(self.highlights)
	end
	
	if self.gates ~= nil then
		table.clear(self.gates)
	end
end

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new(player: Player)
	local self = setmetatable({}, State)
	self.Player = player
	
	self.IsEquipped = true
	
	self.isDragging = false
	self.isPointingGhost = false
	
	self.ghostModel = nil
	self.ghostMouseConnection = nil
	self.ghostRotationConnection = nil
	self.ghostRotation = nil
	
	self.boundingBox = nil
	self.boundingBoxStartPos = nil
	self.boundingBoxEndPos = nil
	self.boundingBoxUpdateConnection = nil
	
	self.highlights = {}
	self.gates = {}
	
	self.gui = nil
	self.guiConnections = {
		SaveButton = nil,
		SearchBar  = nil,
		LoadButtons = {},
		EraseButtons = {},
	}
	self.guiSearchText = nil
	
	self.erasePrompt = nil
	self.erasePromptConnection = nil
	
	self.currentSave = nil
	
	return self
end

function State:Enter()
	local success, result = ClipboardRegistry:LoadAsync()
	if not self.IsEquipped then return end
	
	if not success then
		warn("Failed to fetch server data for player " .. tostring(Players.LocalPlayer.UserId))
		MessageService.SendMessage(result)
	else
		self:BuildGui()
		
		if os.clock() < globalLoadCooldownEnd then
			self:StartLoadCooldown()
		end
	end
end

function State:Activated()
	if not self.IsEquipped or not self.gui then return end
	
	if not self.isDragging and not self.isPointingGhost then
		self:DestroyBoundingBox()
		if not PointerService.HitPosition then return end
		
		self:StartBoundingBox()
		self.isDragging = true
	end
	
	if self.isPointingGhost and self.ghostModel then
		if not PointerService.HitPosition then return end
		
		local saveCFrame = self.ghostModel:GetPivot() * (self.ghostRotation or CFrame.new())
		local targetSave = self.currentSave
		
		self.currentSave = nil
		self:DestroyGhost()
		
		self:StartLoadCooldown()
		
		local success, message = loadEvent:InvokeServer(targetSave, saveCFrame)
		if not self.IsEquipped then return end
		
		if not success then
			MessageService.SendMessage(message)
		elseif message ~= nil then
			MessageService.SendColouredMessage(message, Color3.new(1, 0.4, 0.2))
		end
	end
end

function State:Deactivated()
	if not self.IsEquipped or not self.gui then return end
	
	self.isDragging = false
end

function State:Exit()
	if not self.IsEquipped then return end
	self.IsEquipped = false
	
	self:DestroyErasePrompt()
	self:DestroyGui()
	self:DestroyBoundingBox()
	self:DestroyHighlights()
	self:DestroyGhost()
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
