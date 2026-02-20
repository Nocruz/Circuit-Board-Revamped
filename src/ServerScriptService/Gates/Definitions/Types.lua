--!strict
--[[ TYPES
		Central hub for type definitions to avoid cyclic dependencies.
		This module contains NO logic, only type exports.
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SeverScriptService = game:GetService("ServerScriptService")

local AttributeService = require(SeverScriptService.Gates.Services.AttributeService)
export type TAttributeTable = AttributeService.AttributeTable
export type TAttributeTypeTable = AttributeService.AttributeTypeTable

local GateVisuals = require(ReplicatedStorage.Gates.GateVisuals)
export type TGateVisuals = GateVisuals.TGateVisuals

export type TSignal = string | number | boolean

export type TNode = { [TGate]: true }

export type TGate = {
	Id: number,
	OwnerId: number,
	Model: TGateModel?,

	Class: TGateClass,
	
	Output: TSignal?,
	
	Inputs: { [string]: TNode }?,
	Connections: { [TGate]: { [string] : { existance: true, Wire: Beam? } } }?,
	
	Attributes: TAttributeTable
}

export type TGateModel = {
	Decoration: {
		Main: BasePart,
	},
	Nodes: Folder,
	Base: BasePart,
}

export type TGateClass = {
	__index: TGateClass,

	name: string,
	inputs: { string },
	output: string?,

	new: (id: number, ownerId: number, gateModel: TGateModel) -> TGate,
	
	Update: (gate: TGate, origin: "Signal" | "Schedule") -> TSignal,
	
	validAttributes: TAttributeTypeTable?,
}

return {}