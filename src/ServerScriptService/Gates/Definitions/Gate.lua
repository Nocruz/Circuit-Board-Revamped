--!strict
--[[ GATE
		This is the base gate.
		Represents an GateClass's object.
]]

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local SignalService = require(ServerScriptService.Gates.Services.SignalService)
local AttributeService = require(ServerScriptService.Gates.Services.AttributeService)

-- Types
local Types = require(ServerScriptService.Gates.Definitions.Types)
export type TGate = Types.TGate
export type TNode = Types.TNode
export type TSignal = Types.TSignal

local Gate = {}

function Gate.getBooleanInput(node: TNode): boolean
	for outGate in pairs(node) do
		if SignalService.toBoolean(outGate.Output) then return true end
	end
	return false
end

function Gate.getNumericInput(node: TNode): number
	if next(node) == nil then return 0 end
	local highestValue: number = 0

	for outGate in pairs(node) do
		local out = SignalService.toNumber(outGate.Output)
		if math.abs(out) > math.abs(highestValue) then
			highestValue = out
		end
	end

	return highestValue
end

function Gate.getStringInput(node: TNode): string
	return SignalService.toString(Gate.getSignalInput(node))
end

function Gate.getSignalInput(node: TNode): TSignal
	if next(node) == nil then return false end
	local highestValue: TSignal = false

	for outGate in pairs(node) do
		local out = outGate.Output :: TSignal

		if type(out) == "string" then
			if type(highestValue) ~= "string" then
				highestValue = out
			elseif #out :: string > #highestValue :: string then
				highestValue = out
			end
		else
			if math.abs(SignalService.toNumber(out)) >= math.abs(SignalService.toNumber(highestValue)) then
				highestValue = out
			end
		end
	end
	return highestValue	
end

function Gate.getAttribute(gate: TGate, attribute: string, node: TNode?): AttributeService.Attribute
	assert(gate.Class.validAttributes and gate.Class.validAttributes[attribute] and gate.Attributes[attribute])
	
	if not node or next(node) == nil then return gate.Attributes[attribute] end
	
	local attributeType = gate.Class.validAttributes[attribute]
	local value
	if attributeType.Type == "string" then
		value = Gate.getStringInput(node)
	elseif attributeType.Type == "number" then
		value = Gate.getNumericInput(node)
	elseif attributeType.Type == "boolean" then
		value = Gate.getBooleanInput(node)
	end
	
	return AttributeService.getValid(gate.Attributes[attribute], value :: AttributeService.Attribute, attributeType)
end

function Gate.setAttribute(gate: TGate, attribute: string, value: AttributeService.Attribute)
	assert(gate.Class.validAttributes and gate.Class.validAttributes[attribute] and gate.Attributes[attribute])
	
	local attributeType = gate.Class.validAttributes[attribute]
	gate.Attributes[attribute] = AttributeService.getValid(gate.Attributes[attribute], value, attributeType)
end

return Gate