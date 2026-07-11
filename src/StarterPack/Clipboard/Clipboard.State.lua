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

-- Visuals
local highlightPrefab: SelectionBox = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("ClipboardHighlight")
local guiPrefab: ScreenGui & any = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("ClipboardGui")
local slotPrefab: Frame & any = guiPrefab.SaveSlotPrefab

-- References
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local gatesFolder = Workspace:WaitForChild("Gates")
local ghostPrefab: Model = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("GhostPrefab")

-- Gate detections
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

-- Events
local getSavesDataQuery: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Queries"):WaitForChild("GetSavesData")
local saveEvent: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("Save")
local loadEvent: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("Load")
local eraseEvent: RemoteFunction= ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("EraseSave")

-- State definition
local State = {}
State.__index = State

-- ----------------------------- ------------ HELPER METHODS ------------- -----------------------------

local function toGridEdgePosition(position)
	return Vector3.new(math.round(position.X - 1) + 1, math.round(position.Y), math.round(position.Z - 1) + 1)
end

local function getConnectionCount(c)
	local count = 0
	for _ in pairs(c) do count += 1 end
	return count
end

-- ----------------------------- ------------- SAVE BUTTON --------------- -----------------------------

function State:Save()
	if #self.highlights <= 0 then
		MessageService.SendMessage("Select at least 1 gate to save a circuit")
		return
	end
	
	local saveName = tostring(self.gui.Frame["4_SaveButton"]["0_SaveName"].Text)
		:gsub("[%c]", "")
		:gsub("^%s+", "")
	local match = string.match(saveName, "^[%a_][%w _%-#]*$")
	if #saveName < 1 or #saveName > 30 or match == nil then
		MessageService.SendMessage("Save name should start with a letter, be under 30 characters and include only letters, numbers, spaces and some symbols")
		return
	end
	
	MessageService.SendColouredMessage("Saving...", Color3.new(1, 0.4, 0.2))
	local success, message, result = saveEvent:InvokeServer(saveName, self.gates)
	if not success then
		MessageService.SendMessage(message)
	else
		MessageService.SendColouredMessage("Success!", Color3.new(0, 1, 0))
		self.savesData[saveName] = result
	end
	return success
end

-- ----------------------------- ----------- ERASE SAFEGUARD ------------- -----------------------------

function State:DestroyErasePrompt()
	if self.gui then
		self.gui.Frame.Interactable = true
	end
	
	if self.erasePrompt then
		self.erasePrompt.Visible = false
		self.erasePrompt["4_Erase"]["0_SaveName"].Text = ""
		self.erasePrompt = nil
	end
	
	if self.erasePromptConnection then
		self.erasePromptConnection:Disconnect()
		self.erasePromptConnection = nil
	end
end

function State:CreateErasePrompt(saveIdentifier: string)
	self.erasePrompt = self.gui.ErasePrompt
	self.erasePrompt.Visible = true
	self.gui.Frame.Interactable = false
	
	local frame = self.erasePrompt["4_Erase"]
	self.erasePromptConnection = (frame["1_EraseButton"] :: TextButton).Activated:Connect(function()
		local textInput = frame["0_SaveName"]
		if textInput.Text ~= saveIdentifier then
			MessageService.SendMessage("Wrong Save Name! Be sure of what you want to delete. Re-equip the tool, or try again with the name.")
		else
			local success, message = eraseEvent:InvokeServer(saveIdentifier)
			if not success then
				MessageService.SendMessage(message)
			else
				MessageService.SendColouredMessage("Save erased!", Color3.new(0, 1, 0))
				self.savesData[saveIdentifier] = nil
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
	
	if self.gui then
		self.gui.Frame.Interactable = true
	end
end

function State:LoadGhost()
	local saveData = self.savesData[self.currentSave]
	assert(saveData, "Save name does not match any entry!")
	
	local ghostModel = Instance.new("Model")
	ghostModel.Name = "SaveGhost"
	
	local G = saveData.G
	for id, data in ipairs(G) do
		local ghost: Model = ghostPrefab:Clone()
		ghost.Name = "Ghost"
		ghost:PivotTo(data.CFrame._cframe)
		
		ghost.Parent = ghostModel
	end
	
	ghostModel.WorldPivot = CFrame.new()
	
	if PointerService.HitPosition then
		ghostModel.Parent = Workspace
		ghostModel:PivotTo(GridService.fromCFrame(CFrame.new(PointerService.HitPosition))._cframe)
	else
		ghostModel.Parent = nil
	end
	
	self.ghostMouseConnection = RunService.RenderStepped:Connect(function()
		if PointerService.HitPosition then
			ghostModel.Parent = Workspace
			ghostModel:PivotTo(GridService.fromCFrame(CFrame.new(PointerService.HitPosition))._cframe)
		else
			ghostModel.Parent = nil
		end
	end)
	self.ghostRotationConnection = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.R then ghostModel.WorldPivot *= CFrame.Angles(0, math.rad(-90), 0) end
	end)
	
	self.ghostModel = ghostModel
	self.isPointingGhost = true
	
	self.gui.Frame.Interactable = false
