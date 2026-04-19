--!strict

local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local Safezones = require(ServerScriptService.Players.Safezones)
local GateService = require(ServerScriptService.GateService)
local SaveManager = require(ServerScriptService.GateService.Saves)
local PermissionService = require(ServerScriptService.Players.PermissionService)
local ClipboardCodec = require(ServerScriptService.Players.ClipboardCodec)
local ClipboardValidation = require(ServerScriptService.Players.ClipboardValidation)

type TSaveSummary = {
	Title: string,
	GateCount: number,
	WireCount: number,
	UpdatedAt: number,
}

type TPreviewGate = {
	CFrame: any,
}

type TPreviewData = {
	BaseCFrame: any,
	Gates: { TPreviewGate },
}

type TEncodedSave = any
type TPlayerSaves = { [string]: TEncodedSave }
type TRootSaves = { [string]: TPlayerSaves }

local ClipboardService = {}

local DATASTORE_NAME = "ClipboardSaves"
local DATASTORE_KEY = "SAVE_BETA_0"
local MAX_SAVES_PER_PLAYER = 24
local MAX_SAVE_NAME_LENGTH = 32
local DATASTORE_ERROR_MESSAGE = "Clipboard data couldn't be reached right now."

local ClipboardDataStore = DataStoreService:GetDataStore(DATASTORE_NAME)

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function tableToVector(table: { X: number, Y: number, Z: number }): Vector3
	return Vector3.new(table.X, table.Y, table.Z)
end

local function tableToCFrame(t)
    if not t or not t.Position then return CFrame.new() end
    local p = tableToVector(t.Position)
    if t.R00 == nil then
        return CFrame.new(p)
    end

    return CFrame.new(
        p.X, p.Y, p.Z,
        t.R00, t.R01, t.R02,
        t.R10, t.R11, t.R12,
        t.R20, t.R21, t.R22
    )
end

local function validateAnchorCFrame(anchorCFrame: CFrame): (boolean, string?)
	if typeof(anchorCFrame) ~= "CFrame" then
		return false, "Invalid load position."
	end

	if not Safezones.IsValidPlacement(anchorCFrame) then
		return false, "Invalid placement"
	end

	return true, nil
end

local function normalizeSaveName(rawName: any): string
	if type(rawName) ~= "string" then
		return ""
	end

	local stripped = rawName:gsub("[%c]", "")
	return string.sub(stripped:match("^%s*(.-)%s*$") or "", 1, MAX_SAVE_NAME_LENGTH)
end

local function normalizeGateIds(player: Player, rawGateIds: { any }): (boolean, string?, { number }?)
	if type(rawGateIds) ~= "table" then
		return false, "Invalid clipboard selection."
	end

	local seen = {}
	local gateIds = {}

	for _, rawId in ipairs(rawGateIds) do
		if type(rawId) ~= "number" or not isFiniteNumber(rawId) then
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

local function getPlayerSaves(rootSaves: TRootSaves, userId: number, createIfMissing: boolean): (TPlayerSaves?, string?)
	local userKey = tostring(userId)
	local playerSaves = rootSaves[userKey]

	if playerSaves == nil then
		if not createIfMissing then
			return {}, nil
		end

		playerSaves = {}
		rootSaves[userKey] = playerSaves
	end

	if type(playerSaves) ~= "table" then
		return nil, "Clipboard data is corrupted."
	end

	return playerSaves, nil
end

local function readRootSaves(): (boolean, string?, TRootSaves?)
	local success, result = pcall(function()
		return ClipboardDataStore:GetAsync(DATASTORE_KEY)
	end)
	if not success then
		return false, DATASTORE_ERROR_MESSAGE, nil
	end

	if result == nil then
		return true, nil, {}
	end
	if type(result) ~= "table" then
		return false, "Clipboard data is corrupted.", nil
	end

	return true, nil, result :: TRootSaves
end

