--!strict
--[[ TYPES
		Compatibility shim for modules that still import the old shared type
		bundle. The concrete definitions live in Gate, GateClass, Node, and
		GateModel, but keeping this module avoids touching every caller at once.
]]

local Gate = require(script.Parent.Gate)
local GateClass = require(script.Parent.GateClass)
local GateModel = require(script.Parent.GateModel)
local Node = require(script.Parent.Node)
local GateVisualsService = require(game:GetService("ReplicatedStorage").Services.GateVisualsService)
local SignalService = require(script.Parent.Parent.Services.SignalService)
local AttributeService = require(script.Parent.Parent.Services.AttributeService)

export type TGate = Gate.TGate
export type TGateClass = GateClass.TGateClass
export type TGateModel = GateModel.TGateModel
export type TNode = Node.TNode
export type TNodes = Node.TNodes
export type TNodeInformation = Node.TNodeInformation
export type TGateVisuals = GateVisualsService.TGateVisuals
export type TSignal = SignalService.TSignal
export type TAttributeValues = AttributeService.TAttributeValues

return {}
