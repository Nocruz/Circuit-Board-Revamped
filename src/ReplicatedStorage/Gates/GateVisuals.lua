--!strict
--[[ GATE VISUALS
		This defines the graphics of a GateModel.
		It also contains a registry of visuals.
]]

-- Requires and Services
local ReplicatedStorage	= game:GetService("ReplicatedStorage")

-- References
local VisualsFolder = ReplicatedStorage.Gates.Visuals

-- --------------------------------------- TYPE DEFINITIONS ----------- ---------------------------

export type TGateVisuals = {
	MainColor:    Color3,
	MainMaterial: Enum.Material,
	DisplayName:  string,
	PrefabName:   string,
	
	OutputOffset: Vector2,
	InputOffsets: { [string]: Vector2 }
}

-- Essentially Option<T> values, where Nil or errors during extract collapse to default
local BaseConfigurations: {
		MainColor:    { default: Color3, extract: (v: Color3Value) -> Color3? },
		MainMaterial: { default: Enum.Material, extract: (v: StringValue) -> Enum.Material? },
		DisplayName:  { default: string, extract: (v: StringValue) -> string? },
		PrefabName:   { default: string, extract: (v: StringValue) -> string? },
		OutputOffset: { default: Vector2, extract: (v: Vector3Value) -> Vector2? },
	} = {
	MainColor    = { default = Color3.new(1, 0.2, 0.7), extract = function(v: Color3Value) return v.Value end },
	MainMaterial = { default = Enum.Material.Concrete,    extract = function(v: StringValue) return Enum.Material:FromName(v.Value) end },
	PrefabName   = { default = "BasicGate",               extract = function(v: StringValue) return v.Value end },
	DisplayName  = { default = "Gate",                    extract = function(v: StringValue) return v.Value end },

	OutputOffset = { default = Vector2.zero,              extract = function(v: Vector3Value) return Vector2.new(v.Value.X, v.Value.Z) end }
	-- Handle InputOffsets differently
}

export type TGateVisualsRegistry = {
	getVisualsFromName: (name: string) -> TGateVisuals?,
	validateVisuals: (visuals: TGateVisuals) -> boolean
}

-- ----------------------------- ---------- HELPER FUNCTIONS ---------- ---------------------------

local function getValueOrDefault<T>(config: Configuration, name: string, default: T, extract: (any) -> T) : T
	local obj = config:FindFirstChild(name)

	local success, value = pcall(extract, obj)
	return if success and type(value) ~= "nil" then value else default
end

local function getVisualsFromConfig(config: Configuration): TGateVisuals
	local configTable = table.clone(BaseConfigurations)
	configTable.DisplayName.default = config.Name

	-- Collapse Option<> for each BaseConfiguration
	local visuals = { InputOffsets = {} } :: TGateVisuals
	for configuration, data in pairs(configTable) do
		visuals[configuration] = getValueOrDefault(config, configuration, data.default, data.extract)
	end
	
	-- Read for InputOffsets (if any)
	local InputOffsets = config:FindFirstChild("InputOffsets")
	if InputOffsets then
		for _, child in InputOffsets:GetChildren() do
			if child:IsA("Vector3Value") then
				visuals.InputOffsets[child.Name] = Vector2.new(child.Value.X, child.Value.Z)
			end
		end
	end

	return visuals
end

-- ----------------------------- ------------ CONSTRUCTOR ------------- ---------------------------

local GateVisuals: TGateVisualsRegistry = {
	getVisualsFromName = function(name: string): TGateVisuals?
		local config = VisualsFolder:FindFirstChild(name)
		if not config then return nil end
		if not config:IsA("Configuration") then return nil end
		
		return getVisualsFromConfig(config)
	end,

	validateVisuals = function(visuals: TGateVisuals): boolean
		if not visuals then return false end
		if type(visuals) ~= "table" then return false end

		local hasAllProperties = false
		for configuration, data in pairs(BaseConfigurations) do
			hasAllProperties = visuals[configuration] and typeof(visuals[configuration]) == typeof(data.default)
			if not hasAllProperties then return false end
		end

		for key, value in pairs(visuals.InputOffsets) do
			if typeof(key) ~= "string" or typeof(value) ~= "Vector2" then return false end
		end
		
		return true
	end,
}

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return GateVisuals
