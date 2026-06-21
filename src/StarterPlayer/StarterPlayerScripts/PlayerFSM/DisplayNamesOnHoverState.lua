--[[ DEFAULT STATE
		This state only shows the name of the
		gate's owner. Target gate is the one being
		hovered over.
]]

-- Requires and Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalServices = game:GetService("StarterPlayer").StarterPlayerScripts.Services
local PointerService = require(LocalServices.PointerService)

-- References
local ownerTextPrefab = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("OwnerText")

-- State definition
local State = {}
State.__index = State

-- ----------------------------- ----------- HELPER FUNCTIONS ------------ -----------------------------

function State:hideUI()
	self.UI.Enabled = false
	self.UI.Adornee = nil
end

function State:updateUI(instance: Instance?, gate: Instance?, node: Instance?)
	if not gate then
		self:hideUI()
		return
	end
	
	local ownerID = gate:GetAttribute("OwnerID")
	if ownerID <= 0 then
		self:hideUI()
		return
	end
	
	self.UI.Adornee = gate:FindFirstChild("Base")
	self.UI.Enabled = true
	local success, result = pcall(Players.GetNameFromUserIdAsync, Players, ownerID)
	self.UI.TextLabel.Text = if success then result else "Unknown"
end

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new(player: Player, character: Model)
	local self = setmetatable({}, State)
	self.Player = player
	
	return self
end

function State:Enter()
	self.UI = ownerTextPrefab:Clone() :: BillboardGui
	self.UI.Parent = self.Player:WaitForChild("PlayerGui")
	
	self:hideUI()
	
	self.HoverConnection = PointerService.OnHoverChanged:Connect(function(instance: Instance?, gate: Instance?, node: Instance?)
		self:updateUI(instance, gate, node)
	end)
	self:updateUI()
end

function State:Activated()
end

function State:Deactivated()
end

function State:Exit()
	if self.HoverConnection then
		self.HoverConnection:Disconnect()
		self.HoverConnection = nil
	end
	
	self.UI:Destroy()
	table.clear(self)
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