local function mutatePlayerSaves<T>(userId: number, mutator: (TPlayerSaves) -> (boolean, string?, T?)): (boolean, string?, T?)
	local mutatorMessage: string?
	local mutatorResult: T?

	local success = pcall(function()
		ClipboardDataStore:UpdateAsync(DATASTORE_KEY, function(currentValue)
			local rootSaves = currentValue
			if rootSaves == nil then
				rootSaves = {}
			end
			if type(rootSaves) ~= "table" then
				mutatorMessage = "Clipboard data is corrupted."
				return nil
			end

			local playerSaves, err = getPlayerSaves(rootSaves :: TRootSaves, userId, true)
			if playerSaves == nil then
				mutatorMessage = err
				return nil
			end

			local ok, message, result = mutator(playerSaves)
			if not ok then
				mutatorMessage = message
				return nil
			end

			mutatorResult = result
			return rootSaves
		end)
	end)

	if not success then
		return false, DATASTORE_ERROR_MESSAGE, nil
	end
	if mutatorMessage ~= nil then
		return false, mutatorMessage, nil
	end

	return true, nil, mutatorResult
end

local function buildSaveSummaries(playerSaves: TPlayerSaves): { TSaveSummary }
	local summaries = {}

	for title, encodedSave in pairs(playerSaves) do
		if type(title) == "string" and type(encodedSave) == "table" then
			local gates = if type(encodedSave.Gates) == "table" then encodedSave.Gates else {}
			local connections = if type(encodedSave.Connections) == "table" then encodedSave.Connections else {}
			table.insert(summaries, {
				Title = title,
				GateCount = #gates,
				WireCount = #connections,
				UpdatedAt = if isFiniteNumber(encodedSave.Timestamp) then encodedSave.Timestamp else 0,
			})
		end
	end

	table.sort(summaries, function(a, b)
		if a.UpdatedAt == b.UpdatedAt then
			return a.Title < b.Title
		end
		return a.UpdatedAt > b.UpdatedAt
	end)

	return summaries
end

local function getDecodedSave(playerSaves: TPlayerSaves, rawSaveName: any): (boolean, string?, any?)
	local saveName = normalizeSaveName(rawSaveName)
	if saveName == "" then
		return false, "Pick a save first.", nil
	end

	local encodedSave = playerSaves[saveName]
	if encodedSave == nil then
		return false, "That save does not exist.", nil
	end
	if type(encodedSave) ~= "table" then
		return false, "That save is corrupted.", nil
	end

	local decodeSuccess, decodedSave = pcall(function()
		return ClipboardCodec.DecodeSave(encodedSave)
	end)
	if not decodeSuccess then
		return false, "That save is corrupted.", nil
	end

	decodedSave.SaveName = saveName

	local valid, validationMessage = ClipboardValidation.ValidateSave(decodedSave)
	if not valid then
		return false, validationMessage or "That save is invalid.", nil
	end

	return true, nil, decodedSave
end

function ClipboardService.ListSaves(userId: number): (boolean, string?, { TSaveSummary }?)
	local success, message, rootSaves = readRootSaves()
	if not success or rootSaves == nil then
		return false, message, nil
	end

	local playerSaves, err = getPlayerSaves(rootSaves, userId, false)
	if playerSaves == nil then
		return false, err, nil
	end

	return true, nil, buildSaveSummaries(playerSaves)
end

function ClipboardService.GetSavePreview(userId: number, rawSaveName: any): (boolean, string?, TPreviewData?)
	local success, message, rootSaves = readRootSaves()
	if not success or rootSaves == nil then
		return false, message, nil
	end

	local playerSaves, err = getPlayerSaves(rootSaves, userId, false)
	if playerSaves == nil then
		return false, err, nil
	end

	local decodedSuccess, decodedMessage, saveTable = getDecodedSave(playerSaves, rawSaveName)
	if not decodedSuccess or saveTable == nil then
		return false, decodedMessage, nil
	end

	local previewGates = {}
	for gateId, gateData in pairs(saveTable.Gates) do
		table.insert(previewGates, {
			Id = gateId,
			CFrame = gateData.CFrame,
		})
	end

	table.sort(previewGates, function(a, b)
		return a.Id < b.Id
	end)

	local previewData = {
		BaseCFrame = saveTable.BaseCFrame,
		Gates = {},
	}

	for _, gateData in ipairs(previewGates) do
		table.insert(previewData.Gates, {
			CFrame = gateData.CFrame,
		})
	end

	return true, nil, previewData
