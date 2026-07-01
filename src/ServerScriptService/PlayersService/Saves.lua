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

-- Returns (success: boolean, error_message: string?, new_entry: table)
function Saves.Save(playerID: number, identifier: string, gates: { number } ): (boolean, string?, { any }?)
	simulate_lag()
	
	-- Compressed save style
	local P = {}
	local G = {}
	local C = {}
	
	
	local saveData = { P = P, G = G, C = C,
		timestamp = os.time()
	}
	playerDatas[playerID] = playerDatas[playerID] or {}
	playerDatas[playerID][identifier] = saveData
	return true, nil, saveData
end

function Saves.GetAll(playerID: number)
	simulate_lag()
	return playerDatas[playerID] or {}
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Saves
