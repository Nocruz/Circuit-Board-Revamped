--[[ SAVES (DUMMY)
		Stores player saves locally in the server, simulating the actual datastore.
		
		Used for testing.
]]

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")
local GateService = require(ServerScriptService.GateService)

-- Data
local playerDatas = {}

-- ----------------------------- ------------ HELPER METHODS ------------- -----------------------------

local function simulate_lag()
	task.wait(1)
end

-- ----------------------------- ---------- MODULE DEFINITIONS ----------- -----------------------------

local Saves = {}

function Saves.Save(playerID: number, identifier: string, gates: { number } )
end

function Saves.GetAll(playerID: number)
	simulate_lag()
	return playerDatas[playerID] or {}
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Saves
