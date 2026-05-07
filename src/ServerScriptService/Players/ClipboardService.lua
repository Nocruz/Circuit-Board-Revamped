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

local DATASTORE_NAME = "SAVE_BETA_1"
local LEGACY_DATASTORE_NAME = "ClipboardSaves"
local LEGACY_DATASTORE_KEY = "SAVE_BETA_0"
local MAX_SAVES_PER_PLAYER = 24
local MAX_SAVE_NAME_LENGTH = 32
local MAX_GATES_PER_SAVE = 700
local DATASTORE_ERROR_MESSAGE = "Clipboard data couldn't be reached right now."

local ClipboardDataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
local LegacyClipboardDataStore = DataStoreService:GetDataStore(LEGACY_DATASTORE_NAME)
local DATASTORE_RETRY_COUNT = 3
local DATASTORE_RETRY_DELAY = 0.2

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function tableToVector(value: { X: number, Y: number, Z: number }): Vector3
	return Vector3.new(value.X, value.Y, value.Z)
end

local function runWithRetries(callback)
	local lastError

	for attempt = 1, DATASTORE_RETRY_COUNT do
		local success, result = pcall(callback)
		if success then
			return true, result
		end

		lastError = result
		if attempt < DATASTORE_RETRY_COUNT then
			task.wait(DATASTORE_RETRY_DELAY * attempt)
		end
	end

	return false, lastError
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
		return false, "Invalid clipboard selection.", nil
	end

	local seen = {}
	local gateIds = {}

	for _, rawId in ipairs(rawGateIds) do
		if type(rawId) ~= "number" or not isFiniteNumber(rawId) then
			return false, "Invalid clipboard selection.", nil
		end
		if seen[rawId] then
			continue
		end

		local gate = GateService.GetGateInstance(rawId)
		if not gate then
			return false, "Selection contains a missing gate.", nil
		end
		if not PermissionService.canPlayerDo(player.UserId, gate.OwnerId, "Move") then
			return false, "Selection contains gates you can't move.", nil
		end
		if not PermissionService.canPlayerDo(player.UserId, player.UserId, "Spawn", gate.Name) then
			return false, "Selection contains gates you can't spawn.", nil
		end

		seen[rawId] = true
		table.insert(gateIds, rawId)
	end

	if #gateIds == 0 then
		return false, "Select at least one gate first.", nil
	end
	if #gateIds > MAX_GATES_PER_SAVE then
		return false, "Clipboard saves can contain at most " .. tostring(MAX_GATES_PER_SAVE) .. " gates.", nil
	end

	return true, nil, gateIds
end

local function buildSaveSummaries(playerSaves: TPlayerSaves): { TSaveSummary }
	local summaries = {}

	for title, encodedSave in pairs(playerSaves) do
		if type(title) == "string" and type(encodedSave) == "table" then
			local summarySuccess, gateCount, wireCount = pcall(function()
				return ClipboardCodec.GetSummary(encodedSave)
			end)

			if summarySuccess then
				table.insert(summaries, {
					Title = title,
					GateCount = gateCount,
					WireCount = wireCount,
				})
			end
		end
	end

	table.sort(summaries, function(left, right)
		return string.lower(left.Title) < string.lower(right.Title)
	end)

	return summaries
end

