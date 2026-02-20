--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Gate = require(ServerScriptService.Gates.Definitions.Gate)
local UpdateService = require(ServerScriptService.Gates.Services.UpdateService)
local Types = require(ServerScriptService.Gates.Definitions.Types)

local Configurer = {}

function Configurer.SetAttribute(gate: Types.TGate, attribute: string, value: any)
	Gate.setAttribute(gate, attribute, value)

	UpdateService.propagate(gate)
end

return Configurer