end

-- ----------------------------- ------------- GUI METHODS --------------- -----------------------------

function State:DestroyGui()
	if self.gui then
		self:ClearGUISaveSlots()
		self.gui:Destroy()
		self.gui = nil
	end
	
	if self.guiConnections.SaveButton then
		self.guiConnections.SaveButton:Disconnect()
	end
	if self.guiConnections.SearchBar then
		self.guiConnections.SearchBar:Disconnect()
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
	
	if self.savesData == nil then return end
	
	for name, data in pairs(self.savesData) do
		local slot = slotPrefab:Clone()
		if self.guiSearchText ~= nil and name:sub(1, #self.guiSearchText):lower() ~= self.guiSearchText:lower() then continue end
		slot.Name = name .. "_slot"
		slot.NameLabel.Text = name
		slot.DataLabel.Text =
			tostring(#data.G) .. " Gates, " .. tostring(getConnectionCount(data.C)) .. " Wires. Saved: " .. get24HrsString(data.timestamp)
		slot.Visible = true
		slot.Parent = self.gui.Frame["2_SavesFrame"]["2_ScrollingFrame"]
		
		self.guiConnections.LoadButtons[name] = (slot.LoadButton :: TextButton).Activated:Connect(function()
			self.currentSave = name
			self:LoadGhost(name)
		end)
		
		self.guiConnections.EraseButtons[name] = (slot.EraseButton :: TextButton).Activated:Connect(function()
			self:CreateErasePrompt(name)
		end)
	end
end

function State:ClearGUISaveSlots()
	for _, connection in pairs(self.guiConnections.LoadButtons) do
		connection:Disconnect()
		connection = nil
	end
	for _, connection in pairs(self.guiConnections.EraseButtons) do
		connection:Disconnect()
		connection = nil
	end
	
	for _, child in ipairs(self.gui.Frame["2_SavesFrame"]["2_ScrollingFrame"]:GetChildren()) do
		if not child:IsA("Frame") then continue end
		child:Destroy()
	end
end

function State:UpdateGateCounter()
	self.gui.Frame["3_GateCount"].Label.Text = tostring(#self.highlights) .. " Circuits Selected" 
end

function State:BuildGui()
	local gui = guiPrefab:Clone() do
		gui.Parent = playerGui
		gui.Enabled = true
	end
	self.gui = gui
	
	self.guiSearchText = nil
	self:PopulateGUISaveSlots()
	
	self.guiConnections.SaveButton = (gui.Frame["4_SaveButton"]["1_SaveButton"] :: GuiButton).Activated:Connect(function()
		local success = self:Save()
		if not self.Equipped then return end
		if success then
			self:ClearGUISaveSlots()
			self:PopulateGUISaveSlots()
		end
	end)
	
	local searchBar: TextBox = gui.Frame["2_SavesFrame"]["1_SearchBar"]
	self.guiConnections.SearchBar = searchBar:GetPropertyChangedSignal("Text"):Connect(function()
		self.guiSearchText = searchBar.Text
		self:ClearGUISaveSlots()
		self:PopulateGUISaveSlots()
	end)
	
	self:UpdateGateCounter()
end

-- ----------------------------- --------- BOUNDING BOX METHODS ---------- -----------------------------

function State:UpdateBoundingBox()
	if not PointerService.HitPosition then return end
	
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
	local startPos = toGridEdgePosition(PointerService.HitPosition)
	local box = Instance.new("Part") do
		box.Name = "ClipboardZone"
		box.Parent = Workspace
		box.Anchored = true
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.Transparency = 1
		
		local visuals = highlightPrefab:Clone()
		visuals.Adornee = box
		visuals.Parent = box
		
		PointerService.AddToFilter(box)
	end
	
	self.boundingBox = box
	self.boundingBoxStartPos = startPos
	
	self:UpdateBoundingBox()
	self.boundingBoxUpdateConnection = RunService.RenderStepped:Connect(function()
		if self.isDragging then
			self:UpdateBoundingBox()
		end
	end)
end

function State:DestroyBoundingBox()
	if self.boundingBox then
		self.boundingBox:Destroy()
		self.boundingBox = nil
		
		self.boundingBoxStartPos = nil
		
		if self.boundingBoxUpdateConnection then
			self.boundingBoxUpdateConnection:Disconnect()
			self.boundingBoxUpdateConnection = nil
		end
	end
end

-- ----------------------------- -------- GATE HIGHLIGHT METHODS --------- -----------------------------

function State:UpdateHighlights()
	self:DestroyHighlights()
	
	overlapParams.FilterDescendantsInstances = { gatesFolder }
	
	local parts = Workspace:GetPartBoundsInBox(self.boundingBox.CFrame, self.boundingBox.Size, overlapParams)
	for _, part in ipairs(parts) do
		local gate = part:FindFirstAncestorWhichIsA("Model")
		if gate == nil then continue end
		
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
	if next(self.highlights) ~= nil then
		for _, highlight in ipairs(self.highlights) do
			highlight:Destroy()
		end
		self.highlights = {}
	end
	
	if next(self.gates) ~= nil then
		table.clear(self.gates)
		self.gates = {}
	end
end

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new(player: Player, character: Model)
	local self = setmetatable({}, State)
	self.Player = player
	
	self.Equipped = false
	
	self.isDragging = false
	self.isPointingGhost = false
	
	self.ghostModel = nil
	self.ghostMouseConnection = nil
	self.ghostRotationConnection = nil
	
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
	
	self.savesData = nil
	
	self.currentSave = nil
	
	return self
end

function State:Enter()
	self.Equipped = true
	
	local success, result = getSavesDataQuery:InvokeServer()
	if not success then
		warn("Failed to fetch server data for player " .. tostring(Players.LocalPlayer.UserId))
		MessageService.SendMessage(result)
	else
		self.savesData = result
	end
	if not self.Equipped then return end
	
	self:BuildGui()
end

function State:Activated()
	if not self.gui then return end
	if not self.isDragging and not self.isPointingGhost then
		self:DestroyBoundingBox()
		if not PointerService.HitPosition then return end
		
		self:StartBoundingBox()
		
		self.isDragging = true
	end
	if self.isPointingGhost then
		if not PointerService.HitPosition then return end
		self:DestroyGhost()
		
		local success, message = loadEvent:InvokeServer(self.currentSave)
		if not success then
			MessageService.SendMessage(message)
		end
		self.currentSave = nil
	end
end

function State:Deactivated()
	if not self.gui then return end
	if self.isDragging then
		self.isDragging = false
	end
end

function State:Exit()
	self:DestroyGui()
	self:DestroyErasePrompt()
	self:DestroyBoundingBox()
	self:DestroyHighlights()
	self:DestroyGhost()
	
	self.Equipped = false
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
