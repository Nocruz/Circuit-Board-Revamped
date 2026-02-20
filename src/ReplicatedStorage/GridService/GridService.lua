--!strict
--[[ GRID SERVICE
		Handles coordinate transformation between World and Grid space.
]]

local GridService = {}

-- Grid size constants
local STEP_X = 1
local STEP_Y = 1
local STEP_Z = 1

function GridService.gridToWorld(gridPos: Vector3): Vector3
	return Vector3.new(
		gridPos.X * STEP_X,
		gridPos.Y * STEP_Y,
		gridPos.Z * STEP_Z
	)
end

function GridService.worldToGrid(worldPos: Vector3): Vector3
	return Vector3.new(
		math.round(worldPos.X / STEP_X),
		math.round(worldPos.Y / STEP_Y),
		math.round(worldPos.Z / STEP_Z)
	)
end

function GridService.snap(worldPos: Vector3): Vector3
	local grid = GridService.worldToGrid(worldPos)
	return GridService.gridToWorld(grid)
end

return GridService