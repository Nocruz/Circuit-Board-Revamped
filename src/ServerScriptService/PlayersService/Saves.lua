--[[ SAVES (DUMMY)
		Stores player saves locally in the server, simulating the actual datastore.
		
		Used for testing.
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
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
		
		local originCFrame = CFrame.new(pivotPosition)
		
		for id, gate in ipairs(save.G) do
			gate.CFrame = GridService.fromCFrame(originCFrame:toObjectSpace(gate.CFrame))
		end
	end
	
	return save
end

local function decompressSave(compressedSave)
	return compressedSave
end

-- ----------------------------- ---------- MODULE DEFINITIONS ----------- -----------------------------

local Saves = {}

function Saves.Load(playerID: number, identifier: string)
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
		
		-- (G)ate 
		local entry = {
			ID = gate.ID,
			Attributes = gate.Attributes,
			Specification = gate.Specification.Name,
			CFrame = gate.Model:GetPivot()
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
			local allOuts = Connections.GetAllOutgoing(entry.ID, name)
			for outGateID, nodes in pairs(allOuts) do
				if G[oldToNewIDs[outGateID]] == nil then continue end
				for node in pairs(nodes) do
					outConns[oldToNewIDs[outGateID]] = outConns[oldToNewIDs[outGateID]] or {}
					table.insert(outConns[oldToNewIDs[outGateID]], node)
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

function Saves.GetAll(playerID: number)
	simulate_lag()
	return playerDatas[playerID] or {}
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Saves
