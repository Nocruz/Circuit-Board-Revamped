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
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local LocalServices = StarterPlayerScripts.Services
local PointerService = require(LocalServices.PointerService)
local MessageService = require(LocalServices.MessageService)

-- Visuals
local highlightPrefab: SelectionBox = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("ClipboardHighlight")
local guiPrefab: ScreenGui & any = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("ClipboardGui")
local slotPrefab: Frame & any = guiPrefab.SaveSlotPrefab

-- References
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local gatesFolder = Workspace:WaitForChild("Gates")

-- Gate detections
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

-- Events
local getSavesDataQuery: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Queries"):WaitForChild("GetSavesData")
local saveEvent: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("Save")

-- State definition
local State = {}
State.__index = State

-- ----------------------------- ------------ HELPER METHODS ------------- -----------------------------

local function toGridEdgePosition(position)
	return Vector3.new(math.round(position.X - 1) + 1, math.round(position.Y), math.round(position.Z - 1) + 1)
end

-- ----------------------------- ----------- EVENTS HANDLING ------------- -----------------------------

function State:ErasePrompt()
	error("Not implemented!")
end

function State:LoadGhost()
	error("Not implemented!")
end

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
	
	local success, result = saveEvent:InvokeServer(saveName, self.gates)
	if not success or result then
		MessageService.SendMessage(result)
	end
	return success
end

-- ----------------------------- ------------- GUI METHODS --------------- -----------------------------

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
		slot.Name = name .. "_slot"
		slot.NameLabel.Text = name
		slot.DataLabel.Text =
			tostring(#data.gates) .. " Gates, " .. tostring(#data.connections) .. " Wires. Saved: " .. get24HrsString(data.timestamp)
		slot.Visible = true
		slot.Parent = self.gui.Frame["2_SavesFrame"]["2_ScrollingFrame"]
		
		self.guiConnections.LoadButtons[name] = (slot.LoadButton :: TextButton).Activated:Connect(function()
			self:LoadGhost()
		end)
		
		self.guiConnections.EraseButtons[name] = (slot.EraseButton :: TextButton).Activated:Connect(function()
			self:ErasePrompt(name)
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
	
	self:PopulateGUISaveSlots()
	
	self.guiConnections.SaveButton = (gui.Frame["4_SaveButton"]["1_SaveButton"] :: GuiButton).Activated:Connect(function()
		self:Save()
	end)
	
	self:UpdateGateCounter()
end

function State:DestroyGui()
	if self.gui then
		self:ClearGUISaveSlots()
		self.gui:Destroy()
		self.gui = nil
	end
	
	if self.guiConnections.SaveButton then
		self.guiConnections.SaveButton:Disconnect()
	end
	self.guiConnections = {
		SaveButton = nil,
		LoadButtons = {},
		EraseButtons = {},
	}
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
	
	self.boundingBox = nil
	self.boundingBoxStartPos = nil
	self.boundingBoxEndPos = nil
	self.boundingBoxUpdateConnection = nil
	
	self.highlights = {}
	self.gates = {}
	
	self.gui = nil
	self.guiConnections = {
		SaveButton = nil,
		LoadButtons = {},
		EraseButtons = {},
	}
	
	self.savesData = nil
	
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
	if not self.isDragging then
		self:DestroyBoundingBox()
		if not PointerService.HitPosition then return end
		
		self:StartBoundingBox()
		
		self.isDragging = true
	end
end

function State:Deactivated()
	if self.isDragging then
		self.isDragging = false
	end
end

function State:Exit()
	self:DestroyGui()
	self:DestroyBoundingBox()
	self:DestroyHighlights()
	
	self.Equipped = false
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
