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

-- Database
local SaveDataStore = DataStoreService:GetDataStore("SAVE_BETA_2")

-- Constants
local SAVE_VERSION = 2 -- Used if Specifications change names or whatever
local ROT_TO_INT = { PosX = 0, PosZ = 1, NegX = 2, NegZ = 3 }
local INT_TO_ROT = { [0] = "PosX", [1] = "PosZ", [2] = "NegX", [3] = "NegZ" }

-- ----------------------------- ------------ HELPER METHODS ------------- -----------------------------

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local copy = {}
	for k, v in pairs(t) do copy[deepCopy(k)] = deepCopy(v) end
	return setmetatable(copy, getmetatable(t))
end

type TVisuals = { MainMaterial: Enum.Material, DisplayName:  string, PrefabName:   string, MainColor:    Color3, OutputOffsets: { Vector2 }, InputOffsets:  { Vector2 } }
local function areVisualsEqual(a: TVisuals, b: TVisuals): boolean
	if a.MainMaterial ~= b.MainMaterial then return false end
	if a.DisplayName  ~= b.DisplayName  then return false end
	if a.PrefabName   ~= b.PrefabName   then return false end
	if a.MainColor    ~= b.MainColor    then return false end
	
	if #a.OutputOffsets ~= #b.OutputOffsets then return false end
	for i, offset in ipairs(a.OutputOffsets) do if offset ~= b.OutputOffsets[i] then return false end end
	
	if #a.InputOffsets ~= #b.InputOffsets then return false end
	for i, offset in ipairs(a.InputOffsets)  do if offset ~= b.InputOffsets[i]  then return false end end
	
	return true
end

-- Serializes raw Roblox userdata types into JSON-safe dictionaries
local function serializeData(v: any): any
	local vType = typeof(v)
	if vType == "table" then
		local copy = {}
		for k, val in pairs(v) do
			copy[tostring(k)] = serializeData(val)
		end
		return copy
	elseif vType == "Vector3" then
		return { __type = "Vector3", X = v.X, Y = v.Y, Z = v.Z }
	elseif vType == "Color3" then
		return { __type = "Color3", R = v.R, G = v.G, B = v.B }
	elseif vType == "EnumItem" then
		return { __type = "EnumItem", Enum = tostring(v.EnumType), Name = v.Name }
	elseif vType == "CFrame" then
		return { __type = "CFrame", Components = {v:GetComponents()} }
	elseif vType == "userdata" or vType == "Instance" then
		return nil -- Drop completely unsupported engine types to prevent saves from corrupting
	else
		return v -- Strings, numbers, booleans pass through safely
	end
end

-- Reconstructs original Roblox objects out of stored data-store primitives
local function deserializeData(v: any): any
	if type(v) ~= "table" then return v end
	
	if v.__type then
		if v.__type == "Vector3" then
			return Vector3.new(v.X, v.Y, v.Z)
		elseif v.__type == "Color3" then
			return Color3.new(v.R, v.G, v.B)
		elseif v.__type == "EnumItem" then
			local enumName = string.match(v.Enum, "Enum%.(.+)") or v.Enum
			local success, enumGroup = pcall(function() return Enum[enumName] end)
			if success and enumGroup then
				return enumGroup[v.Name] or enumGroup:GetEnumItems()[1]
			end
			return nil
		elseif v.__type == "CFrame" then
			return CFrame.new(unpack(v.Components))
		end
	end
	
	local copy = {}
	for k, val in pairs(v) do
		copy[k] = deserializeData(val)
	end
	return copy
end

