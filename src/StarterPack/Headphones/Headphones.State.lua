--[[ HEADPHONES TOOL
		Tool used to toggle audio channels on and off locally.
]]

-- Requires and services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local EffectsService = require(ReplicatedStorage:WaitForChild("EffectsService"))

-- Visuals
local guiPrefab: ScreenGui = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("HeadphonesGui")

-- References
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local musicGroup = SoundService:WaitForChild("Music")
local effectsGroup = SoundService:WaitForChild("Effects")

-- State definition
local State = {}
State.__index = State

-- ----------------------------- --------- HELPER METHODS -------- ------------------------------

function State:UpdateButtonVisual(button: TextButton, isActive: boolean)
	if isActive then
		button.TextColor3 = Color3.fromRGB(0, 255, 0)
	else
		button.TextColor3 = Color3.fromRGB(255, 0, 0)
	end
end

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new(player: Player)
	local self = setmetatable({}, State)
	self.Player = player
	
	self.Gui = nil
	self.Connections = {}
	self.IsEquipped = true
	
	return self
end

function State:Enter()
	-- Instantiate the GUI
	self.Gui = guiPrefab:Clone()
	self.Gui.Parent = playerGui
	
	-- Note: Matches the hierarchy shown in image_aa5e87.png
	local frame = self.Gui:WaitForChild("Frame")
	local btnMusic = frame:WaitForChild("Music") :: TextButton
	local btnEffects = frame:WaitForChild("Effects") :: TextButton
	-- We intentionally ignore the "Speakers" button as requested.
	
	-- Initialize colors based on current volume state
	self:UpdateButtonVisual(btnMusic, musicGroup.Volume > 0)
	self:UpdateButtonVisual(btnEffects, effectsGroup.Volume > 0)
	
	-- Bind Music Toggle
	table.insert(self.Connections, btnMusic.Activated:Connect(function()
		if not self.IsEquipped then return end
		
		if musicGroup.Volume > 0 then
			musicGroup.Volume = 0
			self:UpdateButtonVisual(btnMusic, false)
		else
			musicGroup.Volume = 0.3
			self:UpdateButtonVisual(btnMusic, true)
		end
	end))
	
	-- Bind Effects Toggle
	table.insert(self.Connections, btnEffects.Activated:Connect(function()
		if not self.IsEquipped then return end
		
		if effectsGroup.Volume > 0 then
			effectsGroup.Volume = 0
			self:UpdateButtonVisual(btnEffects, false)
		else
			effectsGroup.Volume = 1.0
			self:UpdateButtonVisual(btnEffects, true)
		end
	end))
	
	EffectsService.PlaySFX("Equip Headphones")
end

function State:Activated()
end

function State:Deactivated()
end

function State:Exit()
	if not self.IsEquipped then return end
	self.IsEquipped = false
	
	-- Clean up all UI connections
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	table.clear(self.Connections)
	
	-- Clean up GUI
	if self.Gui then
		self.Gui:Destroy()
		self.Gui = nil
	end
	
	EffectsService.PlaySFX("Unequip Headphones")
	
	table.clear(self)
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
