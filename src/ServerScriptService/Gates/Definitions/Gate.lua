--!strict
--[[ GATE
		This module represents a single Gate object.
		It should be as lightweight as possible, as hundrends of these per player may exist.

		Different 'types' of gates are all Gate objects, just
		  with different Class members. Class should be solved through the Registry.

		Only GateClasses should instantiate Gates, using the CreateGate function.
]]

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")

local SignalService = require(ServerScriptService.Gates.Services.SignalService)
local AttributeService = require(ServerScriptService.Gates.Services.AttributeService)

local Node = require(ServerScriptService.Gates.Definitions.Node)
local GateModel = require(ServerScriptService.Gates.Definitions.GateModel)

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- -----------------------------

export type TGate = {
	Id: number,
	OwnerId: number,
	Model: GateModel.TGateModel,

	Class: string,
	
	Output: SignalService.TSignal?,
	Inputs: Node.TNodes?,
	Connections: { [number]: { [string] : { existance: true, Wire: number } } }?, -- [GateID]: { [NodeName]: ConnectionInformation } 
	
	Attributes: AttributeService.TAttributeValues
}

-- ----------------------------- ------------- END OF MODULE ------------- ---------------------------

return true
