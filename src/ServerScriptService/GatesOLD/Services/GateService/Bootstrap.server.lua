--!strict
--[[ GATE SERVICE BOOTSTRAP
		Boots the self-contained GateService runtime.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GateService = require(script.Parent)
local PermissionService = require(ServerScriptService.Players.PermissionService)
local GridService = require(ReplicatedStorage.Services.GridService)

--- Startup

-- ----------------------------- ------------- STARTUP ----------------- -----------------------------

GateService.Start({
	PermissionService = PermissionService,
	GridService = GridService,
})
