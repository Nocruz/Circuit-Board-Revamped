--[[ NEEDLE TOOL
		Tool used to edit gate's attributes.
]]

-- Requires and services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local LocalServices = StarterPlayerScripts.Services
local PointerService = require(LocalServices.PointerService)
local MessageService = require(LocalServices.MessageService)
local EffectsService = require(ReplicatedStorage:WaitForChild("EffectsService"))

-- Visuals
local highlightPrefab: SelectionBox = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("NeedleHighlight")
local guiPrefab: BillboardGui = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("NeedleGUI")

-- References
local serverGatesFolder = Workspace:WaitForChild("Gates"):WaitForChild("Server")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Events
local getDataQuery: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Queries"):WaitForChild("GetAttributeData")
local changeAttributesEvent: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("SetAttributes")

-- State definition
local State = {}
State.__index = State

-- ----------------------------- --------- LRU ATTRIBUTES -------- ------------------------------

local AttributeCache = {
	_cache = {},
	_order = {},
	MAX_SIZE = 10
}

function AttributeCache.get(gateID: number)
	local data = AttributeCache._cache[gateID]
	if data then
		local index = table.find(AttributeCache._order, gateID)
		if index then table.remove(AttributeCache._order, index) end
		table.insert(AttributeCache._order, gateID)
	end
	return data
end

function AttributeCache.set(gateID: number, data: { any })
	local index = table.find(AttributeCache._order, gateID)
	if index then table.remove(AttributeCache._order, index) end
	
	table.insert(AttributeCache._order, gateID)
	AttributeCache._cache[gateID] = data
	
	if #AttributeCache._order > AttributeCache.MAX_SIZE then
		local oldestGateID = table.remove(AttributeCache._order, 1)
		AttributeCache._cache[oldestGateID] = nil
	end
end

function AttributeCache.invalidate(gateID: number)
	local index = table.find(AttributeCache._order, gateID)
	if index then table.remove(AttributeCache._order, index) end
	AttributeCache._cache[gateID] = nil
end

function AttributeCache.update(gateID: number, changes: { any })
	local data = AttributeCache._cache[gateID]
	if not data then return end
	
	local index = table.find(AttributeCache._order, gateID)
	if index then table.remove(AttributeCache._order, index) end
	table.insert(AttributeCache._order, gateID)
	
	for name, value in pairs(changes) do
		local attribute = data[name]
		if not attribute then return end
		
		local originalType = typeof(attribute.Value)
		if originalType == "number" then
			attribute.Value = tonumber(value) or attribute.Value
		elseif originalType == "boolean" then
			if value == "true" then attribute.Value = true end
			if value == "false" then attribute.Value = false end
		else
			attribute.Value = value
		end
	end
end

-- ----------------------------- --------- HELPER METHODS -------- ------------------------------

function State:ApplyState()
	if not self.IsEquipped or not self.SelectedGate or not self.SelectedGate.Parent then return end
	
	local frame = self.Gui:FindFirstChild("Frame")
	local scrollingFrame = frame and frame:FindFirstChild("ScrollingFrame")
	if not scrollingFrame then return end
	
	local changes = {}
	for _, row: Instance in ipairs(scrollingFrame:GetChildren()) do
		if not row:IsA("Frame") then continue end
		local valueHolder = row:FindFirstChild("TextBox") or row:FindFirstChild("TextButton")
		if valueHolder and (valueHolder:IsA("TextBox") or valueHolder:IsA("TextButton")) then
			changes[row.Name] = valueHolder.Text
		end
	end
	
	if next(changes) == nil then return end
	
	local gateID = self.SelectedGate:GetAttribute("GateID")
	if not gateID then return end
	
	task.spawn(function()
		local success, result = changeAttributesEvent:InvokeServer(gateID, changes)
		if success then AttributeCache.update(gateID, changes) end
		
		if self.IsEquipped and not success then MessageService.SendMessage(result) end
	end)
end

function State:OpenGUI(gate: Instance)
	if not self.IsEquipped or not self.HoveredGate or not self.HoveredGate.Parent then return end
	
	self:DestroyGUI()
	self.SelectedGate = gate
	
	self.Gui = guiPrefab:Clone()
	self.Gui.Adornee = self.SelectedGate
	self.Gui.GateName.Text = self.SelectedGate.Name
	self.Gui.Parent = playerGui
	
	EffectsService.PlaySFX("Open Needle")
end

