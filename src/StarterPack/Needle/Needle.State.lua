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

-- State definition
local State = {}
State.__index = State

-- ----------------------------- --------- HELPER METHODS -------- ------------------------------

function State:CreateGUI()
	self:DestroyGui()
	self.SelectedGate = self.HoveredGate
	
	self.Gui = guiPrefab:Clone()
	self.Gui.Adornee = self.SelectedGate
	self.Gui.Parent  = playerGui
	self.Gui.GateName.Text = self.SelectedGate.Name
	self.GuiClosedConnection = self.Gui.ApplyButton.Activated:Connect(function()
		print("Button clicked!")
		self:DestroyGui()
	end)
end

function State:DestroyGui()
	if self.Gui ~= nil then
		if self.GuiClosedConnection ~= nil then
			self.GuiClosedConnection:Disconnect()
			self.GuiClosedConnection = nil
		end
		
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
