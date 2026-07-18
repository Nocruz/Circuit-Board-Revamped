--[[ SERIALIZER
		This module is just a helper for the Saves module.
		It handles the serialization process for the network transmission
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridService = require(ReplicatedStorage.GridService)

-- ----------------------------- ------------- MAP FUNCTIONS ------------- -----------------------------
-- Maps: (Type -> Function)
local serialize = {}
local deserialize = {}

local function drop(t) warn("Attempted to serialize a value of type " .. t .. ", which is not supported."); return nil end
local function pass(v) return v end

setmetatable(serialize, { __index = function(t, k) return drop(k) end })
setmetatable(deserialize, { __index = function(t, k) return drop(k) end })

-- Primitive types
serialize["string"] = pass
serialize["number"] = pass
serialize["boolean"] = pass
serialize["nil"] = pass

deserialize["string"] = pass
deserialize["number"] = pass
deserialize["boolean"] = pass
deserialize["nil"] = pass

serialize["table"] = function(t: any)
	local copy = {}
	for k, v in pairs(t) do copy[if type(k) == "number" then k else tostring(k)] = serialize[typeof(v)](v) end
	return copy
end

deserialize["table"] = function(t: any)
 -- Not a 'real' rable, but a serialized type
	if t._t and deserialize[t._t] then return deserialize[t._t](t) end	
	
	local copy = {}
	for k, v in pairs(t) do copy[k] = deserialize[type(v)](v) end
	return copy
end

-- Roblox defined types
serialize["Color3"] = function(c: Color3) return { _t = "Color3", R = c.R, G = c.G, B = c.B } end
deserialize["Color3"] = function(c: any) return Color3.new(c.R, c.G, c.B) end

-- Me defined proxys
serialize["GridCFrame"] = function(v: GridService.GridCFrame)
	local serialized = GridService.Serialize(v)
	serialized._t = "GridCFrame"
	return serialized
end

deserialize["GridCFrame"] = GridService.Deserialize

-- ----------------------------- ---------- MODULE DEFINITIONS ----------- -----------------------------

local Serializer = {}

function Serializer.Serialize(data: any): any
	return serialize[typeof(data)](data)
end

function Serializer.Deserialize(data: any): any
	return deserialize[typeof(data)](data)
end

function Serializer.SerializeAs(data: any, proxy: string): any
	return serialize[proxy](data)
end

function Serializer.DeserializeAs(data: any, proxy: string): any
	return deserialize[proxy](data)
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Serializer
