--!strict
--[[ ATTRIBUTE SERVICE
		Defines Gate Attributes.
		These are edited by the client with the Needle tool
		The Gate's behaviour changes based on the attributes
		Attributes' intuition is to consider them a Gate's "variables"

		Attributes may have conditions, such as "must be a positive number".
			This conditions are the Predicates.
		Attributes may have discrete values, like ROUND's Strategy (Floor, Ceil, Closest)
			This values are the AllowedValues.

		This service accepts both the current `(default, predicates, allowedValues)`
		call shape and the older `(default, allowedValues, predicates)` shape that
		a lot of the gate modules still use.
]]

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- ---------------------------

type Predicate<T> = (T) -> boolean

export type TAttribute<T> = {
	Default: T,
	Predicates: { Predicate<T> },
	AllowedValues: { T }?,
}

export type TAttributeConfigurations = { [string]: TAttribute<any> }
export type TAttributeValues = { [string]: any }
export type TAttributeTypeTable = TAttributeConfigurations
export type TClientAttribute = {
	Default: any,
	Type: string,
	Allowed: { any }?,
}

-- ----------------------------- ------------ HELPER METHODS ----------- --------------------------

local function isArray(value: any): boolean
	if type(value) ~= "table" then
		return false
	end

	local length = #value
	for key in pairs(value) do
		if type(key) ~= "number" or key < 1 or key > length or key % 1 ~= 0 then
			return false
		end
	end

	return true
end

local function containsOnlyFunctions(value: any): boolean
	if not isArray(value) then
		return false
	end

	local hasItems = false
	for _, item in ipairs(value) do
		hasItems = true
		if type(item) ~= "function" then
			return false
		end
	end

	return hasItems
end

local function normalizeAllowedValues<T>(allowedValues: { T }?): { T }?
	if allowedValues == nil then
		return nil
	end

	-- Legacy modules often pass `{}` when they mean "any value is allowed".
	if next(allowedValues) == nil then
		return nil
	end

	return allowedValues
end

local function normalizeArguments<T>(second: any, third: any): ({ Predicate<T> }, { T }?)
	local predicates: { Predicate<T> }? = nil
	local allowedValues: { T }? = nil

	if third ~= nil then
		local secondLooksLikeAllowed = isArray(second) and not containsOnlyFunctions(second) and next(second) ~= nil
		local secondLooksLikePredicates = containsOnlyFunctions(second)
		local thirdLooksLikeAllowed = isArray(third) and not containsOnlyFunctions(third) and next(third) ~= nil

		if secondLooksLikeAllowed then
			allowedValues = second
			predicates = third
		elseif secondLooksLikePredicates or thirdLooksLikeAllowed then
			predicates = second
			allowedValues = third
		else
			allowedValues = second
			predicates = third
		end
	else
		if containsOnlyFunctions(second) then
			predicates = second
		else
			allowedValues = second
		end
	end

	return predicates or {}, normalizeAllowedValues(allowedValues)
end

local function isValid(attribute: TAttribute<any>, value: any): boolean
	if typeof(value) ~= typeof(attribute.Default) then
		return false
	end

	local allowedValues = attribute.AllowedValues
	if allowedValues ~= nil and table.find(allowedValues, value) == nil then
		return false
	end

	for _, predicate in attribute.Predicates do
		if not predicate(value) then
			return false
		end
	end

	return true
end

-- ----------------------------- ------------- PUBLIC API ------------- ---------------------------

local AttributeService = {}

function AttributeService.CreateAttribute<T>(default: T, predicatesOrAllowedValues: { any }?, allowedValuesOrPredicates: { any }?): TAttribute<T>
	local predicates, allowedValues = normalizeArguments(predicatesOrAllowedValues, allowedValuesOrPredicates)
	local attribute: TAttribute<T> = {
		Default = default,
		Predicates = predicates,
		AllowedValues = allowedValues,
	}

	assert(isValid(attribute, default), "Failed on attribute creation: Was not valid")
	return attribute
end

function AttributeService.new<T>(default: T, predicatesOrAllowedValues: { any }?, allowedValuesOrPredicates: { any }?): TAttribute<T>
	return AttributeService.CreateAttribute(default, predicatesOrAllowedValues, allowedValuesOrPredicates)
end

function AttributeService.getDefault<T>(attribute: TAttribute<T>): T
	return attribute.Default
end

function AttributeService.ValueOrDefault<T>(attribute: TAttribute<T>, newValue: T): T
	return if isValid(attribute, newValue) then newValue else attribute.Default
end

function AttributeService.ToClientAttribute(attribute: TAttribute<any>): TClientAttribute
	local allowedValues = attribute.AllowedValues
	return {
		Default = attribute.Default,
		Type = typeof(attribute.Default),
		Allowed = if allowedValues then table.clone(allowedValues) else nil,
	}
end

function AttributeService.ToClientSchema(configurations: TAttributeConfigurations?): { [string]: TClientAttribute }
	local schema: { [string]: TClientAttribute } = {}
	for attributeName, attribute in pairs(configurations or {}) do
		schema[attributeName] = AttributeService.ToClientAttribute(attribute)
	end
	return schema
end

-- ----------------------------- ----------- END OF MODULE ------------ ---------------------------

return AttributeService
