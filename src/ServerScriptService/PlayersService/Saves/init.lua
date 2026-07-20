--[[ SAVES
		Handles datastorage stuff.
		I'm too tired to make a description. You know what this does
]]

-- Requires and Services
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Safezones = require(script.Parent.Safezones)
local GateService = require(ServerScriptService.GateService)
local GatesHandler = require(ServerScriptService.GateService.Handlers.GatesHandler)
local Connections = require(ServerScriptService.GateService.Connections)
local SpecificationsHandler = require(ServerScriptService.GateService.Handlers.SpecificationsHandler)
local GridService = require(ReplicatedStorage.GridService)
local Serializer = require(script.Serializer)

-- Database
local SaveDataStore = DataStoreService:GetDataStore("TEST_STUFF")

-- Constants
local SAVE_VERSION = 3 -- Used if Specifications change names or whatever

-- ----------------------------- ------------ HELPER METHODS ------------- -----------------------------

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local copy = {}
	for k, v in pairs(t) do copy[deepCopy(k)] = deepCopy(v) end
	return setmetatable(copy, getmetatable(t))
end

local function packSave(save)
	for _, gate in ipairs(save.G) do
		gate.ID = nil
		gate.CFrame = Serializer.SerializeAs(gate.CFrame, "GridCFrame")
		gate.Attributes = Serializer.Serialize(gate.Attributes)
		gate.State = Serializer.Serialize(gate.State)
	end
	
	return save
end

local function unpackSave(packedSave)
	local unpackedSave = packedSave
	
	for _, gate in ipairs(unpackedSave.G) do
		gate.CFrame = Serializer.DeserializeAs(gate.CFrame, "GridCFrame")
		gate.Attributes = Serializer.Deserialize(gate.Attributes)
		gate.State = Serializer.Deserialize(gate.State)
	end
	
	return unpackedSave
end

-- ----------------------------- ---------- MODULE DEFINITIONS ----------- -----------------------------

local Saves = {}

function Saves.Load(playerID: number, identifier: string, loadCFrame: CFrame): (boolean, string?)
	local playerKey = tostring(playerID)
	
	local success, playerSaves = pcall(SaveDataStore.GetAsync, SaveDataStore, playerKey)
	if not success then return false, "DataStore fetch failed! Try again shortly." end
	if not playerSaves or next(playerSaves) == nil then return false, "Player has no saves!" end
	
	local masterSaveData = playerSaves[identifier]
	if not masterSaveData then return false, "Player has no such save!" end
	
	local saveData = unpackSave(deepCopy(masterSaveData))
	
	-- Validate CFrames
	for offsetID, data in ipairs(saveData.G) do
		if offsetID % 20 == 0 then task.wait() end
		local cframe = loadCFrame:toWorldSpace(data.CFrame._cframe)
		if Safezones.IsGateInSafezone(cframe.Position, Vector3.new(2, 1, 2)) then
			return false, "Save is inside Safezone!"
		end
	end
	
	return GateService.Load(playerID, saveData, loadCFrame)
end

