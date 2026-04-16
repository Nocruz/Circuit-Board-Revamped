--!strict
--[[ GATE CLASS
		Compatibility wrapper kept for the existing gate modules.
		The real shared runtime now lives in Gate.lua.
]]

local Gate = require(script.Parent.Gate)

export type TGateClass = Gate.TGateClass

local GateClass = {}
GateClass.__index = GateClass

function GateClass.CreateGate(id: number, ownerId: number, gateModel: Model)
	return Gate.CreateGate(id, ownerId, gateModel)
end

function GateClass.UpdateGate(gate: Gate.TGate)
	return gate.Output or false
end

setmetatable(GateClass, { __index = Gate })

return GateClass
