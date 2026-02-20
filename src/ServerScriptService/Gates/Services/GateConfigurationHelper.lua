--!strict
--[[ GATE CONFIGURATION HELPER
		Helper for validating gate configurations
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local GateUniversal = require(ServerScriptService.Gates.Models.GateUniversal)

local GatePrefabsFolder = ReplicatedStorage.Gates.Prefabs.Gates
local GateTypesFolder   = ServerScriptService.Gates.Types

-- Debugging
local Logger = require(ReplicatedStorage.Shared.LoggerService)
local log = Logger.new("GateConfigurationHelper")

-- Defaults
local DefaultGateModel = GateUniversal.modelToGateModel(GatePrefabsFolder.BasicGate) :: GateModel
local DefaultMaterial = Enum.Material.Concrete
local DefaultColor = Color3.new(1, 0, 0.7)

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- ---------------------------
type Gate = GateUniversal.Gate
type GateModel = GateUniversal.GateModel

export type GateConfiguration = {
	DisplayName	: string,
	GateModel 	: GateModel,
	MainColor   : Color3,
	MainMaterial: Enum.Material,
	GateClass   : GateUniversal.GateClass,
	InputOffsets: { [string]: Vector2 },
	OutputOffset: Vector2?,
}

-- ----------------------------- ---------- HELPER FUNCTIONS ---------- ---------------------------

local function getValueOrDefault<T, V>(config: Instance, name: string, className: string, default: () -> V, extract: (T) -> V): V
	local obj = config:FindFirstChild(name)
	if obj and obj.ClassName == className then return extract(obj) end
	return default()
end

local function snapInputToEdge(vector: Vector3): Vector2
	local x = math.clamp(vector.X, -0.5, 0.5)
	local z = math.clamp(vector.Z, -0.1, 0.5)
	
	local distanceLeft = math.abs(x + 0.5)
	local distanceRight = math.abs(x - 0.5)
	local distanceBack = math.abs(z - 0.5)
	local minDistance = math.min(distanceLeft, distanceRight, distanceBack)
	
	if minDistance == distanceLeft then
		return Vector2.new(-0.5, z)
	elseif minDistance == distanceRight then
		return Vector2.new(0.5, z)
	elseif minDistance == distanceBack then
		return Vector2.new(x, 0.5)
	end
	
	-- Unreachable code
	return Vector2.new(x, z)
end

local function snapOutputToEdge(vector: Vector3): Vector2
	local x = math.clamp(vector.X, -0.5, 0.5)
	local z = math.clamp(vector.Z, -0.5, -0.4)

	local distanceLeft = math.abs(x + 0.5)
	local distanceRight = math.abs(x - 0.5)
	local distanceFront = math.abs(z + 0.5)
	local minDistance = math.min(distanceLeft, distanceRight, distanceFront)

	if minDistance == distanceLeft then
		return Vector2.new(-0.5, z)
	elseif minDistance == distanceRight then
		return Vector2.new(0.5, z)
	elseif minDistance == distanceFront then
		return Vector2.new(x, -0.5)
	end

	-- Unreachable code
	return Vector2.new(x, z)
end

-- ----------------------------- --------- FACTORY DEFINITION --------- ---------------------------

local GateConfigurationHelper = {}

function GateConfigurationHelper.configToGateConfig(config: Configuration): GateConfiguration?
	local gateConfiguration: GateConfiguration = {
		DisplayName = getValueOrDefault(
			config,
			"DisplayName",
			"StringValue",
			function() return config.Name end,
			function(v) return v.Value end
		),
		GateModel = getValueOrDefault(
			config,
			"GateModel",
			"StringValue",
			function() return DefaultGateModel end,
			function(v)
				local model = GatePrefabsFolder:FindFirstChild(v.Value)
				if not model or not model:IsA("Model") then return DefaultGateModel end
				return GateUniversal.modelToGateModel(model) :: GateModel
			end
		),
		MainColor = getValueOrDefault(
			config,
			"MainColor",
			"Color3Value",
			function() return DefaultColor end,
			function(v) return v.Value end
		),
		MainMaterial = getValueOrDefault(
			config,
			"MainMaterial",
			"StringValue",
			function() return DefaultMaterial end,
			function(v)
				local material = Enum.Material:FromName(v.Value)
				if not material then return DefaultMaterial end
				return material
			end
		),
		GateClass = getValueOrDefault(
			config,
			"GateClass",
			"StringValue",
			function()
				local class = GateTypesFolder:FindFirstChild(config.Name)
				if not class then return GateUniversal end
				return require(GateTypesFolder:FindFirstChild(config.Name)) :: GateUniversal.GateClass 
			end,
			function(v)
				local class = GateTypesFolder:FindFirstChild(v.Value)
				if not class then return GateUniversal end
				return require(GateTypesFolder:FindFirstChild(v.Value)) :: GateUniversal.GateClass
			end
		),
		InputOffsets = {},
	}
	
	-- Gate class is the only required configuration.
	local class = gateConfiguration.GateClass
	if class == GateUniversal then
		log.warn("GateClass was invalid! Cancelling")
		return nil
	end

	-- Input offsets
	local inputsFolder = config:FindFirstChild("InputOffsets")
	if inputsFolder then
		log.info("Found InputOffsets.")
		for name, default in class.inputs do
			log.info("Setting offset for " .. name)
			gateConfiguration.InputOffsets[name] = getValueOrDefault(
				inputsFolder,
				name,
				"Vector3Value",
				function() return default end,
				function(v: Vector3Value) 
					return snapInputToEdge(v.Value)
				end
			)
		end
	else
		log.info("No InputOffsets folder found, using defaults")
		for name, default in class.inputs do
			gateConfiguration.InputOffsets[name] = default
		end
	end
	
	-- Output offset
	if class.output then
		log.info("Gate has Output node, setting offset")
		gateConfiguration.OutputOffset = getValueOrDefault(
			config,
			"OutputOffset",
			"Vector3Value",
			function() return class.output end,
			function(v: Vector3Value) 
				return snapOutputToEdge(v.Value)
			end
		)
	else
		log.info("Gate has no Output node. Setting offset to nil")
		gateConfiguration.OutputOffset = nil
	end
	
	return gateConfiguration	
end

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return GateConfigurationHelper