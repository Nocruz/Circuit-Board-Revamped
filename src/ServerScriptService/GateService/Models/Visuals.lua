--[[ VISUALS
		This service manages how the GateModels are instantiated.
		Decorations described in TGateVisuals come in tables, that this service
		validates.
		
		Configurations are meant to be exchangeable and gate independant (As long as the node amount is the same).
]]

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- ---------------------------

export type TVisuals = {
	MainMaterial: Enum.Material,
	DisplayName:  string?,
	PrefabName:   string,
	MainColor:    Color3,
	
	OutputOffsets: { Vector2 },
	InputOffsets:  { Vector2 }
}

-- ----------------------------- -------- DEFAULT CONFIGURATIONS --------- ---------------------------

local DefaultConfigurations = {
	MainColor    =  Color3.new(1, 0.2, 0.7),
	MainMaterial = Enum.Material.Concrete,
	PrefabName   = "Basic",
	DisplayName  = ""
}

-- Node offsets are from -0.5 to 0.5 on both X and Y axis (Z being up/down)
-- The 0, 0 coordinate maps to the centre of the gate.
-- However, this coordinate is not possible, because the nodes must be attached to the edges
-- To accomplish this, the coordinate closest to 0 distance to its edge will get snapped,
--   with the Y axis getting priority 
-- The nodes also have their own size, but GateModel handles that
-- Nodes can have the following offsets: X < [-0.5, 0.5], Y < if Input [-0.15, 0.5] else [-0.5, -0.30].
-- 
-- Table of [#inputs] = { Position1, Position2, ...}
local DefaultInputOffsets = {
	[0] = { },
	[1] = { Vector2.new( 0.00, 0.50) },
	[2] = { Vector2.new(-0.20, 0.50), Vector2.new( 0.20, 0.50) },
	[3] = { Vector2.new(-0.27, 0.50), Vector2.new( 0.00, 0.50), Vector2.new(0.27, 0.50) },
	[4] = { Vector2.new(-0.27, 0.50), Vector2.new( 0.00, 0.50), Vector2.new(0.27, 0.50), Vector2.new(0.50, 0.00) },
	[5] = { Vector2.new(-0.27, 0.50), Vector2.new( 0.00, 0.50), Vector2.new(0.27, 0.50), Vector2.new(0.50, 0.25), Vector2.new(0.50, -0.15) },
}
local DefaultOutputOffsets = {
	[0] = { },
	[1] = { Vector2.new( 0.00, -0.50) },
	[2] = { Vector2.new(-0.20, -0.50), Vector2.new( 0.20, -0.50) },
	[3] = { Vector2.new(-0.27, -0.50), Vector2.new( 0.00, -0.50), Vector2.new(0.27, -0.50) },
	[4] = { Vector2.new(-0.50, -0.35), Vector2.new(-0.20, -0.50), Vector2.new(0.20, -0.50), Vector2.new(0.50, -0.35) },
	[5] = { Vector2.new(-0.50, -0.35), Vector2.new(-0.27, -0.50), Vector2.new(0.00, -0.50), Vector2.new(0.27, -0.50), Vector2.new(0.50, -0.35) },
}

local defaults = {}
local function GetDefault(inputNodeCount: number, outputNodeCount: number)
	if defaults[inputNodeCount] == nil then defaults[inputNodeCount] = { } end
	if defaults[inputNodeCount][outputNodeCount] == nil then
		local config = table.clone(DefaultConfigurations)
		config.InputOffsets = DefaultInputOffsets[inputNodeCount]
		config.OutputOffsets = DefaultOutputOffsets[outputNodeCount]
		defaults[inputNodeCount][outputNodeCount] = config
	end
	return defaults[inputNodeCount][outputNodeCount]
end

-- ----------------------------- ---------- HELPER FUNCTIONS ---------- ---------------------------

local nodeLimits = { Input  = { x = -0.15, y =  0.5  }, Output = { x = -0.5 , y = -0.27 } }
local function snapToEdge(type: "Input" | "Output", coordinate: Vector2): Vector2
	local limits = nodeLimits[type]
  -- If X is further from centre, snap X
  if math.abs(coordinate.x) > math.abs(coordinate.y) then
    return Vector2.new(if coordinate.x < 0 then -0.5 else 0.5, math.clamp(coordinate.y, limits.x, limits.y))
  else -- snap Y
    return Vector2.new(math.clamp(coordinate.x, -0.5, 0.5), if math.abs(limits.x) == 0.5 then limits.x else limits.y)
  end
end

-- ----------------------------- ------------- PUBLIC API ------------- ---------------------------

local Visuals = {}

function Visuals.CompleteWithDefaults(table: any, name: string, inputCount: number, outputCount: number)
	local default = GetDefault(inputCount, outputCount)
	if (table.DisplayName == nil) then table.DisplayName = name end
	return setmetatable(table, {__index = default})
end

return Visuals
