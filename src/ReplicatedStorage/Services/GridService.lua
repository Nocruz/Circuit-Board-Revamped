--!strict
--[[ GRID SERVICE
		Stores a CFrame, it's position on the grid and it's rotation in 4 steps.
]]

-- Grid size constants
local STEP_XZ = 1
local STEP_Y  = 1

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- ---------------------------

export type TRotation = "PosX" | "NegX" | "PosZ" | "NegZ"
export type TGridCFrame = {
	_cframe: CFrame,
	Position: Vector3,
	Rotation: TRotation,
}

-- ----------------------------- --------- SERVICE DEFINITION --------- ---------------------------

local GridService = {}

-- ----------------------------- ------------- CONSTRUCTORS -------------- ---------------------------

function GridService.fromCFrame(cframe: CFrame): TGridCFrame
	local position = Vector3.new(math.round(cframe.X / STEP_XZ) * STEP_XZ, math.round(cframe.Y / STEP_Y) * STEP_Y, math.round(cframe.Z / STEP_XZ) * STEP_XZ)
	local rotation:TRotation, rotVector
	
	local lookX, lookZ = cframe.LookVector.X, cframe.LookVector.Z
	if math.abs(lookZ) >= math.abs(lookX) then
		if lookZ > 0 then
			rotation = "PosZ"
			rotVector = position + Vector3.zAxis
		else
			rotation = "NegZ"
			rotVector = position - Vector3.zAxis
		end
	else
		if lookX > 0 then
			rotation = "PosX"
			rotVector = position + Vector3.xAxis
		else
			rotation = "NegX"
			rotVector = position - Vector3.xAxis
		end
	end
	
	local resultCFrame = CFrame.lookAt(position, rotVector)
	return {
		_cframe = resultCFrame,
		Position = position,
		Rotation = rotation
	}
end

-- ----------------------------- ------------ TRANSFORMATIONS ------------ ---------------------------
-- Offset is in grid units

function GridService.Move(from: TGridCFrame, to: Vector3): TGridCFrame
	return GridService.fromCFrame(CFrame.new(to) * from._cframe.Rotation)
end

function GridService.Rotate(from: TGridCFrame, direction: "Clockwise" | "Counter"): TGridCFrame
	return GridService.fromCFrame(from._cframe * from._cframe.Rotation * CFrame.Angles(0, math.rad(90 * if direction == "Clockwise" then 1 else -1), 0))
end

function GridService.getSurfaceNormal(pos: Vector3, targetCFrame: TGridCFrame): Vector3
	local relative = pos - (targetCFrame.Position + Vector3.yAxis * STEP_Y / 2)

	local nx, ny, nz = math.abs(relative.X), math.abs(relative.Y) * 2, math.abs(relative.Z)

	-- Determine which face was clicked by finding the largest component
	if nx > ny and nx > nz then
		return Vector3.xAxis * math.sign(relative.X)
	elseif ny > nx and ny > nz then
		return if math.sign(relative.Y) < 0 then -Vector3.yAxis else Vector3.zero
	else
		return Vector3.zAxis * math.sign(relative.Z)
	end
end

-- ----------------------------- ------------- END OF MODULE ------------- ---------------------------

return GridService
