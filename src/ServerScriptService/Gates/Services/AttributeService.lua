--!strict
--[[ ATTRIBUTE SERVICE
		Defines Gate Attributes.		
		These are edited by the client with the Needle tool
		The Gate's behaviour changes based on the attributes
		
		Attributes may have conditions, such as "must be a positive number"
		Attributes may have discrete values, like ROUND's Strategy (Floor, Ceil, Closest)
]]

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- ---------------------------

type Predicate<T> = (T) -> boolean

type BaseAttribute<T> = {
	Type: "string" | "number" | "boolean",
	Default: T,
	Predicates: { Predicate<T> },
	Allowed: { T }?,
}

export type StringAttribute  = BaseAttribute<string>  & { Type: "string"  }
export type NumberAttribute  = BaseAttribute<number>  & { Type: "number"  }
export type BooleanAttribute = BaseAttribute<boolean> & { Type: "boolean" }

export type AttributeType =
	| StringAttribute
	| NumberAttribute
	| BooleanAttribute
;

export type Attribute = string | number | boolean

export type AttributeIdentifier = string
export type AttributeTable = { [string]: Attribute }
export type AttributeTypeTable = { [string]: AttributeType }

-- ----------------------------- ------------ HELPER METHODS ----------- ---------------------------

local function isAllowed<T>(value: T, allowed: { T }?): boolean
	if not allowed or #allowed < 1 then return true end
	for _, allowedValue in allowed do
		if value == allowedValue then return true end
	end
	return false
end

local function isValid<T>(value: T, type: BaseAttribute<T>): boolean
	if not isAllowed(value, type.Allowed) then return false end

	for _, predicate in type.Predicates do
		if not predicate(value) then return false end
	end
	return true
end

-- ----------------------------- -------- FUNCTIONS AND METHODS -------- ---------------------------

local AttributeService = {}

function AttributeService.new<T>(default: T, allowed: { T }?, predicates: { Predicate<T> }?): AttributeType
	if (typeof(default) ~= "string" and typeof(default) ~= "number" and typeof(default) ~= "boolean") then 
		warn("Invalid default value. Must be string, number, or boolean.") 
		return {} :: AttributeType 
	else
		return {
			Type = typeof(default),
			Default = default,
			Predicates = predicates or {},
			Allowed = allowed,
		} :: AttributeType
	end
end

function AttributeService.getDefault(type: AttributeType): Attribute return type.Default end

function AttributeService.getValid(current: Attribute?, newValue: Attribute, type: AttributeType): Attribute
	if type.Type == "string" then
		if typeof(newValue) == "string" and isValid(newValue, type :: StringAttribute) then return newValue
		else return current or AttributeService.getDefault(type) end
		
	elseif type.Type == "number" then
		if (typeof(newValue) == "number" or tonumber(newValue)) and isValid(tonumber(newValue) :: number, type :: NumberAttribute) then return newValue
		else return current or AttributeService.getDefault(type) end

	elseif type.Type == "boolean" then
		if typeof(newValue) == "boolean" and isValid(newValue, type :: BooleanAttribute) then return newValue
		else return current or AttributeService.getDefault(type) end
	end
	
	warn("Invalid attribute type. Must be string, number, or boolean.")	
	return current or AttributeService.getDefault(type)
end

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return AttributeService