function State:PopulateGUI(attributesData)
	if not self.IsEquipped or not self.Gui then return end
	
	local frame = self.Gui:FindFirstChild("Frame")
	local scrollingFrame = frame and frame:FindFirstChild("ScrollingFrame")
	if not scrollingFrame then return end
	
	self.GuiClosedConnection = self.Gui.ApplyButton.Activated:Connect(function()
		self:ApplyState()
		self:DestroyGUI()
	end)
	
	self.GuiTogglersConnections = {}
	
	-- Instantiate all the attribute frame editors
	for name, data in pairs(attributesData) do
		if data.AllowedValues == nil then
			local row: Frame & any = self.Gui.InputAttributePrefab:Clone()
			row.Visible = true
			row.Name = name
			row.TextLabel.Text = name
			row.TextBox.Text = tostring(data.Value)
			row.Parent = scrollingFrame
		elseif #data.AllowedValues > 0 then
			local row: Frame & any = self.Gui.ToggleAttributePrefab:Clone()
			row.Visible = true
			row.Name = name
			row.TextLabel.Text = name
			row.TextButton.Text = tostring(data.Value)
			row.Parent = scrollingFrame
			row:SetAttribute("AllowedValues_Index", table.find(data.AllowedValues, data.Value))
			
			table.insert(self.GuiTogglersConnections, row.TextButton.Activated:Connect(function()
				if not self.IsEquipped or not row:GetAttribute("AllowedValues_Index") then return end
				local newIndex = ((row:GetAttribute("AllowedValues_Index") :: number) % #data.AllowedValues) + 1
				row.TextButton.Text = tostring(data.AllowedValues[newIndex])
				row:SetAttribute("AllowedValues_Index", newIndex)
			end))
		end
	end
end

function State:DestroyGUI()
	if self.GuiClosedConnection ~= nil then
		self.GuiClosedConnection:Disconnect()
		self.GuiClosedConnection = nil
	end
	
	if self.GuiTogglersConnections then
		for _, connection in ipairs(self.GuiTogglersConnections) do
			connection:Disconnect()
		end
		table.clear(self.GuiTogglersConnections)
		self.GuiTogglersConnections = nil
	end
	
	if self.Gui then
		self.Gui:Destroy()
		self.Gui = nil
		EffectsService.PlaySFX("Close Needle")
	end
	
	self.SelectedGate = nil
end

function State:ResetHighlight()
	if self.HoveredGateHighlight then
		self.HoveredGateHighlight.Adornee = nil
		self.HoveredGateHighlight.Parent = nil
	end
	if self.HoveredGate then
		self.HoveredGate = nil
	end
end

function State:SetHighlight(gate: Instance)
	if not self.IsEquipped or not gate or not gate.Parent then return end
	if gate:IsDescendantOf(serverGatesFolder) then return end
	
	self.HoveredGate = gate
	if self.HoveredGateHighlight then
		self.HoveredGateHighlight.Adornee = gate
		self.HoveredGateHighlight.Parent = gate
	end
end

function State:UpdateHighlight(gate: Model?)
	if not self.IsEquipped then return end
	
	if not gate or not gate.Parent then
		self:ResetHighlight()
	elseif self.HoveredGate ~= gate then
		self:ResetHighlight()
		self:SetHighlight(gate)
	end
end

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new(player: Player)
	local self = setmetatable({}, State)
	self.Player = player
	
	self.HoverConnection = nil
	
	self.HoveredGate = nil
	self.HoveredGateHighlight = nil
	
	self.Gui = nil
	self.GuiClosedConnection = nil
	self.GuiTogglersConnections = nil
	self.SelectedGate = nil
	
	self.IsEquipped = true
	
	return self
end

function State:Enter()
	self.HoveredGateHighlight = highlightPrefab:Clone()
	
	self.HoverConnection = PointerService.OnHoverChanged:Connect(function(_, gate)
		if not self.IsEquipped then return end
		self:UpdateHighlight(gate)
	end)
	self:UpdateHighlight(PointerService.HoveredGate)
end

function State:Activated()
	if not self.IsEquipped then return end
	
	local clickedGate = self.HoveredGate
	if clickedGate and clickedGate.Parent and clickedGate ~= self.SelectedGate then
		local gateID = self.HoveredGate:GetAttribute("GateID")
		if not gateID then return end
		
		self:OpenGUI(clickedGate)
		
		local cachedData = AttributeCache.get(gateID)
		if cachedData then
			self:PopulateGUI(cachedData)
			return
		end
		
		local gateAtRequestTime = clickedGate
		task.spawn(function()
			local success, result = getDataQuery:InvokeServer(gateID)
			if not self.IsEquipped then return end
		
			if self.SelectedGate == gateAtRequestTime then
				if not success then
					MessageService.SendMessage(result)
					self:DestroyGUI()
					return
				end
				
				if not result or typeof(result) ~= "table" or next(result) == nil then
					MessageService.SendMessage("Gate has no attributes to change!")
					self:DestroyGUI()
					return
				end
				
				AttributeCache.set(gateID, result)
				self:PopulateGUI(result)
			end
		end)
	end
end

function State:Deactivated()
end

function State:Exit()
	if not self.IsEquipped then return end
	self.IsEquipped = false
	
	self:ResetHighlight()
	self:DestroyGUI()
	
	if self.HoverConnection then
		self.HoverConnection:Disconnect()
		self.HoverConnection = nil
	end
	
	if self.HoveredGateHighlight then
		self.HoveredGateHighlight:Destroy()
		self.HoveredGateHighlight = nil
	end
	
	table.clear(self)
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
