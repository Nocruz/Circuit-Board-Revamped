--[[ VISUALS
		This service manages how the GateModels are instantiated.
		Decorations described in TGateVisuals come in tables, that this service
		validates.
		
		Configurations are meant to be exchangeable and gate independant (As long as the node amount is the same).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GateVisualRules = require(ReplicatedStorage.Services.GateVisualRules)

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- ---------------------------

export type TVisuals = {
	MainMaterial: Enum.Material,
	DisplayName:  string?,
	PrefabName:   string,
	MainColor:    Color3,
	
	OutputOffsets: { Vector2 },
	InputOffsets:  { Vector2 }
}

-- ----------------------------- ------------- PUBLIC API ------------- ---------------------------

local Visuals = {}

function Visuals.Clone(value: any): any
	return GateVisualRules.Clone(value)
end

function Visuals.Merge(baseVisuals: any, overrideVisuals: any): any
	local merged = if type(baseVisuals) == "table" then GateVisualRules.Clone(baseVisuals) else {}
	if type(overrideVisuals) ~= "table" then
		return merged
	end

	for key, value in pairs(overrideVisuals) do
		merged[key] = GateVisualRules.Clone(value)
	end

	return merged
end

function Visuals.CompleteWithDefaults(visuals: any, name: string, inputCount: number, outputCount: number, baseVisuals: any?): TVisuals
	local default = GateVisualRules.GetDefault(name, inputCount, outputCount)
	local resolved = Visuals.Merge(default, baseVisuals)
	resolved = Visuals.Merge(resolved, visuals)

	if resolved.MainColor == nil then
		resolved.MainColor = default.MainColor
	end
	assert(typeof(resolved.MainColor) == "Color3", "Visuals.MainColor must be a Color3")

	if resolved.MainMaterial == nil then
		resolved.MainMaterial = default.MainMaterial
	end
	assert(typeof(resolved.MainMaterial) == "EnumItem" and resolved.MainMaterial.EnumType == Enum.Material, "Visuals.MainMaterial must be an Enum.Material")

	if resolved.PrefabName == nil then
		resolved.PrefabName = default.PrefabName
	end
	assert(type(resolved.PrefabName) == "string" and resolved.PrefabName ~= "", "Visuals.PrefabName must be a non-empty string")

	if resolved.DisplayName == nil then
		resolved.DisplayName = default.DisplayName
	end
	assert(type(resolved.DisplayName) == "string", "Visuals.DisplayName must be a string")

	local preparedInputs = GateVisualRules.PrepareOffsets("Input", resolved.InputOffsets, inputCount)
	local preparedOutputs = GateVisualRules.PrepareOffsets("Output", resolved.OutputOffsets, outputCount)

	resolved.InputOffsets = preparedInputs or GateVisualRules.CloneOffsets(default.InputOffsets)
	resolved.OutputOffsets = preparedOutputs or GateVisualRules.CloneOffsets(default.OutputOffsets)

	return resolved :: TVisuals
end

return Visuals
