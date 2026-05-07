--!strict

local GateVisualRules = {}

GateVisualRules.DefaultConfigurations = {
	MainColor = Color3.new(1, 0.2, 0.7),
	MainMaterial = Enum.Material.Concrete,
	PrefabName = "Basic",
	DisplayName = "",
}

GateVisualRules.DefaultInputOffsets = {
	[0] = {},
	[1] = { Vector2.new(0.00, 0.50) },
	[2] = { Vector2.new(-0.20, 0.50), Vector2.new(0.20, 0.50) },
	[3] = { Vector2.new(-0.27, 0.50), Vector2.new(0.00, 0.50), Vector2.new(0.27, 0.50) },
	[4] = { Vector2.new(-0.27, 0.50), Vector2.new(0.00, 0.50), Vector2.new(0.27, 0.50), Vector2.new(0.50, 0.00) },
	[5] = { Vector2.new(-0.27, 0.50), Vector2.new(0.00, 0.50), Vector2.new(0.27, 0.50), Vector2.new(0.50, 0.25), Vector2.new(0.50, -0.15) },
}

GateVisualRules.DefaultOutputOffsets = {
	[0] = {},
	[1] = { Vector2.new(0.00, -0.50) },
	[2] = { Vector2.new(-0.20, -0.50), Vector2.new(0.20, -0.50) },
	[3] = { Vector2.new(-0.27, -0.50), Vector2.new(0.00, -0.50), Vector2.new(0.27, -0.50) },
	[4] = { Vector2.new(-0.50, -0.35), Vector2.new(-0.20, -0.50), Vector2.new(0.20, -0.50), Vector2.new(0.50, -0.35) },
	[5] = { Vector2.new(-0.50, -0.35), Vector2.new(-0.27, -0.50), Vector2.new(0.00, -0.50), Vector2.new(0.27, -0.50), Vector2.new(0.50, -0.35) },
}

GateVisualRules.NodeLimits = {
	Input = { MinSecondary = -0.15, FixedSecondary = 0.50 },
	Output = { MinSecondary = -0.50, FixedSecondary = -0.27 },
}

local cachedDefaults: { [number]: { [number]: any } } = {}

local function deepClone(value)
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = deepClone(nestedValue)
	end

	return clone
end

function GateVisualRules.Clone(value: any): any
	return deepClone(value)
end

function GateVisualRules.CloneOffsets(offsets: { Vector2 }): { Vector2 }
	local clone = table.create(#offsets)
	for i, offset in ipairs(offsets) do
		clone[i] = offset
	end
	return clone
end

function GateVisualRules.GetDefault(name: string, inputCount: number, outputCount: number)
	cachedDefaults[inputCount] = cachedDefaults[inputCount] or {}
	local cached = cachedDefaults[inputCount][outputCount]
	if cached ~= nil then
		local resolved = GateVisualRules.Clone(cached)
		resolved.DisplayName = name
		return resolved
	end

	local config = GateVisualRules.Clone(GateVisualRules.DefaultConfigurations)
	config.InputOffsets = GateVisualRules.CloneOffsets(GateVisualRules.DefaultInputOffsets[inputCount] or {})
	config.OutputOffsets = GateVisualRules.CloneOffsets(GateVisualRules.DefaultOutputOffsets[outputCount] or {})
	cachedDefaults[inputCount][outputCount] = GateVisualRules.Clone(config)
	config.DisplayName = name
	return config
end

function GateVisualRules.SnapToEdge(nodeType: "Input" | "Output", coordinate: Vector2): Vector2
	local limits = GateVisualRules.NodeLimits[nodeType]
	if math.abs(coordinate.X) > math.abs(coordinate.Y) then
		return Vector2.new(
			if coordinate.X < 0 then -0.5 else 0.5,
			math.clamp(coordinate.Y, limits.MinSecondary, limits.FixedSecondary)
		)
	end

	local snappedY = if math.abs(limits.MinSecondary) == 0.5 then limits.MinSecondary else limits.FixedSecondary
	return Vector2.new(math.clamp(coordinate.X, -0.5, 0.5), snappedY)
end

function GateVisualRules.PrepareOffsets(nodeType: "Input" | "Output", offsets: { Vector2 }?, expectedCount: number): { Vector2 }?
	if offsets == nil then
		return nil
	end

	assert(type(offsets) == "table", nodeType .. "Offsets must be a table or nil")
	assert(#offsets == expectedCount, nodeType .. "Offsets must be nil or have exactly " .. expectedCount .. " entries")

	local prepared = table.create(expectedCount)
	for index = 1, expectedCount do
		local offset = offsets[index]
		assert(typeof(offset) == "Vector2", nodeType .. "Offsets[" .. index .. "] must be a Vector2")
		prepared[index] = GateVisualRules.SnapToEdge(nodeType, offset)
	end

	return prepared
end

return GateVisualRules
