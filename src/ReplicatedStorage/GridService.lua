--[[ GRID SERVICE
		Stores a CFrame snapped to a grid, supporting full 3D axis-aligned rotations.
		Acts as a complete CFrame proxy (.Position, .LookVector, call :ToWorldSpace(), etc. all callable)
		Should implement overrides of the methods that also return GridCFrames
]]

-- Constants
local STEP_XZ = 1
local STEP_Y  = 1

local AXIS_ID_TO_VECTOR = {
	[0] = Vector3.xAxis, [1] = -Vector3.xAxis,
	[2] = Vector3.yAxis, [3] = -Vector3.yAxis,
	[4] = Vector3.zAxis, [5] = -Vector3.zAxis,
}

-- Types

export type Direction = "Clockwise" | "Counter"

export type GridCFrame = typeof(setmetatable({} :: { _cframe: CFrame }, {} :: any)) & CFrame & {
	Move: (self: GridCFrame, to: Vector3) -> GridCFrame,
	RotateX: (self: GridCFrame, direction: Direction) -> GridCFrame,
	RotateY: (self: GridCFrame, direction: Direction) -> GridCFrame,
	RotateZ: (self: GridCFrame, direction: Direction) -> GridCFrame,
	GetSurfaceNormal: (self: GridCFrame, pos: Vector3) -> Vector3,
}

local GridService = {}

-- ----------------------------- ----------- HELPER FUNCTIONS ------------ -----------------------------

-- Snaps a given Vector3 to the absolute nearest axis aligned direction.
local function snapAxisV3(v: Vector3): Vector3
	local ax, ay, az = math.abs(v.X), math.abs(v.Y), math.abs(v.Z)
	
	if ax >= ay and ax >= az then
		return Vector3.xAxis * (if v.X < 0 then -1 else 1)
	elseif ay >= ax and ay >= az then
		return Vector3.yAxis * (if v.Y < 0 then -1 else 1)
	else
		return Vector3.zAxis * (if v.Z < 0 then -1 else 1)
	end
end

-- Extracts a perfectly orthonormal 3D rotation matrix snapped to cardinal axes
local function snapRotation(cf: CFrame): CFrame
	local right = snapAxisV3(cf.RightVector)
	local up = snapAxisV3(cf.UpVector)
	
	-- Fallback to ensure orthogonal axes in case of extreme floating point distortions
	if math.abs(right:Dot(up)) > 0.5 then
		local newUp = cf.UpVector - right * cf.UpVector:Dot(right)
		up = snapAxisV3(newUp)
	end
	
	local back = right:Cross(up)
	return CFrame.fromMatrix(Vector3.zero, right, up, back)
end

local function vectorToAxisId(v: Vector3): number
	local ax, ay, az = math.abs(v.X), math.abs(v.Y), math.abs(v.Z)
	if ax >= ay and ax >= az then return v.X > 0 and 0 or 1
	elseif ay >= ax and ay >= az then return v.Y > 0 and 2 or 3
	else return v.Z > 0 and 4 or 5 end
end

-- ----------------------------- ------------- PROXY SETUP --------------- -----------------------------

local GridCFrameMT = {}
local GridCFrameMethods = {}

function GridCFrameMT.__index(self, key)
	-- Check if it's one of our custom class methods (Move, RotateX, etc.)
	if GridCFrameMethods[key] then
		return GridCFrameMethods[key]
	end
	
	-- Proxy over to the real, internal CFrame
	local val = self._cframe[key]
	
	-- If it's a CFrame method (like :ToWorldSpace()), wrap it to pass the real CFrame as self
	if type(val) == "function" then
		return function(_, ...)
			return val(self._cframe, ...)
		end
	end
	
	return val
end

-- Support math operations with standard CFrames
function GridCFrameMT.__mul(a, b)
	local cfA = type(a) == "table" and a._cframe or a
	local cfB = type(b) == "table" and b._cframe or b
	return cfA * cfB 
end

function GridCFrameMT.__eq(a, b)
	local cfA = type(a) == "table" and a._cframe or a
	local cfB = type(b) == "table" and b._cframe or b
	return cfA == cfB
end

function GridCFrameMT.__tostring(self)
	return tostring(self._cframe)
end

-- ----------------------------- -------------- CONSTRUCTOR -------------- -----------------------------

function GridService.fromCFrame(cframe: CFrame): GridCFrame
	local position = Vector3.new(
		math.round(cframe.X / STEP_XZ) * STEP_XZ, 
		math.round(cframe.Y / STEP_Y) * STEP_Y, 
		math.round(cframe.Z / STEP_XZ) * STEP_XZ
	)
	
	-- Combine snapped rotation matrix with snapped positional vector
	local resultCFrame = snapRotation(cframe) + position
	
	local self = {
		_cframe = resultCFrame,
	}
	
	return setmetatable(self, GridCFrameMT) :: any
end

-- ----------------------------- ---------------- METHODS ---------------- -----------------------------

function GridCFrameMethods:Move(to: Vector3): GridCFrame
	return GridService.fromCFrame(CFrame.new(to) * self._cframe.Rotation)
end

local function getAngle(direction: Direction): number
	return math.rad(90 * (direction == "Clockwise" and -1 or 1))
end

-- Rotates around the object's local RightVector (Pitch)
function GridCFrameMethods:RotateX(direction: Direction): GridCFrame
	return GridService.fromCFrame(self._cframe * CFrame.Angles(getAngle(direction), 0, 0))
end

-- Rotates around the object's local UpVector (Yaw)
function GridCFrameMethods:RotateY(direction: Direction): GridCFrame
	return GridService.fromCFrame(self._cframe * CFrame.Angles(0, getAngle(direction), 0))
end

-- Rotates around the object's local LookVector (Roll)
function GridCFrameMethods:RotateZ(direction: Direction): GridCFrame
	return GridService.fromCFrame(self._cframe * CFrame.Angles(0, 0, getAngle(direction)))
end

function GridCFrameMethods:GetSurfaceNormal(pos: Vector3): Vector3
	-- Proxy lets us natively read `self.Position` from the internal CFrame
	local relative = pos - (self.Position + Vector3.yAxis * STEP_Y / 2)
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

-- ----------------------------- ------------- SERIALIZATION ------------- -----------------------------

function GridService.Serialize(gridCF: GridCFrame)
	local cf = gridCF._cframe
	return {
		X = cf.X, Y = cf.Y, Z = cf.Z,
		R = vectorToAxisId(cf.RightVector),
		U = vectorToAxisId(cf.UpVector)
	}
end

function GridService.Deserialize(data: any): GridCFrame
	local pos = Vector3.new(data.X, data.Y, data.Z)
	local right = AXIS_ID_TO_VECTOR[data.R] or Vector3.xAxis
	local up = AXIS_ID_TO_VECTOR[data.U] or Vector3.yAxis
	local back = right:Cross(up)
	
	-- Fallback to fix orthogonality if data was corrupted
	if back.Magnitude < 0.1 then back = Vector3.zAxis end
	
	return GridService.fromCFrame(CFrame.fromMatrix(pos, right, up, back))
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return GridService
