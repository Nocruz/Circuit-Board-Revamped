--[[ SPEED BRACE
		Easy tool. On equip, gives a speed boost.
		On click, toggles between a Low Speed Boost and a High Speed Boost.
		
		Should also spawn a beam that tracks the player (As a flash trail or similar)
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EffectsService = require(ReplicatedStorage:WaitForChild("EffectsService"))

-- State definition
local State = {}
State.__index = State

-- Constants
local LOW_SPEED = 50
local HIGH_SPEED = 120
local DEFAULT_SPEED = 16 -- Standard Roblox walkspeed

local SOUND_EFFECT = "Speed Brace"

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new(player: Player, character: Model)
	local self = setmetatable({}, State)
	self.humanoid = character:FindFirstChildOfClass("Humanoid")
	
	self.stopMusic = nil
	
	self.IsActive = false
	
	return self
end

function State:Enter()
	self.humanoid.WalkSpeed = LOW_SPEED
	self.stopMusic = EffectsService.PlaySFX(SOUND_EFFECT)
end

function State:Activated()
	self.IsActive = not self.IsActive
	self.humanoid.WalkSpeed = if self.IsActive
		then HIGH_SPEED
		else LOW_SPEED
end

function State:Deactivated()
end

function State:Exit()
	self.humanoid.WalkSpeed = DEFAULT_SPEED
	if self.stopMusic then
		self.stopMusic()
		self.stopMusic = nil
	end
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
