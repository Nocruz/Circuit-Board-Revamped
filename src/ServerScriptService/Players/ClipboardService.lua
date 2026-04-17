--!strict

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local GateService = require(ServerScriptService.GateService)
local SaveManager = require(ServerScriptService.GateService.Saves)
local PermissionService = require(ServerScriptService.Players.PermissionService)

type TDraftSave = {
	SaveTable: any,
	SavedAt: number,
}

type TPreviewGate = {
	CFrame: any,
}

type TPreviewData = {
	BaseCFrame: any,
	Gates: { TPreviewGate },
}

local ClipboardService = {}
local DraftSaves: { [number]: TDraftSave } = {}

local function validateAnchorCFrame(anchorCFrame: CFrame): (boolean, string?)
	if typeof(anchorCFrame) ~= "CFrame" then
		return false, "Invalid load position."
	end

	local position = anchorCFrame.Position
	if position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z then
		return false, "Invalid load position."
	end
	if position.Magnitude > 1000 then
		return false, "That load position is too far away."
	end
	if position.Y < -5 then
		return false, "That load position is too low."
	end

	return true, nil
end

local function normalizeGateIds(player: Player, rawGateIds: { any }): (boolean, string?, { number }?)
	if type(rawGateIds) ~= "table" then
		return false, "Invalid clipboard selection."
	end

	local seen = {}
	local gateIds = {}

	for _, rawId in ipairs(rawGateIds) do
		if type(rawId) ~= "number" then
			return false, "Invalid clipboard selection."
		end
		if seen[rawId] then
			continue
		end

		local gate = GateService.GetGateInstance(rawId)
		if not gate then
			return false, "Selection contains a missing gate."
		end
		if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Move") then
			return false, "Selection contains gates you can't move."
		end
		if not PermissionService.canPlayerDo(player.UserId, player.UserId, "Spawn", gate.Name) then
			return false, "Selection contains gates you can't spawn."
		end

		seen[rawId] = true
		table.insert(gateIds, rawId)
	end

	if #gateIds == 0 then
		return false, "Select at least one gate first."
	end

	return true, nil, gateIds
end

function ClipboardService.HasDraft(userId: number): boolean
	return DraftSaves[userId] ~= nil
end

function ClipboardService.GetDraftPreview(userId: number): (boolean, string?, TPreviewData?)
	local draft = DraftSaves[userId]
	if draft == nil then
		return false, "No clipboard draft has been saved yet.", nil
	end

	local saveTable = draft.SaveTable
	local previewGates = {}

	for _, gateData in pairs(saveTable.Gates or {}) do
		if type(gateData) == "table" and gateData.CFrame ~= nil then
			table.insert(previewGates, {
				CFrame = gateData.CFrame,
			})
		end
	end

	return true, nil, {
		BaseCFrame = saveTable.BaseCFrame,
		Gates = previewGates,
	}
end

function ClipboardService.SaveDraft(player: Player, rawGateIds: { any }): (boolean, string?)
	local valid, message, gateIds = normalizeGateIds(player, rawGateIds)
	if not valid or gateIds == nil then
		return false, message or "Invalid clipboard selection."
	end

	local saveTable = SaveManager.Save(gateIds, {
		Owner = {
			Name = player.Name,
			Id = player.UserId,
		},
		SaveName = "ClipboardDraft",
	})

	DraftSaves[player.UserId] = {
		SaveTable = saveTable,
		SavedAt = os.clock(),
	}

	return true, nil
end

function ClipboardService.LoadDraft(player: Player, anchorCFrame: CFrame): (boolean, string?)
	local draft = DraftSaves[player.UserId]
	if draft == nil then
		return false, "No clipboard draft has been saved yet."
	end

	local validAnchor, anchorMessage = validateAnchorCFrame(anchorCFrame)
	if not validAnchor then
		return false, anchorMessage or "Invalid load position."
	end

	local success, result = SaveManager.Load(draft.SaveTable, player.UserId, {
		Offset = anchorCFrame,
	})
	if not success then
		return false, tostring(result)
	end

	return true, nil
end

Players.PlayerRemoving:Connect(function(player)
	DraftSaves[player.UserId] = nil
end)

return ClipboardService
