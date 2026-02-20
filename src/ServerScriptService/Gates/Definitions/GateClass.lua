--!strict
--[[ GATE CLASS
		This module defines the structure of a GateClass
		
		Design rule: Gates should be simple. Let players discover advanced stuff by themselves.
]]

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ServerScriptService.Gates.Definitions.Types)

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- -----------------------------

type TGate = Types.TGate
type TGateModel = Types.TGateModel
export type TGateClass = Types.TGateClass

-- ----------------------------- ------ ABSTRACT CLASS DEFINITION ------ -----------------------------

local GateClass = {} :: TGateClass
GateClass.__index = GateClass

function GateClass.new(id: number, ownerId: number, gateModel: TGateModel): TGate
	local gate = setmetatable({} :: TGate, GateClass)

	gate.Id = id
	gate.OwnerId = ownerId
	
	gate.Class = GateClass
	gate.Model = gateModel

	return gate
end

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return GateClass