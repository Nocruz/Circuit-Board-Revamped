--[[ ATTRIBUTES
		Defines Gate Attributes.
		These are edited by the client with the Needle tool
		The Gate's behaviour changes based on the attributes
		Attributes' intuition is to consider them a Gate's "variables"

		Attributes may have conditions, such as "must be a positive number".
			This conditions are the Predicates.
		Attributes may have discrete values, like ROUND's Strategy (Floor, Ceil, Closest)
			This values are the AllowedValues.
]]

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- ---------------------------

type Predicate<T> = (T) -> boolean

export type TAttributeSpecification<T> = {
	Default: T,
	Predicates: { Predicate<T> },
	AllowedValues: { T }?,
}

-- ----------------------------- ------------ HELPER METHODS ----------- --------------------------

-- ----------------------------- ------------- PUBLIC API ------------- ---------------------------

local Attributes = {}

function Attributes.IsValid(attribute: string | number | boolean, specification: TAttributeSpecification<string | number | boolean>): boolean
	if type(attribute) ~= "string" and type(attribute) ~= "number" and type(attribute) ~= "boolean" then return false end
	for predicate in ipairs(specification.Predicates) do
		if not predicate(attribute) then return false end
	end
	
	if specification.AllowedValues then
		for i, value in ipairs(specification.AllowedValues) do
			if attribute == value then return true end
		end
		return false
	end
	
	return true
end

function Attributes.Get(attribute: string | number | boolean, specification:TAttributeSpecification<string | number | boolean>)
	return if Attributes.IsValid(attribute, specification) then attribute else specification.Default
end

-- ----------------------------- ----------- END OF MODULE ------------ ---------------------------

return Attributes
