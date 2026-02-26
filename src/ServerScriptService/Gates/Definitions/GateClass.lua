--!strict
--[[ GATE CLASS
		This module defines the structure of a GateClass.
		GateClasses include AND, OR, NOT, etc...

		The GateClass defines:
			- Input count and names
			- On-update behaviour
			- Construction of instances

		Everything related to the instance is stored in Gate.
		
		Design rule: GateClasses should be simple. Let players discover advanced stuff by themselves.
		Most simple behaviours can be automatically created using the Factory module.
]]

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")

local SignalService = require(ServerScriptService.Gates.Services.SignalService)
local AttributeService = require (ServerScriptService.Gates.Services.AttributeService)

local Gate = require(ServerScriptService.Gates.Definitions.Gate)
local GateModel = require(ServerScriptService.Gates.Definitions.GateModel)

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- -----------------------------

type TGate = Gate.TGate
type TGateModel = GateModel.TGateModel

export type TGateClass = {
	__index: TGateClass,

	name: string,
	inputs: { string },
	output: string?,
	validAttributes: AttributeService.TAttributeConfigurations,

	CreateGate: (id: number, ownerId: number, gateModel: TGateModel) -> TGate,
	UpdateGate: (gate: TGate) -> SignalService.TSignal,
}

-- ----------------------------- ------ ABSTRACT CLASS DEFINITION ------ -----------------------------

local GateClass = {} :: TGateClass
GateClass.__index = GateClass

function GateClass.CreateGate(id: number, ownerId: number, gateModel: TGateModel): TGate
	local gate = setmetatable({}, GateClass)

	gate.Id = id
	gate.OwnerId = ownerId
	
	gate.Class = GateClass
	gate.Model = gateModel

	return gate :: TGate
end

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return GateClass
