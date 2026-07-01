--[[ SAVES (DUMMY)
		Stores player saves locally in the server, simulating the actual datastore.
		
		Used for testing.
]]

local playerDatas = {}

local function simulate_lag()
	task.wait(1)
end

local Saves = {}

function Saves.GetAll(playerID: number)
	simulate_lag()
	return playerDatas[playerID] or {}
end

return Saves