-- This function removes the OldID from the gates (As it is not needed at all)
-- It also sets all CFrames from World-Position (Basically useless) to a new Offset based.
-- The offset is calculated from the centermost gate.
local function compressSave(save)
	-- Remove the OldID data
	for _, gate in ipairs(save.G) do if gate.ID then gate.ID = nil end end
	
	-- Do the CFrame magic
	local count = #save.G
	if count > 0 then
		local firstPos = save.G[1].CFrame.Position
		local minX, maxX = firstPos.X, firstPos.X
		local minY, maxY = firstPos.Y, firstPos.Y
		local minZ, maxZ = firstPos.Z, firstPos.Z
		
		for id = 2, count do
			local pos = save.G[id].CFrame.Position
			if pos.X < minX then minX = pos.X elseif pos.X > maxX then maxX = pos.X end
			if pos.Y < minY then minY = pos.Y elseif pos.Y > maxY then maxY = pos.Y end
			if pos.Z < minZ then minZ = pos.Z elseif pos.Z > maxZ then maxZ = pos.Z end
		end
		
		local halfX = (minX + maxX) / 2
		local halfZ = (minZ + maxZ) / 2
		local pivotPosition = Vector3.new(halfX, minY, halfZ)
		
		local originCFrame = GridService.fromCFrame(CFrame.new(pivotPosition))
		
		for id, gate in ipairs(save.G) do
			local relativeCFrame = originCFrame._cframe:toObjectSpace(gate.CFrame)
			local gridStructure = GridService.fromCFrame(relativeCFrame)
			
			gate.CFrame = {
				X = gridStructure.Position.X,
				Y = gridStructure.Position.Y,
				Z = gridStructure.Position.Z,
				R = ROT_TO_INT[gridStructure.Rotation] or 0
			}
		end
	end
	
	return save
end

local function decompressSave(compressedSave)
	local decompressedSave = deserializeData(compressedSave)
	
	-- Decompresses the CFrame
	for offsetID, data in ipairs(compressedSave.G) do
		local savedCF = data.CFrame
		
		local position = Vector3.new(savedCF.X, savedCF.Y, savedCF.Z)
		local rotationStr = INT_TO_ROT[savedCF.R] or "PosX"
		
		local rotVector
		if rotationStr == "PosZ" then rotVector = position + Vector3.zAxis
		elseif rotationStr == "NegZ" then rotVector = position - Vector3.zAxis
		elseif rotationStr == "PosX" then rotVector = position + Vector3.xAxis
		elseif rotationStr == "NegX" then rotVector = position - Vector3.xAxis
		end
		
		local relativeCFrame = CFrame.lookAt(position, rotVector)
		decompressedSave.G[offsetID].CFrame = GridService.fromCFrame(relativeCFrame)
	end
	return decompressedSave
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
	
	local saveData = decompressSave(deepCopy(masterSaveData))
	
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

-- Returns (success: boolean, error_message: string?, new_entry: table)
function Saves.Save(playerID: number, identifier: string, gates: { number } ): (boolean, string?, { any }?)
	local playerKey = tostring(playerID)
	
	-- Maps for fast lookup
	local oldToNewIDs = {}
	
	-- Compressed save style
	local P = {}
	local G = {}
	local C = {}
	
	for i, gateID in ipairs(gates) do
		local gate = GatesHandler.Get(gateID)
		if not gate then continue end
		
		-- (P)alette
		-- Not implemented
		
		-- (G)ate 
		local entry = {
			ID = gate.ID,
			Attributes = deepCopy(gate.Attributes),
			Specification = gate.Specification.Name,
			CFrame = gate.Model:GetPivot(),
			State = {
				Signals = serializeData(gate.Nodes.Signals),
				Internal = serializeData(gate.InternalState)
			}
		}
		G[#G + 1] = entry
		oldToNewIDs[entry.ID] = #G
	end
	
	-- (C)onnections
	for newID, entry in pairs(G) do
		local outConns = {}
		
		local specification = SpecificationsHandler.Get(entry.Specification)
		for i, name in ipairs(specification.Nodes.Outputs) do
			for outGateID, nodes in pairs(Connections.GetAllOutgoing(entry.ID, name)) do
				if G[oldToNewIDs[outGateID]] == nil then continue end
				
				-- Roblox is so dumb it thinks the sparce array is a literal array, so I need to stringify the keys
				-- God knows what this breaks
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
	
	local workingSaveData = { P = P, G = G, C = C,
		timestamp = os.time(),
		version = SAVE_VERSION
	}
	local finalCompressedSnapshot = compressSave(workingSaveData)
	local success, result = pcall(function()
		SaveDataStore:UpdateAsync(playerKey, function(oldSavesMap)
			local currentMap = oldSavesMap or {}
			currentMap[identifier] = finalCompressedSnapshot
			return currentMap
		end)
	end)
	
	if not success then return false, "Database transaction failed to save: " .. tostring(result) end
	return true, nil, decompressSave(finalCompressedSnapshot)
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
	for name, data in pairs(playerSaves) do decompressedSaves[name] = decompressSave(data) end
	return decompressedSaves
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Saves
