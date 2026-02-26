--!strict
--[[ GATE VISUALS SERVICE
			This service manages how the GateModels are instantiated.
			It does so by reading the Configuration instance under
				.\ReplicatedStorage\Gates\Visuals\<gateName>

			Configurations are meant to be exchangeable and gate independant.
			For gate dependant stuff, change the Prefab
]]

-- Requires and Services
local ReplicatedStorage	= game:GetService("ReplicatedStorage")

-- References
local VisualsFolder = ReplicatedStorage:WaitForChild("Gates"):WaitForChild("Visuals")

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- ---------------------------

export type TGateVisuals = {
	MainColor:    Color3,
	MainMaterial: Enum.Material,
	DisplayName:  string,
	PrefabName:   string,
	
	OutputOffset: Vector2,
	InputOffsetOverrides: { [string]: Vector2 }
}

-- ----------------------------- -------- BASE CONFIGURATIONS ---------- ---------------------------

-- Node offsets are from -0.5 to 0.5 on both X and Y axis (Z being up/down)
-- The 0, 0 coordinate maps to the centre of the gate.
-- However, this coordinate is not possible, because the nodes must be attached to the edges
-- To accomplish this, the coordinate closest to 0 distance to its edge will get snapped,
--   with the Y axis getting priority 
-- The nodes also have their own size, but GateModel handles that

-- This function takes a (x, y) and the (min, max) positions on Y, and returns
--   a valid position for InputOffsetOverrides or OutputOffset
local InputLimits = Vector2.new(-0.15, 0.5)
local OutputLimits = Vector2.new(-0.5, -0.35)
local function snapToEdge(coordinate: Vector2, limits: Vector2): Vector2
  -- If X is further from centre, snap X
  if math.abs(coordinate.x) > math.abs(coordinate.y) then
    return Vector2.new(if coordinate.x < 0 then -0.5 else 0.5, math.clamp(coordinate.y, limits.x, limits.y))
  else -- snap Y
    return Vector2.new(math.clamp(coordinate.x, -0.5, 0.5), if math.abs(limits.x) == 0.5 then limits.x else limits.y)
  end
end

-- Function to get the InputOffsetOverrides out of the Config -> InputOffsets Configuration instance
local function extractInputOffsetOverrides(v: Configuration)
	local offsets = {}
	for _, child in ipairs(v:GetChildren()) do
		if child:IsA("Vector3Value") then
			offsets[child.Name] = snapToEdge(Vector2.new(child.Value.X, child.Value.Z), InputLimits)
		end
	end
	return offsets
end

-- Essentially Option<T> values, where Nil or errors during extract collapse to default
local BaseConfigurations: {
		MainColor:    { default: Color3,                        extract: (v: Color3Value) -> Color3? },
		MainMaterial: { default: Enum.Material,                 extract: (v: StringValue) -> Enum.Material? },
		PrefabName:   { default: string,                        extract: (v: StringValue) -> string? },
		DisplayName:  { default: string,                        extract: (v: StringValue) -> string? },
		OutputOffset: { default: Vector2,                       extract: (v: Vector3Value) -> Vector2? },
		InputOffsetOverrides: { default: { [string]: Vector2 }, extract: (v: Configuration) -> { [string]: Vector2 }?  },
	} = {
	MainColor    = { default = Color3.new(1, 0.2, 0.7), extract = function(v: Color3Value) return v.Value end },
	MainMaterial = { default = Enum.Material.Concrete,    extract = function(v: StringValue) return Enum.Material:FromName(v.Value) end },
	PrefabName   = { default = "BasicGate",               extract = function(v: StringValue) return v.Value end },
	DisplayName  = { default = "Gate",                    extract = function(v: StringValue) return v.Value end },
	OutputOffset = { default = Vector2.zero,              extract = function(v: Vector3Value) return snapToEdge(Vector2.new(v.Value.X, v.Value.Z), OutputLimits) end },
	InputOffsetOverrides = { default = {},                extract = extractInputOffsetOverrides }
}

-- Table of [#inputs] = { Position1, Position2, ...}
local DefaultInputOffsets = {
	{ Vector2.new(0, 0.5) },
	{ Vector2.new(-0.2, 0.5), Vector2.new(0.2, 0.5) },
	{ Vector2.new(-0.25, 0.5), Vector2.new(0, 0.5), Vector2.new(0.25, 0.5) },
	{ Vector2.new(-0.25, 0.5), Vector2.new(0, 0.5), Vector2.new(0.25, 0.5), Vector2.new(0.5, 0) },
	{ Vector2.new(-0.25, 0.5), Vector2.new(0, 0.5), Vector2.new(0.25, 0.5), Vector2.new(0.5, -0.2), Vector2.new(0.5, 0.2) },
}

-- ----------------------------- ---------- HELPER FUNCTIONS ---------- ---------------------------

local function getValueOrDefault<T>(configurations: Configuration, name: string, default: T, extract: (any) -> T) : T
	local configuration = configurations:FindFirstChild(name)
	if configuration == nil then return default end
	
	local success, value = pcall(extract, configuration)
	return if success and value ~= nil then value else default
end

local function getVisualsFromConfig(config: Configuration): TGateVisuals
	local visuals = {} :: TGateVisuals

	-- Collapse Option<T> for each BaseConfiguration
	for configuration, data in pairs(BaseConfigurations) do
		local default = if configuration == "DisplayName" then config.Name else data.default

		visuals[configuration] = getValueOrDefault(config, configuration, default, data.extract)
	end

	return visuals
end

local function getConfigFromName(name: string): Configuration?
		local config = VisualsFolder:FindFirstChild(name)
		if not config or not config:IsA("Configuration") then return nil
		else return config end
end

-- ----------------------------- -------------- REGISTRY -------------- ---------------------------

local registry: { [string]: TGateVisuals } = {}

-- ----------------------------- --------- SERVICE DEFINITION --------- ---------------------------

local GateVisualsService = {}

GateVisualsService.Get = function (key: string): TGateVisuals?
	local config = getConfigFromName(key)
	if not config then return nil end

	if not registry[key] then
		registry[key] = getVisualsFromConfig(config)
	end

	return registry[key]
end

GateVisualsService.DefaultInputOffsets = DefaultInputOffsets

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return GateVisualsService
