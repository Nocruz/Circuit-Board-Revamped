--!strict
--[[ SPECIFICATION FACTORY
		Creates normalized GateService specifications.
]]

local SpecificationFactory = {}

--- Helpers

-- ----------------------------- ------------ HELPERS ------------------- -----------------------------

local function buildInputOrder(signalInputs: { string }, attributes: { [string]: any }): { string }
	local ordered = {}

	for _, inputName in ipairs(signalInputs) do
		table.insert(ordered, inputName)
	end

	for attributeName, attribute in pairs(attributes) do
		if attribute.SignalType ~= nil and table.find(ordered, attributeName) == nil then
			table.insert(ordered, attributeName)
		end
	end

	table.sort(ordered, function(left, right)
		local leftSignalIndex = table.find(signalInputs, left)
		local rightSignalIndex = table.find(signalInputs, right)

		if leftSignalIndex ~= nil and rightSignalIndex ~= nil then
			return leftSignalIndex < rightSignalIndex
		end
		if leftSignalIndex ~= nil then
			return true
		end
		if rightSignalIndex ~= nil then
			return false
		end

		return left < right
	end)

	return ordered
end

local function cloneAttributes(attributes: { [string]: any }): { [string]: any }
	local cloned = {}

	for attributeName, attribute in pairs(attributes) do
		cloned[attributeName] = table.clone(attribute)
	end

	return cloned
end

local function normalizeNodes(schema: any, attributes: { [string]: any }): any
	local schemaNodes = schema.Nodes
	assert(type(schemaNodes) == "table", "Specification '" .. schema.Name .. "' is missing Nodes")

	local signalInputs = schemaNodes.SignalInputs or {}
	local attributeInputs = {}

	for attributeName, attribute in pairs(attributes) do
		if attribute.SignalType ~= nil then
			attributeInputs[attributeName] = attribute.SignalType
		end
	end

	return {
		SignalInputs = table.clone(signalInputs),
		AttributeInputs = attributeInputs,
		HasOutput = schemaNodes.HasOutput == true,
		InputOrder = buildInputOrder(signalInputs, attributes),
	}
end

local function normalizeAttributes(schema: any): { [string]: any }
	local attributes = schema.Attributes or {}
	assert(type(attributes) == "table", "Specification '" .. schema.Name .. "' attributes must be a table")

	for attributeName, attribute in pairs(attributes) do
		assert(type(attributeName) == "string" and attributeName ~= "", "Specification attribute names must be strings")
		assert(type(attribute) == "table", "Attribute '" .. attributeName .. "' must be a table")
		assert(attribute.Default ~= nil, "Attribute '" .. attributeName .. "' is missing Default")
	end

	return cloneAttributes(attributes)
end

local function normalizeSchema(schema: any): any
	assert(type(schema) == "table", "Gate specification schema must be a table")
	assert(type(schema.Name) == "string" and schema.Name ~= "", "Gate specification schema is missing Name")
	assert(type(schema.Process) == "function", "Specification '" .. schema.Name .. "' is missing Process")

	local attributes = normalizeAttributes(schema)

	return {
		Name = schema.Name,
		Nodes = normalizeNodes(schema, attributes),
		Attributes = attributes,
		DefaultVisuals = schema.DefaultVisuals,
		Create = schema.Create,
		Process = schema.Process,
		OnDestroy = schema.OnDestroy,
		OnConnectionChanged = schema.OnConnectionChanged,
	}
end

--- Public API

-- ----------------------------- ------------- PUBLIC API ------------- -----------------------------

function SpecificationFactory.Create(schema: any): any
	return normalizeSchema(schema)
end

SpecificationFactory.new = SpecificationFactory.Create
SpecificationFactory.FromSchema = SpecificationFactory.Create
SpecificationFactory.FromSimple = SpecificationFactory.Create

return SpecificationFactory