end

function ClipboardService.SaveSelection(player: Player, rawSaveName: any, rawGateIds: { any }): (boolean, string?, { TSaveSummary }?)
	local saveName = normalizeSaveName(rawSaveName)
	if saveName == "" then
		return false, "Give the save a name.", nil
	end

	local validSelection, selectionMessage, gateIds = normalizeGateIds(player, rawGateIds)
	if not validSelection or gateIds == nil then
		return false, selectionMessage or "Invalid clipboard selection.", nil
	end

	local saveTable = SaveManager.Save(gateIds, {
		Owner = {
			Name = player.Name,
			Id = player.UserId,
		},
		SaveName = saveName,
	})

	local validSave, validationMessage = ClipboardValidation.ValidateSave(saveTable)
	if not validSave then
		return false, validationMessage or "Clipboard save failed validation.", nil
	end

	local encodeSuccess, encodedSave = pcall(function()
		return ClipboardCodec.EncodeSave(saveTable)
	end)
	if not encodeSuccess then
		return false, "Clipboard save couldn't be serialized.", nil
	end

	return mutatePlayerSaves(player.UserId, function(playerSaves)
		local saveCount = 0
		for _ in pairs(playerSaves) do
			saveCount += 1
		end

		if playerSaves[saveName] == nil and saveCount >= MAX_SAVES_PER_PLAYER then
			return false, "Clipboard is full.", nil
		end

		playerSaves[saveName] = encodedSave
		return true, nil, buildSaveSummaries(playerSaves)
	end)
end

function ClipboardService.DeleteSave(player: Player, rawSaveName: any): (boolean, string?, { TSaveSummary }?)
	local saveName = normalizeSaveName(rawSaveName)
	if saveName == "" then
		return false, "Pick a save first.", nil
	end

	return mutatePlayerSaves(player.UserId, function(playerSaves)
		if playerSaves[saveName] == nil then
			return false, "That save does not exist.", nil
		end

		playerSaves[saveName] = nil
		return true, nil, buildSaveSummaries(playerSaves)
	end)
end

function ClipboardService.LoadSave(player: Player, rawSaveName: any, anchorCFrame: CFrame): (boolean, string?)
	local validAnchor, anchorMessage = validateAnchorCFrame(anchorCFrame)
	if not validAnchor then
		return false, anchorMessage or "Invalid load position."
	end

	local success, message, rootSaves = readRootSaves()
	if not success or rootSaves == nil then
		return false, message
	end

	local playerSaves, err = getPlayerSaves(rootSaves, player.UserId, false)
	if playerSaves == nil then
		return false, err
	end

	local decodedSuccess, decodedMessage, saveTable = getDecodedSave(playerSaves, rawSaveName)
	if not decodedSuccess or saveTable == nil then
		return false, decodedMessage
	end

	do -- Testing stuff
		local saveCFrame = CFrame.new(tableToVector(saveTable.BoxPosition))
		
    local basePosition = tableToCFrame(saveTable.BaseCFrame).Position
    local basePivot = CFrame.new(basePosition)

    -- 1. Get the save's offset relative to the original save's base position
    local relativeOffset = basePivot:Inverse() * saveCFrame
    -- 2. Apply this offset to the new anchor (which preserves the client's rotation)
    local finalCFrame = anchorCFrame * relativeOffset

		local Box1 = Instance.new("Part")
		Box1.Anchored = true
		Box1.Size = Vector3.one
		Box1.Name = "anchorCFrame"
		Box1.Parent = workspace
		Box1.CFrame = finalCFrame
		
		if not Safezones.IsValidBoxPlacement(saveCFrame, tableToVector(saveTable.BoxSize)) then
			return false, "Invalid placement"
		end
	end

	local loadSuccess, loadResult = SaveManager.Load(saveTable, player.UserId, {
		Offset = anchorCFrame,
	})
	if not loadSuccess then
		return false, tostring(loadResult)
	end

	return true, nil
end

return ClipboardService
