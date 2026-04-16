--!strict
--[[ GATE REGISTRY
		Stores gate classes and live gate instances.
		This module also keeps a small compatibility surface for older callers
		that still use `:`/lowercase method names.
]]

-- Requires and Services
local Gate = require(script.Parent.Gate)
local GateModel = require(script.Parent.GateModel)

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- ---------------------------

export type TGate = Gate.TGate
export type TGateClass = Gate.TGateClass
export type TGateModel = GateModel.TGateModel

-- ----------------------------- ------- REGISTRY DEFINITION -------- ---------------------------

local GateRegistry = {}

local GatesById: { [number]: TGate } = {}
local ModelsById: { [number]: TGateModel } = {}
local GatesByModel: { [Instance]: TGate } = {}
local ClassesByName: { [string]: TGateClass } = {}

local function resolveId(first: any, second: any): number
	return if second ~= nil then second else first
end

local function resolveClass(first: any, second: any): TGateClass
	return if second ~= nil then second else first
end

local function resolveGate(first: any, second: any, third: any): TGate
	if third ~= nil then
		return third
	end
	if second ~= nil and type(first) == "number" then
		return second
	end
	return if second ~= nil then second else first
end

-- ----------------------------- ------------- CLASSES -------------- ---------------------------

function GateRegistry.RegisterClass(selfOrClass: any, maybeClass: TGateClass?): TGateClass
	local class = resolveClass(selfOrClass, maybeClass)
	assert(class ~= nil and class.name ~= nil, "Gate class must have a name")
	assert(ClassesByName[class.name] == nil, "Gate class " .. class.name .. " already exists")
	
	class.nodeInformation = Gate.GetNodeInformation(class)
	ClassesByName[class.name] = class
	return class
end

function GateRegistry.GetClass(selfOrName: any, maybeName: string?): TGateClass?
	local name = if maybeName ~= nil then maybeName else selfOrName
	return ClassesByName[name]
end

-- ----------------------------- -------------  GATES --------------- ---------------------------

function GateRegistry.RegisterGate(selfOrGate: any, maybeGate: TGate?, maybeGateForCompatibility: TGate?): TGate
	local gate = resolveGate(selfOrGate, maybeGate, maybeGateForCompatibility)
	assert(gate ~= nil, "Gate is required")
	assert(GatesById[gate.Id] == nil, "Gate with ID " .. gate.Id .. " already exists")

	GatesById[gate.Id] = gate

	local model = gate.Model
	if model ~= nil then
		ModelsById[gate.Id] = model :: TGateModel
		GatesByModel[model] = gate
	end

	return gate
end

function GateRegistry.UnregisterGate(selfOrId: any, maybeId: number?): TGate?
	local id = resolveId(selfOrId, maybeId)
	local gate = GatesById[id]
	if gate == nil then
		return nil
	end

	GatesById[id] = nil
	ModelsById[id] = nil

	local model = gate.Model
	if model ~= nil then
		GatesByModel[model] = nil
	end

	return gate
end

function GateRegistry.IsGate(selfOrId: any, maybeId: number?): boolean
	local id = resolveId(selfOrId, maybeId)
	return GatesById[id] ~= nil
end

function GateRegistry.GetGate(selfOrId: any, maybeId: number?): TGate?
	local id = resolveId(selfOrId, maybeId)
	return GatesById[id]
end

function GateRegistry.TryGetGateFromId(selfOrId: any, maybeId: number?): TGate?
	return GateRegistry.GetGate(selfOrId, maybeId)
end

function GateRegistry.TryGetGateFromModel(selfOrModel: any, maybeModel: Instance?): TGate?
	local model = if maybeModel ~= nil then maybeModel else selfOrModel
	return GatesByModel[model]
end

function GateRegistry.GetAllGates(): { [number]: TGate }
	return GatesById
end

-- ----------------------------- -------------  MODELS -------------- ---------------------------

function GateRegistry.IsModel(selfOrId: any, maybeId: number?): boolean
	local id = resolveId(selfOrId, maybeId)
	return ModelsById[id] ~= nil
end

function GateRegistry.GetModel(selfOrId: any, maybeId: number?): TGateModel?
	local id = resolveId(selfOrId, maybeId)
	return ModelsById[id]
end

-- ----------------------------- --------- COMPATIBILITY ALIASES -------- ---------------------------

GateRegistry.registerClass = GateRegistry.RegisterClass
GateRegistry.tryGetGateClass = GateRegistry.GetClass
GateRegistry.getClass = GateRegistry.GetClass

GateRegistry.registerGate = GateRegistry.RegisterGate
GateRegistry.unregisterGate = GateRegistry.UnregisterGate
GateRegistry.tryGetGateFromId = GateRegistry.TryGetGateFromId
GateRegistry.tryGetGateFromModel = GateRegistry.TryGetGateFromModel

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return GateRegistry