-- Saves the `gates` array under the name `identifier` for the player `playerID`
-- Function assumes all parameters are 100% valid.
-- Returns (success: boolean, error_message: string?, new_entry: table)
function Saves.Save(playerID: number, identifier: string, gates: { number } ): (boolean, string?, { any }?)
	local playerKey = tostring(playerID)
	
	-- Maps for fast lookup
	local oldToNewIDs = {}
	
	-- Compressed save style
	local P = {}
	local G = {}
	local C = {}
	
	-- Double check in case of asynchronous deletes
	local validGates = {}
	for _, id in ipairs(gates) do
		local gate = GatesHandler.Get(id)
		if gate ~= nil then table.insert(validGates, gate) end
	end
	if #validGates == 0 then return false, "No valid gates where selected!", nil end
	
	-- (G)ates
	local originCFrame = GridService.fromCFrame(CFrame.identity)
	do
		local firstPos = validGates[1].Model:GetPivot().Position
		local minX, maxX = firstPos.X, firstPos.X
		local minY, maxY = firstPos.Y, firstPos.Y
		local minZ, maxZ = firstPos.Z, firstPos.Z
		
		for i = 2, #validGates do
			local pos = validGates[i].Model:GetPivot().Position
			if pos.X < minX then minX = pos.X elseif pos.X > maxX then maxX = pos.X end
			if pos.Y < minY then minY = pos.Y elseif pos.Y > maxY then maxY = pos.Y end
			if pos.Z < minZ then minZ = pos.Z elseif pos.Z > maxZ then maxZ = pos.Z end
		end
		
		local halfX = (minX + maxX) / 2
		local halfZ = (minZ + maxZ) / 2
		local pivotPosition = Vector3.new(halfX, minY, halfZ)
		originCFrame = GridService.fromCFrame(CFrame.new(pivotPosition))
	end
	
	for _, gate in ipairs(validGates) do
		local relativeCFrame = GridService.fromCFrame(originCFrame:ToObjectSpace(gate.Model:GetPivot()))
		
		local entry = {
			ID = gate.ID,
			Attributes = deepCopy(gate.Attributes),
			Specification = gate.Specification.Name,
			CFrame = relativeCFrame,
			State = {
				Signals = gate.Nodes.Signals,
				Internal = gate.InternalState
			}
		}
		
		table.insert(G, entry)
		oldToNewIDs[entry.ID] = #G
	end
	
	-- (C)onnections
	for newID, entry in pairs(G) do
		local outConns = {}
		
		local specification = SpecificationsHandler.Get(entry.Specification)
		for i, name in ipairs(specification.Nodes.Outputs) do
			for outGateID, nodes in pairs(Connections.GetAllOutgoing(entry.ID, name)) do
				if G[oldToNewIDs[outGateID]] == nil then continue end
				
				-- Roblox thinks the sparce array is a literal array, so I need to stringify the keys
				local serializationKey = tostring(oldToNewIDs[outGateID])
				for node in pairs(nodes) do
					outConns[name] = outConns[name] or {} -- C[newID][outputName]
					outConns[name][serializationKey] = outConns[name][serializationKey] or {}
					table.insert(outConns[name][serializationKey], node)
				end
			end
		end
		
		if next(outConns) ~= nil then
			C[tostring(newID)] = outConns
		end
	end
	
	local workingSaveData = {
		P = P, G = G, C = C,
		timestamp = os.time(),
		version = SAVE_VERSION
	}
	
	local packedSave = packSave(workingSaveData)
	local success, result = pcall(function()
		SaveDataStore:UpdateAsync(playerKey, function(oldSavesMap)
			local currentMap = oldSavesMap or {}
			currentMap[identifier] = packedSave
			return currentMap
		end)
	end)
	
	if not success then return false, "Database transaction failed to save: " .. tostring(result) end
	return true, nil, unpackSave(deepCopy(packedSave))
end

function Saves.Erase(playerID: number, identifier: string): (boolean, string?)
	local playerKey = tostring(playerID)
	local itemExisted = false
	
	local success, result = pcall(function()
		SaveDataStore:UpdateAsync(playerKey, function(oldSavesMap)
			if not oldSavesMap or not oldSavesMap[identifier] then return nil end

			itemExisted = true
			oldSavesMap[identifier] = nil
			return oldSavesMap
		end)
	end)
	
	if not success then return false, "Erase transaction aborted: " .. tostring(result) end
	if not itemExisted then return false, "Target layout profile does not exist" end
	
	return true
end

function Saves.GetAll(playerID: number)
	local playerKey = tostring(playerID)
	
	local success, playerSaves = pcall(function() return SaveDataStore:GetAsync(playerKey) end)
	if not success or not playerSaves then return {} end
	
	local decompressedSaves = {}
	for name, data in pairs(playerSaves) do decompressedSaves[name] = unpackSave(data) end
	return decompressedSaves
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Saves
