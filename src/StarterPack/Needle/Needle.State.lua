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
	local changes = {}
	
	for _, row: Instance in ipairs(self.Gui.Frame.ScrollingFrame:GetChildren()) do
		if not row:IsA("Frame") then continue end
		local valueHolder = row:FindFirstChild("TextBox") or row:FindFirstChild("TextButton")
		changes[row.Name] = valueHolder.Text
	end
	
	if next(changes) == nil then return true end
	
	local success, result = changeAttributesEvent:InvokeServer(self.SelectedGate:GetAttribute("GateID"), changes)
	if not success then
		MessageService.SendMessage(result)
	end
	return success
end

function State:CreateGUI(attributesData)
	self:DestroyGui()
	self.SelectedGate = self.HoveredGate
	
	self.Gui = guiPrefab:Clone()
	self.Gui.Adornee = self.SelectedGate
	self.Gui.Parent  = playerGui
	self.Gui.GateName.Text = self.SelectedGate.Name
	self.GuiTogglersConnections = {}
	self.GuiClosedConnection = self.Gui.ApplyButton.Activated:Connect(function()
		if self:ApplyState() then
			self:DestroyGui()
		end
	end)
	
	-- Instantiate all the attribute frame editors
	for name, data in pairs(attributesData) do
		if data.AllowedValues == nil then
			local row: Frame & any = self.Gui.InputAttributePrefab:Clone()
			row.Visible = true
			row.Name = name
			row.TextLabel.Text = name
			row.TextBox.Text = tostring(data.Value)
			row.Parent = self.Gui.Frame.ScrollingFrame
		elseif #data.AllowedValues > 0 then
			local row: Frame & any = self.Gui.ToggleAttributePrefab:Clone()
			row.Visible = true
			row.Name = name
			row.TextLabel.Text = name
			row.TextButton.Text = tostring(data.Value)
			row.Parent = self.Gui.Frame.ScrollingFrame
			row:SetAttribute("AllowedValues_Index", table.find(data.AllowedValues, data.Value))
			table.insert(self.GuiTogglersConnections, row.TextButton.Activated:Connect(function()
				local newIndex = ((row:GetAttribute("AllowedValues_Index") :: number) % #data.AllowedValues) + 1
				row.TextButton.Text = tostring(data.AllowedValues[newIndex])
				row:SetAttribute("AllowedValues_Index", newIndex)
			end))
		end
	end
end

function State:DestroyGui()
	if self.Gui ~= nil then
		if self.GuiClosedConnection ~= nil then
			self.GuiClosedConnection:Disconnect()
			self.GuiClosedConnection = nil
		end
		
		for _, connection in ipairs(self.GuiTogglersConnections) do
			connection:Disconnect()
		end
		table.clear(self.GuiTogglersConnections)
		self.GuiTogglersConnections = nil
		
		self.Gui:Destroy()
		self.Gui = nil
		
		self.SelectedGate = nil
	end
end

function State:ResetHighlight()
	if self.HoveredGate then
		self.HoveredGateHighlight.Adornee = nil
		self.HoveredGateHighlight.Parent = nil
		self.HoveredGate = nil
	end
end

function State:SetHighlight(gate: Instance)
	self.HoveredGate = gate
	self.HoveredGateHighlight.Adornee = gate
	self.HoveredGateHighlight.Parent = gate
end

function State:UpdateHighlight(gate: Model?)
	if not gate then
		self:ResetHighlight()
	elseif self.HoveredGate ~= gate then
		self:ResetHighlight()
		self:SetHighlight(gate)
	end
end

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new(player: Player, character: Model)
	local self = setmetatable({}, State)
	self.Player = player
	
	self.HoverConnection = nil
	
	self.HoveredGate = nil
	self.HoveredGateHighlight = nil
	
	self.Gui = nil
	self.GuiClosedConnection = nil
	self.GuiTogglersConnections = nil
	self.SelectedGate = nil
	
	return self
end

function State:Enter()
	self.HoveredGateHighlight = highlightPrefab:Clone()
	
	self.HoverConnection = PointerService.OnHoverChanged:Connect(function(_, gate)
		self:UpdateHighlight(gate)
	end)
	self:UpdateHighlight(PointerService.HoveredGate)
end

function State:Activated()
	if self.HoveredGate and self.HoveredGate ~= self.SelectedGate then
		local success, result = getDataQuery:InvokeServer(self.HoveredGate:GetAttribute("GateID"))
		if not success then
			MessageService.SendMessage(result)
			return
		end
		
		if not next(result) then
			MessageService.SendMessage("Gate has no attributes to change!")
			return
		end
		
		self:CreateGUI(result)
	end
end

function State:Deactivated()
end

function State:Exit()
	self:ResetHighlight()
	
	self:DestroyGui()
	
	if self.HoverConnection then
		self.HoverConnection:Disconnect()
		self.HoverConnection = nil
	end
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
