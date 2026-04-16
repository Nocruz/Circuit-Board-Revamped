--!strict

local UpdateService = {}

--- Public API

function UpdateService.schedule(gate: any, delay: number)
	local GateService = require(script.Parent.GateService)
	GateService.Schedule(gate, delay)
end

function UpdateService.cancel(gate: any)
	local GateService = require(script.Parent.GateService)
	GateService.Cancel(gate)
end

function UpdateService.propagate(gate: any)
	local GateService = require(script.Parent.GateService)
	GateService.Propagate(gate)
end

return UpdateService