local function readLegacyRootSaves(): (boolean, string?, TRootSaves?)
	local success, result = runWithRetries(function()
		return LegacyClipboardDataStore:GetAsync(LEGACY_DATASTORE_KEY)
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

local function compactLegacyPlayerSaves(userId: number): (boolean, string?, TPlayerSaves?)
	local success, message, rootSaves = readLegacyRootSaves()
	if not success or rootSaves == nil then
		return false, message, nil
	end

	local userKey = tostring(userId)
	local legacyPlayerSaves = rootSaves[userKey]
	if legacyPlayerSaves == nil then
		return true, nil, {}
	end
	if type(legacyPlayerSaves) ~= "table" then
		return false, "Clipboard data is corrupted.", nil
	end

	local compactSaves = {}
	for rawSaveName, legacySave in pairs(legacyPlayerSaves) do
		local saveName = normalizeSaveName(rawSaveName)
		if saveName == "" or type(legacySave) ~= "table" then
			warn("Skipping corrupt legacy clipboard save for user " .. userKey .. ".")
			continue
		end

		local decodeSuccess, decodedSave = pcall(function()
			return ClipboardCodec.DecodeLegacySave(legacySave)
		end)
		if not decodeSuccess then
			warn("Skipping legacy clipboard save '" .. saveName .. "' because it could not be decoded.")
			continue
		end

		decodedSave.SaveName = saveName
		local valid, validationMessage = ClipboardValidation.ValidateSave(decodedSave)
		if not valid then
			warn("Skipping legacy clipboard save '" .. saveName .. "': " .. tostring(validationMessage))
			continue
		end

		local encodeSuccess, compactSave = pcall(function()
			return ClipboardCodec.EncodeSave(decodedSave)
		end)
		if not encodeSuccess then
			warn("Skipping legacy clipboard save '" .. saveName .. "': " .. tostring(compactSave))
			continue
		end

		compactSaves[saveName] = compactSave
	end

	return true, nil, compactSaves
end

local function migratePlayerSaves(userId: number): (boolean, string?, TPlayerSaves?)
	local success, message, compactSaves = compactLegacyPlayerSaves(userId)
	if not success or compactSaves == nil then
		return false, message, nil
	end

	local userKey = tostring(userId)
	local updateSuccess, result = runWithRetries(function()
		return ClipboardDataStore:UpdateAsync(userKey, function(currentValue)
			if currentValue == nil then
				return compactSaves
			end

			if type(currentValue) ~= "table" then
				return currentValue
			end

			local playerSaves = currentValue :: TPlayerSaves
			for saveName, compactSave in pairs(compactSaves) do
				if playerSaves[saveName] == nil then
					playerSaves[saveName] = compactSave
				end
			end

			return playerSaves
		end)
	end)

	if not updateSuccess then
		return false, DATASTORE_ERROR_MESSAGE, nil
	end
	if type(result) ~= "table" then
		return false, "Clipboard data is corrupted.", nil
	end

	return true, nil, result :: TPlayerSaves
end

local function readPlayerSaves(userId: number): (boolean, string?, TPlayerSaves?)
	local userKey = tostring(userId)
	local success, result = runWithRetries(function()
		return ClipboardDataStore:GetAsync(userKey)
	end)
	if not success then
		return false, DATASTORE_ERROR_MESSAGE, nil
	end

	if result == nil then
		return migratePlayerSaves(userId)
	end
	if type(result) ~= "table" then
		return false, "Clipboard data is corrupted.", nil
	end

	return true, nil, result :: TPlayerSaves
end

local function mutatePlayerSaves<T>(userId: number, mutator: (TPlayerSaves) -> (boolean, string?, T?)): (boolean, string?, T?)
	local mutatorMessage: string?
	local mutatorResult: T?
	local userKey = tostring(userId)

	local success = runWithRetries(function()
		ClipboardDataStore:UpdateAsync(userKey, function(currentValue)
			local playerSaves = currentValue
			if playerSaves == nil then
				playerSaves = {}
			end
			if type(playerSaves) ~= "table" then
				mutatorMessage = "Clipboard data is corrupted."
				return nil
			end

			local ok, message, result = mutator(playerSaves :: TPlayerSaves)
			if not ok then
				mutatorMessage = message
				return nil
			end

			mutatorResult = result
			return playerSaves
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

function ClipboardService.MigratePlayerSaves(userId: number): (boolean, string?)
	local success, message = migratePlayerSaves(userId)
	return success, message
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
	local success, message, playerSaves = readPlayerSaves(userId)
	if not success or playerSaves == nil then
		return false, message, nil
	end

	return true, nil, buildSaveSummaries(playerSaves)
end

function ClipboardService.GetSavePreview(userId: number, rawSaveName: any): (boolean, string?, TPreviewData?)
	local success, message, playerSaves = readPlayerSaves(userId)
	if not success or playerSaves == nil then
		return false, message, nil
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

	table.sort(previewGates, function(left, right)
		return left.Id < right.Id
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
		return false, tostring(encodedSave), nil
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

	local success, message, playerSaves = readPlayerSaves(player.UserId)
	if not success or playerSaves == nil then
		return false, message
	end

	local decodedSuccess, decodedMessage, saveTable = getDecodedSave(playerSaves, rawSaveName)
	if not decodedSuccess or saveTable == nil then
		return false, decodedMessage
	end

	do
		local relativeBoxPosition = tableToVector(saveTable.BoxPosition)
		local boxSize = tableToVector(saveTable.BoxSize)
		local boxCFrame = anchorCFrame:ToWorldSpace(CFrame.new(relativeBoxPosition))

		if not Safezones.IsValidBoxPlacement(boxCFrame, boxSize) then
			return false, "Invalid placement: Blueprint intersects a Safezone."
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
