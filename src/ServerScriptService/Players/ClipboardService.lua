--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local GateService = require(ServerScriptService.Gates.Services.GateService)

local ClipboardService = {}

--- Public API

function ClipboardService.ListBuilds(userId: number)
	return GateService.ListClipboardBuilds(userId)
end

function ClipboardService.SaveSelection(player: Player, rawTitle: string, cornerA: Vector3, cornerB: Vector3)
	return GateService.SaveClipboardSelection(player, rawTitle, cornerA, cornerB)
end

function ClipboardService.RestoreBuild(player: Player, rawTitle: string, anchorCFrame: CFrame)
	return GateService.RestoreClipboardSelection(player, rawTitle, anchorCFrame)
end

return ClipboardService
