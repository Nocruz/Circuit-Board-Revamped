--!strict
-- Requires and Services
local ServerStorage = game:GetService("ServerStorage")

-- Define types for our condition functions to give you nice autocompletion
type ConditionFunction = (cframe: CFrame) -> boolean
type BoxConditionFunction = (cframe: CFrame, size: Vector3) -> boolean

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -2048 and value < 2048
end

local Safezones = {}

-- Module State
Safezones.Folder = ServerStorage:FindFirstChild("Safezones") :: Folder?
Safezones.Conditions = {
	function(cframe: CFrame) return isFiniteNumber(cframe.Position.X) and isFiniteNumber(cframe.Position.Y) and isFiniteNumber(cframe.Position.Z) end,
	function(cframe: CFrame) return cframe.Position.Magnitude < 1000 end,
	function(cframe: CFrame) return cframe.Position.Y >= 0 end
}
Safezones.BoxConditions = {
	function(cframe: CFrame, size: Vector3) return isFiniteNumber(cframe.Position.X) and isFiniteNumber(cframe.Position.Y) and isFiniteNumber(cframe.Position.Z) end,
	function(cframe: CFrame, size: Vector3) return cframe.Position.Y - size.Y / 2 >= 0 end,
}

-- Reusable OverlapParams for spatial box queries
local boxOverlapParams = OverlapParams.new()
boxOverlapParams.FilterType = Enum.RaycastFilterType.Include

-- Helper: Checks if a specific Vector3 point is physically inside a BasePart (handles rotation naturally)
local function isPointInPart(point: Vector3, part: BasePart): boolean
	local localPos = part.CFrame:PointToObjectSpace(point)
	local halfSize = part.Size / 2
	
	return math.abs(localPos.X) <= halfSize.X
		and math.abs(localPos.Y) <= halfSize.Y
		and math.abs(localPos.Z) <= halfSize.Z
end

-- ==========================================
-- POINT / PIVOT CHECKS (For the 2x1x2 Blocks)
-- ==========================================

-- Returns true if the CFrame's exact position is inside any BasePart in the Safezones folder
function Safezones.IsCFrameInSafezone(cframe: CFrame): boolean
	if not Safezones.Folder then
		warn("Safezones: No Folder referenced!")
		return false
	end

	local pos = cframe.Position

	for _, child in Safezones.Folder:GetChildren() do
		if child:IsA("BasePart") then
			if isPointInPart(pos, child) then
				return true
			end
		end
	end

	return false
end

-- Validates a point placement
function Safezones.IsValidPlacement(cframe: CFrame): boolean
	-- 1. Fails if the pivot is inside a Safezone
	if Safezones.IsCFrameInSafezone(cframe) then
		return false
	end

	-- 2. Fails if it does not pass all custom Conditions
	for _, condition in Safezones.Conditions do
		if not condition(cframe) then
			return false
		end
	end

	return true
end

-- ==========================================
-- BOX CHECKS (For volume-based placements)
-- ==========================================

-- Returns true if a mathematical box overlaps with any BasePart in the Safezones folder
function Safezones.IsBoxInSafezone(cframe: CFrame, size: Vector3): boolean
	if not Safezones.Folder then
		warn("Safezones: No Folder referenced!")
		return false
	end

	-- Update the filter table (useful if you assign the folder dynamically later)
	boxOverlapParams.FilterDescendantsInstances = {Safezones.Folder}

	-- Spatial query: returns an array of parts intersecting the given box
	local partsInBox = workspace:GetPartBoundsInBox(cframe, size, boxOverlapParams)

	return #partsInBox > 0
end

-- Validates a Box placement
function Safezones.IsValidBoxPlacement(cframe: CFrame, size: Vector3): boolean
	local Box = Instance.new("Part")
	Box.Anchored = true
	Box.CFrame = cframe
	Box.Size = size
	Box.Parent = workspace
	
	-- 1. Fails if the box intersects a Safezone
	if Safezones.IsBoxInSafezone(cframe, size) then
		return false
	end

	-- 2. Fails if it does not pass all custom BoxConditions
	for _, condition in Safezones.BoxConditions do
		if not condition(cframe, size) then
			return false
		end
	end

	return true
end

return Safezones
