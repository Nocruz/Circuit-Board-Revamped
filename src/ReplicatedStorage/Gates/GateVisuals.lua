--!strict
--[[ GATE VISUALS
		This defines the graphics of a GateModel.
		It also contains a registry of visuals.
]]

-- Requires and Services
local ReplicatedStorage	= game:GetService("ReplicatedStorage")

local VisualsFolder = ReplicatedStorage.Gates.Visuals

-- --------------------------------------- TYPE DEFINITIONS ----------- ---------------------------

-- Types
export type TGateVisuals = {
	MainColor   : Color3,
	MainMaterial: Enum.Material,
	DisplayName	: string,
	PrefabName	: string,
	
	OutputOffset: Vector2,
	InputOffsets:{ [string]: Vector2 }
}

export type TGateVisualsRegistry = {
	getVisualsFromName: (name: string) -> TGateVisuals?,
	
	validateVisuals: (visuals: TGateVisuals) -> boolean
}

-- ----------------------------- ---------- HELPER FUNCTIONS ---------- ---------------------------

local function getValueOrDefault<T, V>(config: Instance, name: string, className: string, default: () -> V, extract: (T) -> V) : V
	local obj = config:FindFirstChild(name)
	if obj and obj.ClassName == className then return extract(obj) end
	return default()
end

local function getVisualsFromConfig(config: Configuration): TGateVisuals
	local visuals = {
		MainColor = getValueOrDefault(
			config,
			"MainColor",
			"Color3Value",
			function() return Color3.new(1, 0.2, 0.7) end,
			function(v) return v.Value end
		),
		MainMaterial = getValueOrDefault(
			config,
			"MainMaterial",
			"StringValue",
			function() return Enum.Material.Concrete end,
			function(v) return Enum.Material:FromName(v.Value) or Enum.Material.Concrete end
		),
		PrefabName = getValueOrDefault(
			config,
			"PrefabName",
			"StringValue",
			function() return "BasicGate" end,
			function(v) return v.Value end
		),
		DisplayName = getValueOrDefault(
			config,
			"DisplayName",
			"StringValue",
			function() return config.Name end,
			function(v) return v.Value end
		),

		OutputOffset = getValueOrDefault(
			config,
			"OutputOffset",
			"Vector3Value",
			function() return Vector2.zero end,
			function(v: Vector3Value) return Vector2.new(v.Value.X, v.Value.Z) end
		),

		InputOffsets = {}
	} :: TGateVisuals

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

		local hasAllProperties =
			typeof(visuals.MainColor) == "Color3" and
			typeof(visuals.MainMaterial) == "EnumItem" and
			typeof(visuals.DisplayName) == "string" and
			typeof(visuals.OutputOffset) == "Vector2" and
			typeof(visuals.InputOffsets) == "table"
		if not hasAllProperties then return false end

		if visuals.MainMaterial.EnumType ~= Enum.Material then return false end

		for key, value in pairs(visuals.InputOffsets) do
			if typeof(key) ~= "string" or typeof(value) ~= "Vector2" then return false end
		end
		
		return true
	end,
}

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return GateVisuals
