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
		-- Find centre
		local centre = Vector3.zero
		for _, gate in ipairs(save.G) do centre += gate.CFrame.Position end
		centre /= count
		
		-- Find gate closest to centre
		local min, closest = (save.G[1].CFrame.Position - centre).Magnitude, save.G[1].CFrame
		for id = 2, count do
			local distance = (save.G[id].CFrame.Position - centre).Magnitude
			if distance < min then
				min = distance
				closest = CFrame.new(save.G[id].CFrame)
			end
		end
		
		-- Update all CFrames to be offsets
		for id, gate in ipairs(save.G) do
			gate.CFrame = GridService.fromCFrame(closest:ToObjectSpace(gate.CFrame))
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
