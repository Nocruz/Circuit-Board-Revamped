--!strict
--[[ GATE REGISTRY
		This has no behaviour by itself.
		It's just a record that holds:
		  - Gate classes
		  - Map from Gate's IDs to class instances
		  - Map from Gate's IDs to model instances
]]

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")

local Gate = require(ServerScriptService.Gates.Definitions.Gate)
local GateClass = require(ServerScriptService.Gates.Definitions.GateClass)
local GateModel = require(ServerScriptService.Gates.Definitions.GateModel)

-- State
local LastID: number = 1

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- ---------------------------

export type TGate = Gate.TGate
export type TGateClass = GateClass.TGateClass
export type TGateModel = GateModel.TGateModel

-- ----------------------------- ------- REGISTRY DEFINITION -------- ---------------------------

local Gates:   { [number]: TGate } = {}
local Classes: { [string]: TGateClass } = {}
local Models:  { [number]: TGateModel } = {}

local GateRegistry = {}

function GateRegistry.NextID(): number
	LastID += 1
	return LastID
end

-- ----------------------------- ------------- CLASSES -------------- ---------------------------

function GateRegistry.RegisterClass(class: TGateClass)
	assert(not Classes[class.name], "Gate class " .. class.name .. " already exists")
	Classes[class.name] = class
end

function GateRegistry.IsClass(name: string): boolean return Classes[name] ~= nil end
function GateRegistry.GetClass(name: string): TGateClass return Classes[name] end

-- ----------------------------- -------------  GATES --------------- ---------------------------

function GateRegistry.RegisterGate(id: number, gate: TGate)
	assert(Gates[id] == nil, "Gate with ID " .. id .. " already exists")
	Gates[id] = gate
end

function GateRegistry.UnregisterGate(id: number)
	assert(Gates[id] ~= nil, "Gate with ID " .. id .. " does not exist")
	Gates[id] = nil
end

function GateRegistry.IsGate(id: number): boolean return Gates[id] ~= nil end
function GateRegistry.GetGate(id: number): TGate? return Gates[id] end

-- ----------------------------- -------------  MODELS -------------- ---------------------------

function GateRegistry.RegisterModel(id: number, model: TGateModel)
	assert(Gates[id] ~= nil, "Gate with ID " .. id .. " does not exist")
	assert(Models[id] ~= nil, "Gate with ID " .. id .. " already has a registered model")
	Models[id] = model
end

function GateRegistry.UnregisterModel(id: number)
	assert(Models[id] ~= nil, "Model for gate of id ".. id .. "does not exist")
	Models[id] = nil
end

function GateRegistry.IsModel(id: number): boolean return Models[id] ~= nil end
function GateRegistry.GetModel(id: number): TGate return Models[id] end

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return GateRegistry
