--[[ SPEED BRACE
		Easy tool. On equip, gives a speed boost.
		On click, toggles between a Low Speed Boost and a High Speed Boost.
		
		Should also spawn a beam that tracks the player (As a flash trail or similar)
]]

-- State definition
local State = {}
State.__index = State

-- Constants
local LOW_SPEED = 50
local HIGH_SPEED = 120
local DEFAULT_SPEED = 16 -- Standard Roblox walkspeed

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new(player: Player, character: Model)
	local self = setmetatable({}, State)
	self.humanoid = character:FindFirstChildOfClass("Humanoid")
	
	self.IsActive = false
	
	return self
end

function State:Enter()
	self.humanoid.WalkSpeed = LOW_SPEED
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
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
