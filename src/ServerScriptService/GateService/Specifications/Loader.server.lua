--[[ SPECIFICATION LOADER
		This just loads all the specification tables
]]

-- Requires and Services
local ServerScriptService = game:GetService("ServerScriptService")

local GateService = require(ServerScriptService.GateService)

-- Actual work
for _, child in ipairs(script.Parent:GetChildren()) do
	if not child:IsA("ModuleScript") then continue end
	
	GateService.RegisterSpecification(require(child), child.Name)
end
