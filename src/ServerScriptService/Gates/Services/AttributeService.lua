--!strict
--[[ ATTRIBUTE SERVICE
		Defines Gate Attributes.		
		These are edited by the client with the Needle tool
		The Gate's behaviour changes based on the attributes
		Attributes' intuition is to consider them a Gate's "variables"

		Attributes may have conditions, such as "must be a positive number".
			This conditions are the Predicates.
		Attributes may have discrete values, like ROUND's Strategy (Floor, Ceil, Closest)
			This values are the AllowedValues. (If AllowedValues == nil, all values are allowed, if AllowedValues == { }, no values are allowed)

		Boolean attributes should always have AllowedValues = { true, false }!!
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

-- ----------------------------- ------------ HELPER METHODS ----------- --------------------------

-- Checks if a value matches the conditions for an attribute
local function isValid(attribute: TAttribute<any>, value: any): boolean
	-- Checks type. Only Server defines attributes so this should be clean enough for only primitives
	if typeof(value) ~= typeof(attribute.Default) then return false end
	
	-- Checks value against the Allowed table
	if attribute.AllowedValues ~= nil and table.find(attribute.AllowedValues, value) == nil then return false end

	for _, predicate in attribute.Predicates do
		if not predicate(value) then return false end
	end

	return true
end

-- ----------------------------- ------------- PUBLIC API ------------- ---------------------------

local AttributeService = {}

function AttributeService.CreateAttribute<T>(default: T, predicates: { Predicate<T> }?, allowedValues: { T }?): TAttribute<T>
	local attribute: TAttribute<T> = { Default = default, Predicates = predicates or {}, AllowedValues = allowedValues }
	assert(isValid(attribute, default), "Failed on attribute creation: Was not valid")
	return attribute
end

-- Returns newValue if assignable, default if not
function AttributeService.ValueOrDefault<T>(attribute: TAttribute<T>, newValue: T): T
	return if isValid(attribute, newValue) then newValue else attribute.Default
end

-- ----------------------------- ----------- END OF MODULE ------------ ---------------------------

return AttributeService
