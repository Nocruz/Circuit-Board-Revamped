--!strict
--[[ SPAWNER
		Spawns and destroys gate instances.
]]

-- Requires and services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GateVisualsService = require(ReplicatedStorage.Services.GateVisualsService)
local UpdateService = require(ServerScriptService.Gates.Services.UpdateService)

local GateRegistry = require(ServerScriptService.Gates.Definitions.GateRegistry)
local GateModel = require(ServerScriptService.Gates.Definitions.GateModel)

-- Debugging
local Logger = require(ReplicatedStorage.Services.LoggerService)
local log = Logger.new("Spawn")

-- State
local lastId = 0

local function nextId(): number
	lastId += 1
	return lastId
end

local function ensureOwnerFolder(ownerId: number): Folder
	local gatesFolder = workspace:WaitForChild("Gates")
	local folderName = if ownerId == 0 then "Server" else tostring(ownerId)
	local ownerFolder = gatesFolder:FindFirstChild(folderName)

	if ownerFolder and ownerFolder:IsA("Folder") then
		return ownerFolder
	end

	local newFolder = Instance.new("Folder")
	newFolder.Name = folderName
	newFolder.Parent = gatesFolder
	return newFolder
end

local Spawner = {}

-- ----------------------------- ----------- SPAWN GATE --------------- ---------------------------

function Spawner.Spawn(class: GateRegistry.TGateClass, visuals: GateVisualsService.TGateVisuals, cframe: CFrame, ownerId: number): GateRegistry.TGate
	log.info("Spawning " .. class.name)
	
	local id = nextId()
	local gateModel = GateModel.Instantiate(class, visuals, cframe)
	gateModel.Parent = ensureOwnerFolder(ownerId)
	gateModel:SetAttribute("Id", id)
	gateModel:SetAttribute("Owner", ownerId)
	gateModel:SetAttribute("ClassName", class.name)
	
	local gate = class.new and class.new(id, ownerId, gateModel)
	assert(gate ~= nil, "Gate class instance failed on new()")
	
	GateRegistry.RegisterGate(gate)
	UpdateService.propagate(gate)
	
	return gate
end

function Spawner.Despawn(id: number)
	local gate = GateRegistry.TryGetGateFromId(id)
	assert(gate, "Gate " .. id .. " not found!")
	
	log.info("Despawning " .. id)
	
	UpdateService.cancel(gate)
	GateRegistry.UnregisterGate(id)
	
	local gateModel = gate.Model :: Model?
	if gateModel then
		gateModel:Destroy()
	end
end

return Spawner
