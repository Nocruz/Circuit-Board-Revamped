--[[ SAVES (DUMMY)
		Stores player saves locally in the server, simulating the actual datastore.
		
		Used for testing.
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Safezones = require(script.Parent.Safezones)
local GateService = require(ServerScriptService.GateService)
local GatesHandler = require(ServerScriptService.GateService.Handlers.GatesHandler)
local Connections = require(ServerScriptService.GateService.Connections)
local SpecificationsHandler = require(ServerScriptService.GateService.Handlers.SpecificationsHandler)

local GridService = require(ReplicatedStorage.GridService)

-- Data
local playerDatas = {}

-- Constants
local SAVE_VERSION = 1 -- Used if Specifications change names or whatever

-- ----------------------------- ------------ HELPER METHODS ------------- -----------------------------

local function simulate_lag()
	task.wait(1)
end

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
			gate.CFrame = GridService.fromCFrame(originCFrame._cframe:toObjectSpace(gate.CFrame))
		end
	end
	
	return save
end

local function decompressSave(compressedSave)
	return compressedSave
end

-- ----------------------------- ---------- MODULE DEFINITIONS ----------- -----------------------------

local Saves = {}

function Saves.Load(playerID: number, identifier: string, loadCFrame: CFrame): (boolean, string?)
	if not playerDatas[playerID] then return false, "Player has no saves!" end
	local saveData = playerDatas[playerID][identifier]
	if not saveData then return false, "Player has no such save!" end
	
	-- Validate CFrames
	for offsetID, data in ipairs(saveData.G) do
		local cframe = loadCFrame:toWorldSpace(data.CFrame._cframe)
		if Safezones.IsGateInSafezone(cframe.Position, Vector3.new(2, 1, 2)) then
			return false, "Save is inside Safezone!"
		end
	end
	
	return GateService.Load(playerID, saveData, loadCFrame)
end

-- Returns (success: boolean, error_message: string?, new_entry: table)
function Saves.Save(playerID: number, identifier: string, gates: { number } ): (boolean, string?, { any }?)
	simulate_lag()
	
	-- Maps for fast lookup
	local savedGateIDs = {}
	local oldToNewIDs = {}
	
	-- Compressed save style
	local P = {}
	local G = {}
	local C = {}
	
	for i, gateID in ipairs(gates) do
		local gate = GatesHandler.Get(gateID)
		
		-- (P)alette
		local paletteID = nil
		if next(gate.Visuals) ~= nil then
			for id, palette in pairs(P) do
				if areVisualsEqual(gate.Visuals, palette) then
					paletteID = id
					break
				end
			end
			if paletteID == nil then
				P[#P + 1] = gate.Visuals
				paletteID = #P
			end
		end
		
		-- (G)ate 
		local entry = {
			ID = gate.ID,
			Attributes = deepCopy(gate.Attributes),
			Specification = gate.Specification.Name,
			CFrame = gate.Model:GetPivot(),
			State = {
				Signals = deepCopy(gate.Nodes.Signals),
				Internal = deepCopy(gate.InternalState)
			}
		}
		G[#G + 1] = entry
		savedGateIDs[entry.ID] = true
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
			C[newID] = outConns
		end
	end
	
	local saveData = { P = P, G = G, C = C,
		timestamp = os.time(),
		version = SAVE_VERSION
	}
	playerDatas[playerID] = playerDatas[playerID] or {}
	playerDatas[playerID][identifier] = compressSave(saveData)
	return true, nil, decompressSave(playerDatas[playerID][identifier])
end

function Saves.Erase(playerID: number, identifier: string): (boolean, string?)
	local data = playerDatas[playerID]
	if not data then return false, "Player has no saves" end
	local save = data[identifier]
	if not save then return false, "Player has no save " .. identifier end
	
	playerDatas[playerID][identifier] = nil
	return true
end

function Saves.GetAll(playerID: number)
	simulate_lag()
	return playerDatas[playerID] or {}
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Saves
