--!strict
--[[ SERVER BOOTSTRAP
		This script brings the GateRegistry to life
		Should run only once on startup, and is responsible of
		  loading all gate classes into the
		  registry.
		Valid classes are decided from ServerScriptService.Gates.Classes.Modules
]]

-- Requires and services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GateRegistry = require(ServerScriptService.Gates.Services.GateRegistry)
local GateVisuals = require(ReplicatedStorage.Gates.GateVisuals)
local GridCFrame = require(ReplicatedStorage.GridService.GridCFrame)

local Spawner = require(ServerScriptService.Gates.Actions.Spawner)

-- References
local Modules = ServerScriptService.Gates.Classes.Modules

-- Debugging
local Logger = require(game:GetService("ReplicatedStorage").Shared.LoggerService)
local log = Logger.new("Bootstrap")

-- ----------------------------- ---- INITIALIZING GATE REGISTRY --------- ---------------------------

log.info("Building GateRegistry's class register")
for _, module in pairs(Modules:GetChildren()) do
	log.info("	Registering " .. module.Name)
	
	local class = require(module) :: GateRegistry.TGateClass
	assert(class, "Error while loading " .. module.Name .. " class module.")
	
	GateRegistry:registerClass(class)
end

-- ----------------------------- --------- SPAWN SERVER GATES ------------ ---------------------------

log.info("Spawning server gates from placeholders")

local GridCFrame = require(game:GetService("ReplicatedStorage").GridService.GridCFrame)

for _, placeholder in pairs(workspace.Gates.Server:GetChildren()) do
	log.info("	Spawning " .. placeholder.Name)
	assert(placeholder and typeof(placeholder) == "Instance" and (placeholder:IsA("Part") or placeholder:IsA("UnionOperation")), "Placeholder is not a part or union")
	
	local class = GateRegistry:tryGetGateClass(placeholder.Name)
	if not class then 
		log.warn("Placeholder " .. placeholder.Name .. " has no gate class!") 
		continue 
	end
	
	local visuals = GateVisuals.getVisualsFromName(placeholder.Name)
	assert(visuals)
	
	local cframe = GridCFrame.fromCFrame(placeholder:GetPivot())._cframe
	
	Spawner.Spawn(class, visuals, cframe, 0)
	placeholder:Destroy()
end