--[[ NEEDLE TOOL
		Tool used to edit gate's attributes.
]]

-- Requires and services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local LocalServices = StarterPlayerScripts.Services
local PointerService = require(LocalServices.PointerService)
local MessageService = require(LocalServices.MessageService)

-- Visuals
local highlightPrefab: SelectionBox = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("NeedleHighlight")
local guiPrefab: BillboardGui = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("NeedleGUI")

-- References
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Events
local getDataQuery: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Queries"):WaitForChild("GetAttributeData")
local changeAttributesEvent: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("SetAttributes")

-- State definition
local State = {}
State.__index = State

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
	
	if next(changes) == nil then return true end
	
	local gateID = self.SelectedGate:GetAttribute("GateID")
	if not gateID then return end
	
	local success, result = changeAttributesEvent:InvokeServer(gateID, changes)
	if not self.IsEquipped then return end
	
	if not success then
		MessageService.SendMessage(result)
	end
	return success
end

function State:CreateGUI(attributesData)
	if not self.IsEquipped or not self.HoveredGate or not self.HoveredGate.Parent then return end
	
	self:DestroyGui()
	self.SelectedGate = self.HoveredGate
	
	self.Gui = guiPrefab:Clone()
	self.Gui.Adornee = self.SelectedGate
	self.Gui.GateName.Text = self.SelectedGate.Name
	self.Gui.Parent  = playerGui
	
	self.GuiTogglersConnections = {}
	self.GuiClosedConnection = self.Gui.ApplyButton.Activated:Connect(function()
		if not self.IsEquipped then return end
		if self:ApplyState() then
			self:DestroyGui()
		end
	end)
	
	local frame = self.Gui:FindFirstChild("Frame")
	local scrollingFrame = frame and frame:FindFirstChild("ScrollingFrame")
	if not scrollingFrame then return end
	
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

function State:DestroyGui()
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
	
	if self.HoveredGate and self.HoveredGate.Parent and self.HoveredGate ~= self.SelectedGate then
		local gateID = self.HoveredGate:GetAttribute("GateID")
		if not gateID then return end
		
		local success, result = getDataQuery:InvokeServer(gateID)
		if not self.IsEquipped then return end
		
		if not success then
			MessageService.SendMessage(result)
			return
		end
		
		if not result or typeof(result) ~= "table" or next(result) == nil then
			MessageService.SendMessage("Gate has no attributes to change!")
			return
		end
		
		self:CreateGUI(result)
	end
end

function State:Deactivated()
end

function State:Exit()
	if not self.IsEquipped then return end
	self.IsEquipped = false
	
	self:ResetHighlight()
	self:DestroyGui()
	
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
