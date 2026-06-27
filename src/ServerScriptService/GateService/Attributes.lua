--[[ ATTRIBUTES
		Defines Gate Attributes.
		These are edited by the client with the Needle tool
		The Gate's behaviour changes based on the attributes
		Attributes' intuition is to consider them a Gate's "variables"
		
		Attributes may have conditions, such as "must be a positive number".
			These conditions are the Predicates.
		Attributes may only take discrete values, like ROUND's Strategy (Floor, Ceil, Closest)
			These values are the AllowedValues.
]]

-- ----------------------------- ------------ TYPE DEFINITIONS ----------- -----------------------------

type Predicate<T> = (T) -> boolean

export type TAttributeData<T> = {
	Default: T,
	Predicates: { Predicate<T> },
	AllowedValues: { T }?,
}

-- ----------------------------- --------------- PUBLIC API -------------- -----------------------------

local Attributes = {}

function Attributes.IsValid(attribute: string | number | boolean, attributeData: TAttributeData<string | number | boolean>): boolean
	if not attributeData then return false end
	if type(attribute) ~= "string" and type(attribute) ~= "number" and type(attribute) ~= "boolean" then return false end
	
	local targetType = type(attributeData.Default)
	if type(attribute) ~= targetType then
		if targetType == "string" then
			attribute = tostring(attribute)
		
		elseif targetType == "number" then
			local asNumber = tonumber(attribute)
			if asNumber ~= nil then
				attribute = asNumber
			else
				return false
			end
		
		elseif targetType == "boolean" then
			if attribute == "true" then attribute = true
			elseif attribute == "false" then attribute = false
			else return false end
		end
	end
	
	for i, predicate in ipairs(attributeData.Predicates) do
		if not predicate(attribute) then return false end
	end
	
	if attributeData.AllowedValues then
		for i, value in ipairs(attributeData.AllowedValues) do
			if attribute == value then return true, attribute end
		end
		return false
	end
	
	return true, attribute
end

function Attributes.Get(attribute: string | number | boolean, specification: TAttributeData<string | number | boolean>)
	return if Attributes.IsValid(attribute, specification) then attribute else specification.Default
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Attributes
