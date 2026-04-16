--!strict
--[[ GATE
		Runtime gate helpers and the shared class shape.
		This is now the single source of truth for both the gate instance and
		the lightweight "class" tables used by the individual gate modules.
]]

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")

local AttributeService = require(ServerScriptService.Gates.Services.AttributeService)
local SignalService = require(ServerScriptService.Gates.Services.SignalService)
local Node = require(ServerScriptService.Gates.Definitions.Node)

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- -----------------------------

export type TGateClass = {
	__index: TGateClass,
	name: string,
	inputs: { string }?,
	output: string?,
	nodeInformation: Node.TNodeInformation?,
	validAttributes: AttributeService.TAttributeConfigurations?,
	
	new: ((id: number, ownerId: number, gateModel: Model) -> TGate)?,
	Update: ((gate: TGate, origin: "Signal" | "Schedule") -> SignalService.TSignal)?,
}

export type TGate = {
	Id: number,
	OwnerId: number,
	Model: Model,

	Class: TGateClass?,
	Output: SignalService.TSignal?,
	Inputs: Node.TNodes?,
	Connections: Node.TNodeConnections?,

	Attributes: AttributeService.TAttributeValues,
	[string]: any,
}

-- ----------------------------- ----------- MODULE DEFINITION ----------- -----------------------------

local Gate = {}

-- ----------------------------- ------------- CONSTRUCTION ------------- -----------------------------

function Gate.GetNodeInformation(class: TGateClass): Node.TNodeInformation
	local existing = class.nodeInformation
	if existing ~= nil then
		return existing
	end

	local inputs = class.inputs or {}
	local nodeInformation: Node.TNodeInformation = {
		HasOutput = class.output ~= nil,
		InputCount = #inputs,
		Inputs = inputs,
	}

	class.nodeInformation = nodeInformation
	return nodeInformation
end

local function applyClassDefaults(gate: TGate, class: TGateClass)
	gate.Class = class
	gate.Inputs = Node.CreateNodes(class.inputs or {})
	gate.Connections = if class.output ~= nil then {} else nil
	gate.Output = if class.output ~= nil then false else nil
	gate.Attributes = {}

	for attributeName, attribute in pairs(class.validAttributes or {}) do
		gate.Attributes[attributeName] = AttributeService.getDefault(attribute)
	end

	Gate.GetNodeInformation(class)
end

function Gate.CreateGate(id: number, ownerId: number, gateModel: Model, class: TGateClass?): TGate
	local gate: TGate = {
		Id = id,
		OwnerId = ownerId,
		Model = gateModel,

		Class = nil,
		Output = nil,
		Inputs = nil,
		Connections = nil,

		Attributes = {},
	}

	if class ~= nil then
		applyClassDefaults(gate, class)
	end

	return gate
end

function Gate.Instantiate(class: TGateClass, id: number, ownerId: number, gateModel: Model): TGate
	return setmetatable(Gate.CreateGate(id, ownerId, gateModel, class), class)
end

function Gate.CreateClass(class: TGateClass): TGateClass
	class.__index = class
	Gate.GetNodeInformation(class)

	if class.new == nil then
		function class.new(id: number, ownerId: number, gateModel: Model): TGate
			return Gate.Instantiate(class, id, ownerId, gateModel)
		end
	end

	if class.Update == nil then
		function class.Update(gate: TGate): SignalService.TSignal
			return gate.Output or false
		end
	end

	return class
end

-- ----------------------------- ------------ ATTRIBUTE ACCESS ------------ ----------------------------

function Gate.getAttribute(gate: TGate, attribute: string, inputNode: Node.TNode?): any
	if inputNode ~= nil and Node.HasConnections(inputNode) then
		return Gate.getSignalInput(inputNode)
	end

	local storedValue = gate.Attributes[attribute]
	if storedValue ~= nil then
		return storedValue
	end

	local class = gate.Class
	local validAttributes = class and class.validAttributes
	if validAttributes and validAttributes[attribute] ~= nil then
		return validAttributes[attribute].Default
	end

	return nil
end

function Gate.setAttribute(gate: TGate, attribute: string, value: any): any
	local class = gate.Class
	local validAttributes = class and class.validAttributes

	if validAttributes and validAttributes[attribute] ~= nil then
		gate.Attributes[attribute] = AttributeService.ValueOrDefault(validAttributes[attribute], value)
	else
		gate.Attributes[attribute] = value
	end

	return gate.Attributes[attribute]
end

-- ----------------------------- ------------ INPUT HELPERS -------------- ----------------------------

function Gate.getSignalInput(node: Node.TNode?): SignalService.TSignal
	if node == nil or not Node.HasConnections(node) then
		return false
	end

	local signals = {}
	for gate in pairs(node) do
		local output = gate.Output
		if output ~= nil then
			table.insert(signals, output)
		end
	end

	return SignalService.Collapse(signals)
end

function Gate.getBooleanInput(node: Node.TNode?): boolean
	return SignalService.toBoolean(Gate.getSignalInput(node))
end

function Gate.getNumericInput(node: Node.TNode?): number
	return SignalService.toNumber(Gate.getSignalInput(node))
end

function Gate.getStringInput(node: Node.TNode?): string
	return SignalService.toString(Gate.getSignalInput(node))
end

-- ----------------------------- ------------- END OF MODULE ------------- ---------------------------

return Gate
