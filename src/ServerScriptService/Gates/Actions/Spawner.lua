--!strict
--[[ SPAWNER
		Spawns and destroys gate instances.
]]

-- Requires and services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GateVisuals = require(ReplicatedStorage.Gates.GateVisuals)
local UpdateService = require(ServerScriptService.Gates.Services.UpdateService)

local GateRegistry = require(ServerScriptService.Gates.Services.GateRegistry)
local GateModel = require(ServerScriptService.Gates.Definitions.GateModel)

-- Debugging
local logger = require(ReplicatedStorage.LoggerService)
local log = logger.new("Spawn")

-- State
local lastId = 0
local function getId(): number lastId = lastId+1
	return lastId
end

local Spawner = {}

-- ----------------------------- ----------- SPAWN GATE --------------- ---------------------------

function Spawner.Spawn(class: GateRegistry.TGateClass, visuals: GateVisuals.TGateVisuals, cframe: CFrame, ownerId: number)
	log.info("Spawning " .. class.name)
	log.info("	Grid Position: " .. tostring(cframe.Position))
	log.info("	Owner " .. if ownerId == 0 then "Server" else tostring(ownerId))
	
	getId()
	
	-- Creates gateModel
	local gateModel = GateModel.instantiate(class, visuals, cframe) :: GateModel.TGateModel | any
	gateModel.Parent = workspace.Gates:FindFirstChild(tostring(if ownerId == 0 then "Server" else tostring(ownerId)))
	if not gateModel.Parent then return log.error("Player " .. ownerId .. " has no Gate Folder! - OR - gateModel was nil or not a Model!") end
	
	gateModel:SetAttribute("Id", lastId)
	gateModel:SetAttribute("Owner", ownerId)
	
	-- Creates gate object
	local gate = class.new(lastId, ownerId, gateModel)
	if not gate then return log.error("Gate class instance failed on new!") end
	
	-- Registers gate
	GateRegistry:registerGate(lastId, gate)
	
	-- Updates gate
	UpdateService.propagate(gate)
end

function Spawner.Despawn(id: number)
	local gate = GateRegistry:tryGetGateFromId(id)
	assert(gate, "Gate " .. id .. " not found!")
	
	log.info("Despawning " .. id)
	
	-- Unregisters gate
	GateRegistry:unregisterGate(id)
	
	-- Destroys gateModel
	local gateModel = gate.Model :: Model?
	if gateModel then
		gateModel:Destroy()
	end
end

return Spawner
