--!strict
--[[ GATE REGISTRY
		This has no behaviour by itself.
		It's just a record that holds:
		  - Gate classes
		  - Gate's IDs and class objects
]]

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local Types = require(ServerScriptService.Gates.Definitions.Types)

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- ---------------------------

export type TGate = Types.TGate
export type TGateClass = Types.TGateClass

export type TGateRegistry = {
	Classes: { [string]: TGateClass },
	Gates        : { [number]: TGate },
	
	-- Static functions
	tryGetGateClass	: (self: TGateRegistry, name: string) -> TGateClass?,
	tryGetGateFromId   : (self: TGateRegistry, id: number) -> TGate?,
	
	registerGate: (self: TGateRegistry, id: number, gate: TGate) -> (),
	unregisterGate: (self: TGateRegistry, id: number) -> (),
	registerClass: (self: TGateRegistry, class: TGateClass) -> (),
}

-- ----------------------------- ------- REGISTRY DEFINITION -------- ---------------------------

local GateRegistry: TGateRegistry = {
	Classes = {},
	Gates 	= {},
	
	tryGetGateClass = function(self: TGateRegistry, name: string): TGateClass?
		return self.Classes[name]
	end,
	tryGetGateFromId = function(self: TGateRegistry, id: number): TGate
		return self.Gates[id]
	end,
	
	registerGate = function(self: TGateRegistry, id: number, gate: TGate)
		assert(not self.Gates[id], "Gate with ID " .. id .. " already exists!")
		self.Gates[id] = gate
	end,
	unregisterGate = function(self: TGateRegistry, id: number)
		assert(self.Gates[id], "Gate with ID " .. id .. " does not exist!")
		self.Gates[id] = nil
	end,
	registerClass = function(self: TGateRegistry, class: TGateClass)
		assert(not self.Classes[class.name], "Gate class " .. class.name .. " already exists!")
		self.Classes[class.name] = class
	end,
}

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return GateRegistry