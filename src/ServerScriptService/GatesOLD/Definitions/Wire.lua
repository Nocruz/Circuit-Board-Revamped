--!strict
--[[ WIRE
		Compatibility alias for the real wire runtime service.
]]

local ServerScriptService = game:GetService("ServerScriptService")

return require(ServerScriptService.Gates.Services.WireService)
