--[[ SAFEZONES
		For now, it's just a helper to prevent moving and
		spawning gates too close to the spawn.
		
		The idea is for it to gracefully create a safezone
		on a player's build so griefers dont block saves.
]]

-- Requires and Services
local Workspace = game:GetService("Workspace")

-- References
local safezonesFolder = Workspace.Safezones
assert(safezonesFolder, "No safezones folder! Did ya forget this on an update?")

-- Boxcast
local overlapParameters = OverlapParams.new()
overlapParameters.FilterType = Enum.RaycastFilterType.Include
overlapParameters.FilterDescendantsInstances = { safezonesFolder }

-- ----------------------------- ----------- MODULE DEFINITION ----------- -----------------------------

local Safezones = {}

function Safezones.IsGateInSafezone(position: Vector3, size: Vector3): boolean
	local centreCFrame = CFrame.new(position + Vector3.yAxis * size.Y / 2)
	local safezonesInGate = Workspace:GetPartBoundsInBox(centreCFrame, size, overlapParameters)
	
	return #safezonesInGate > 0
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Safezones
