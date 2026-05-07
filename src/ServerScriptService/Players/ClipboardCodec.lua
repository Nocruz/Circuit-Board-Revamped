--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GateService = require(ServerScriptService.GateService)
local GridService = require(ReplicatedStorage.Services.GridService)
local SpecificationIndex = require(ServerScriptService.GateService.Specifications)

local ClipboardCodec = {}

local TYPE_KEY = "__clipType"
local MAX_GATES_PER_SAVE = 700
local BYTE_MAX = 255
local ROTATION_TOLERANCE = 1e-3

local ROTATION_TO_NUMBER = {
	PosX = 0,
	PosZ = 1,
	NegX = 2,
	NegZ = 3,
}

local ROTATION_TO_VECTOR = {
	[0] = Vector3.xAxis,
	[1] = Vector3.zAxis,
	[2] = -Vector3.xAxis,
	[3] = -Vector3.zAxis,
}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function isByte(value: any): boolean
	return type(value) == "number" and value % 1 == 0 and value >= 0 and value <= BYTE_MAX
end

local function serializeVector3(value: Vector3)
	return {
		X = value.X,
		Y = value.Y,
		Z = value.Z,
	}
end

local function deserializeVector3(value: any): Vector3
	if type(value) ~= "table" then
		return Vector3.zero
	end

	return Vector3.new(value.X or 0, value.Y or 0, value.Z or 0)
end

local function serializeCFrame(value: CFrame)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
	return {
		Position = serializeVector3(Vector3.new(x, y, z)),
		R00 = r00,
		R01 = r01,
		R02 = r02,
		R10 = r10,
		R11 = r11,
		R12 = r12,
		R20 = r20,
		R21 = r21,
		R22 = r22,
	}
end

local function deserializeCFrame(value: any): CFrame
	if type(value) ~= "table" or value.Position == nil then
		return CFrame.new()
	end

	local position = deserializeVector3(value.Position)
	if value.R00 == nil then
		return CFrame.new(position)
	end

	return CFrame.new(
		position.X,
		position.Y,
		position.Z,
		value.R00,
		value.R01 or 0,
		value.R02 or 0,
		value.R10 or 0,
		value.R11 or 1,
		value.R12 or 0,
		value.R20 or 0,
		value.R21 or 0,
		value.R22 or 1
	)
end

local function encodeCFrame(value: CFrame)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = value:GetComponents()
	return {
		[TYPE_KEY] = "CFrame",
		X = x,
		Y = y,
		Z = z,
		R00 = r00,
		R01 = r01,
		R02 = r02,
		R10 = r10,
		R11 = r11,
		R12 = r12,
		R20 = r20,
		R21 = r21,
		R22 = r22,
	}
end

local function decodeCFrame(value: any): CFrame
	return CFrame.new(
		value.X or 0,
		value.Y or 0,
		value.Z or 0,
		value.R00 or 1,
		value.R01 or 0,
		value.R02 or 0,
		value.R10 or 0,
		value.R11 or 1,
		value.R12 or 0,
		value.R20 or 0,
		value.R21 or 0,
		value.R22 or 1
	)
end

local function encodeValue(value: any): any
	local valueType = typeof(value)
	if value == nil or valueType == "string" or valueType == "boolean" then
		return value
	end

	if valueType == "number" then
		assert(isFiniteNumber(value), "ClipboardCodec cannot encode non-finite numbers")
		return value
	end

	if valueType == "Color3" then
		return {
			[TYPE_KEY] = "Color3",
			R = value.R,
			G = value.G,
			B = value.B,
		}
	end

	if valueType == "Vector2" then
		return {
			[TYPE_KEY] = "Vector2",
			X = value.X,
			Y = value.Y,
		}
	end

	if valueType == "Vector3" then
		return {
			[TYPE_KEY] = "Vector3",
			X = value.X,
			Y = value.Y,
			Z = value.Z,
		}
	end

	if valueType == "CFrame" then
		return encodeCFrame(value)
	end

	if valueType == "EnumItem" then
		return {
			[TYPE_KEY] = "EnumItem",
			EnumType = tostring(value.EnumType),
			Name = value.Name,
		}
	end

	if valueType == "table" then
		local encoded = {}
		for key, nestedValue in pairs(value) do
			encoded[key] = encodeValue(nestedValue)
		end
		return encoded
	end

	error("ClipboardCodec cannot encode values of type " .. valueType)
end

local function decodeValue(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local taggedType = value[TYPE_KEY]
	if taggedType == "Color3" then
		return Color3.new(value.R or 0, value.G or 0, value.B or 0)
	end

	if taggedType == "Vector2" then
		return Vector2.new(value.X or 0, value.Y or 0)
	end

	if taggedType == "Vector3" then
		return Vector3.new(value.X or 0, value.Y or 0, value.Z or 0)
	end

	if taggedType == "CFrame" then
		return decodeCFrame(value)
	end

	if taggedType == "EnumItem" then
		local enumType = value.EnumType and Enum[value.EnumType]
		if enumType == nil then
			error("ClipboardCodec cannot decode enum type " .. tostring(value.EnumType))
		end

		local enumItem = value.Name and enumType[value.Name]
		if enumItem == nil then
			error("ClipboardCodec cannot decode enum item " .. tostring(value.Name))
		end

		return enumItem
	end

	local decoded = {}
	for key, nestedValue in pairs(value) do
		if key ~= TYPE_KEY then
			decoded[key] = decodeValue(nestedValue)
		end
	end
	return decoded
end

local function valuesEqual(left: any, right: any): boolean
	local leftType = typeof(left)
	if leftType ~= typeof(right) then
		return false
	end

	if leftType ~= "table" then
		return left == right
	end

	for key, value in pairs(left) do
		if not valuesEqual(value, right[key]) then
			return false
		end
	end
	for key in pairs(right) do
		if left[key] == nil then
			return false
		end
	end

	return true
end

local function stableKey(value: any): string
	local valueType = type(value)
	if valueType ~= "table" then
		return valueType .. ":" .. tostring(value)
	end

	local keys = {}
	for key in pairs(value) do
		table.insert(keys, key)
	end
	table.sort(keys, function(left, right)
		return tostring(left) < tostring(right)
	end)

	local parts = table.create(#keys)
	for _, key in ipairs(keys) do
		table.insert(parts, tostring(key) .. "=" .. stableKey(value[key]))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function packTransform(x: number, y: number, z: number, rotation: number): number
	assert(isByte(x) and isByte(y) and isByte(z), "Clipboard save is too large for the 255x255x255 grid limit.")
	assert(type(rotation) == "number" and rotation >= 0 and rotation <= 3 and rotation % 1 == 0, "Clipboard save contains an invalid gate rotation.")

	return bit32.bor(bit32.lshift(x, 18), bit32.lshift(y, 10), bit32.lshift(z, 2), rotation)
end

local function unpackTransform(packed: any): (number, number, number, number)
	if not isFiniteNumber(packed) or packed % 1 ~= 0 or packed < 0 or bit32.rshift(packed, 26) ~= 0 then
		error("Clipboard save contains an invalid packed transform.")
	end

	local x = bit32.band(bit32.rshift(packed, 18), 0xff)
	local y = bit32.band(bit32.rshift(packed, 10), 0xff)
	local z = bit32.band(bit32.rshift(packed, 2), 0xff)
	local rotation = bit32.band(packed, 0x3)
	return x, y, z, rotation
end

local function cframeFromGrid(x: number, y: number, z: number, rotation: number): CFrame
	local direction = ROTATION_TO_VECTOR[rotation]
	if direction == nil then
		error("Clipboard save contains an invalid gate rotation.")
	end

	local position = Vector3.new(x, y, z)
	return CFrame.lookAt(position, position + direction)
end

local function validateRotation(cframe: CFrame, gridCFrame)
	if cframe.UpVector:Dot(Vector3.yAxis) < 1 - ROTATION_TOLERANCE then
		error("Clipboard save contains an invalid gate rotation.")
	end

	if cframe.LookVector:Dot(gridCFrame._cframe.LookVector) < 1 - ROTATION_TOLERANCE then
		error("Clipboard save contains an invalid gate rotation.")
	end
end

local function compareGateRecords(left, right): boolean
	if left.x ~= right.x then
		return left.x < right.x
	end
	if left.y ~= right.y then
		return left.y < right.y
	end
	if left.z ~= right.z then
		return left.z < right.z
	end
	if left.rotation ~= right.rotation then
		return left.rotation < right.rotation
	end
	if left.specId ~= right.specId then
		return left.specId < right.specId
	end

	return (left.sourceId or 0) < (right.sourceId or 0)
end

local function getIndex(values: { string }, target: any): number?
	if type(target) ~= "string" then
		return nil
	end

	for index, value in ipairs(values) do
		if value == target then
			return index
		end
	end

	return nil
end

local function getVisualOverrides(visuals: any, defaultVisuals: any): any
	local overrides = {}
	if type(visuals) ~= "table" then
		return overrides
	end

	for key, value in pairs(visuals) do
		local defaultValue = if type(defaultVisuals) == "table" then defaultVisuals[key] else nil
		if not valuesEqual(value, defaultValue) then
			overrides[key] = value
		end
	end

	return overrides
end

local function getAttributeOverrides(attributes: any, specification: any): any
	local overrides = {}
	if type(attributes) ~= "table" then
		return overrides
	end

	for attributeName, value in pairs(attributes) do
		local attributeData = specification.AttributeData[attributeName]
		if attributeData == nil then
			error("Gate uses unknown attribute '" .. tostring(attributeName) .. "'.")
		end
		if not valuesEqual(value, attributeData.Default) then
			overrides[attributeName] = value
		end
	end

	return overrides
end

local function getCompactGateSummary(compactSave: any): number
	local gateCount = 0
	if type(compactSave) ~= "table" or type(compactSave.G) ~= "table" then
		return 0
	end

	for _, gatesForSpec in pairs(compactSave.G) do
		if type(gatesForSpec) == "table" then
			gateCount += #gatesForSpec
		end
	end

	return gateCount
end

local function getCompactWireSummary(compactSave: any): number
	local wireCount = 0
	if type(compactSave) ~= "table" or type(compactSave.C) ~= "table" then
		return 0
	end

	for _, sourceConnections in pairs(compactSave.C) do
		if type(sourceConnections) == "table" then
			for _, group in ipairs(sourceConnections) do
				if type(group) == "table" and #group > 2 then
					wireCount += #group - 2
				end
			end
		end
	end

	return wireCount
end

local function computeDecodedBox(records): (any, any)
	if #records == 0 then
		return serializeVector3(Vector3.zero), serializeVector3(Vector3.zero)
	end

	local minX = records[1].x
	local minY = records[1].y
	local minZ = records[1].z
	local maxX = records[1].x
	local maxY = records[1].y
	local maxZ = records[1].z

	for _, record in ipairs(records) do
		minX = math.min(minX, record.x)
		minY = math.min(minY, record.y)
		minZ = math.min(minZ, record.z)
		maxX = math.max(maxX, record.x)
		maxY = math.max(maxY, record.y)
		maxZ = math.max(maxZ, record.z)
	end

	local minVector = Vector3.new(minX - 1, minY, minZ - 1)
	local maxVector = Vector3.new(maxX + 1, maxY + 1, maxZ + 1)
	return serializeVector3((minVector + maxVector) * 0.5), serializeVector3(maxVector - minVector)
end

local function decodeCompactSave(compactSave: any): any
	if type(compactSave) ~= "table" then
		error("Clipboard save is invalid.")
	end

	local palette = if type(compactSave.P) == "table" then compactSave.P else {}
	local records = {}
	local seenTransforms = {}

	if type(compactSave.G) ~= "table" then
		error("Clipboard save gates are invalid.")
	end

	for rawSpecId, gatesForSpec in pairs(compactSave.G) do
		local specId = tonumber(rawSpecId)
		local specName = specId and SpecificationIndex.numberToSpec[specId]
		local specification = specName and GateService.GetSpecification(specName)
		if specId == nil or specName == nil or specification == nil or type(gatesForSpec) ~= "table" then
			error("Clipboard save uses an unknown gate specification.")
		end

		for _, gateData in ipairs(gatesForSpec) do
			if type(gateData) ~= "table" then
				error("Clipboard save contains an invalid gate entry.")
			end

			local x, y, z, rotation = unpackTransform(gateData.f)
			local transformKey = tostring(specId) .. ":" .. tostring(gateData.f)
			if seenTransforms[transformKey] then
				error("Clipboard save contains duplicate gate transforms.")
			end
			seenTransforms[transformKey] = true

			table.insert(records, {
				specId = specId,
				specName = specName,
				specification = specification,
				x = x,
				y = y,
				z = z,
				rotation = rotation,
				data = gateData,
			})
		end
	end

	table.sort(records, compareGateRecords)

	local gates = {}
	local recordsBySavedId = {}
	for savedId, record in ipairs(records) do
		if savedId > MAX_GATES_PER_SAVE then
			error("Clipboard save contains too many gates.")
		end

		record.savedId = savedId
		recordsBySavedId[savedId] = record

		local paletteEntry = nil
		if record.data.p ~= nil then
			if type(record.data.p) ~= "number" or type(palette[record.data.p]) ~= "table" then
				error("Clipboard save references an invalid palette entry.")
			end
			paletteEntry = decodeValue(palette[record.data.p])
		end

		gates[savedId] = {
			Specification = record.specName,
			Visuals = paletteEntry or {},
			Attributes = decodeValue(record.data.a or {}),
			CFrame = serializeCFrame(cframeFromGrid(record.x, record.y, record.z, record.rotation)),
		}
	end

	local connections = {}
	local connectionOrder = 0
	local sourceBuckets = {}

	if compactSave.C ~= nil and type(compactSave.C) ~= "table" then
		error("Clipboard save connections are invalid.")
	end

	for rawFromId, sourceConnections in pairs(compactSave.C or {}) do
		local fromId = tonumber(rawFromId)
		if fromId == nil or recordsBySavedId[fromId] == nil or type(sourceConnections) ~= "table" then
			error("Clipboard save contains an invalid connection source.")
		end

		table.insert(sourceBuckets, {
			fromId = fromId,
			sourceConnections = sourceConnections,
		})
	end

	table.sort(sourceBuckets, function(left, right)
		return left.fromId < right.fromId
	end)

	for _, sourceBucket in ipairs(sourceBuckets) do
		local fromRecord = recordsBySavedId[sourceBucket.fromId]
		for _, group in ipairs(sourceBucket.sourceConnections) do
			if type(group) ~= "table" or #group < 3 then
				error("Clipboard save contains an invalid connection group.")
			end

			local toId = group[1]
			local fromNodeIndex = group[2]
			local toRecord = recordsBySavedId[toId]
			if toRecord == nil then
				error("Clipboard save connection references an invalid target gate.")
			end

			local fromNode = fromRecord.specification.Nodes.Outputs[fromNodeIndex]
			if fromNode == nil then
				error("Clipboard save connection references an invalid source node.")
			end

			for index = 3, #group do
				local toNode = toRecord.specification.Nodes.Inputs[group[index]]
				if toNode == nil then
					error("Clipboard save connection references an invalid target node.")
				end

				connectionOrder += 1
				table.insert(connections, {
					fromGate = sourceBucket.fromId,
					toGate = toId,
					fromNode = fromNode,
					toNode = toNode,
					timestamp = connectionOrder,
				})
			end
		end
	end

	local boxPosition, boxSize = computeDecodedBox(records)
	return {
		Version = 2,
		Timestamp = 0,
		Owner = {
			Name = "Unknown",
			Id = 0,
		},
		SaveName = "",
		Offset = serializeVector3(Vector3.zero),
		BaseCFrame = serializeCFrame(CFrame.new()),
		BoxPosition = boxPosition,
		BoxSize = boxSize,
		Gates = gates,
		Connections = connections,
	}
end

function ClipboardCodec.EncodeSave(saveTable: any): any
	if type(saveTable) ~= "table" or type(saveTable.Gates) ~= "table" then
		error("Clipboard save is invalid.")
	end

	local records = {}
	local minX, minY, minZ

	for sourceId, gateData in pairs(saveTable.Gates) do
		local numericSourceId = tonumber(sourceId)
		if numericSourceId == nil or type(gateData) ~= "table" or type(gateData.Specification) ~= "string" then
			error("Clipboard save contains an invalid gate entry.")
		end

		local specId = SpecificationIndex.specToNumber[gateData.Specification]
		local specification = GateService.GetSpecification(gateData.Specification)
		if specId == nil or specification == nil then
			error("Clipboard save uses unknown specification '" .. tostring(gateData.Specification) .. "'.")
		end

		local cframe = deserializeCFrame(gateData.CFrame)
		local gridCFrame = GridService.fromCFrame(cframe)
		validateRotation(cframe, gridCFrame)
		local rotation = ROTATION_TO_NUMBER[gridCFrame.Rotation]
		if rotation == nil then
			error("Clipboard save contains an invalid gate rotation.")
		end

		local position = gridCFrame.Position
		minX = if minX == nil then position.X else math.min(minX, position.X)
		minY = if minY == nil then position.Y else math.min(minY, position.Y)
		minZ = if minZ == nil then position.Z else math.min(minZ, position.Z)

		table.insert(records, {
			sourceId = numericSourceId,
			specId = specId,
			specName = gateData.Specification,
			specification = specification,
			position = position,
			rotation = rotation,
			visuals = gateData.Visuals,
			attributes = gateData.Attributes,
		})
	end

	if #records == 0 then
		error("Clipboard save contains no gates.")
	end
	if #records > MAX_GATES_PER_SAVE then
		error("Clipboard save contains too many gates.")
	end

	for _, record in ipairs(records) do
		record.x = math.round(record.position.X - minX)
		record.y = math.round(record.position.Y - minY)
		record.z = math.round(record.position.Z - minZ)
		record.f = packTransform(record.x, record.y, record.z, record.rotation)
	end

	table.sort(records, compareGateRecords)

	local seenTransforms = {}
	local recordsBySourceId = {}
	local encodedGates = {}
	local palette = {}
	local paletteByKey = {}

	for savedId, record in ipairs(records) do
		local transformKey = tostring(record.specId) .. ":" .. tostring(record.f)
		if seenTransforms[transformKey] then
			error("Clipboard save contains duplicate gate transforms.")
		end
		seenTransforms[transformKey] = true

		record.savedId = savedId
		recordsBySourceId[record.sourceId] = record

		local gateEntry = {
			f = record.f,
		}

		local attributeOverrides = getAttributeOverrides(record.attributes, record.specification)
		if next(attributeOverrides) ~= nil then
			gateEntry.a = encodeValue(attributeOverrides)
		end

		local visualOverrides = getVisualOverrides(record.visuals, record.specification.DefaultVisuals)
		if next(visualOverrides) ~= nil then
			local encodedVisuals = encodeValue(visualOverrides)
			local key = stableKey(encodedVisuals)
			local paletteIndex = paletteByKey[key]
			if paletteIndex == nil then
				paletteIndex = #palette + 1
				paletteByKey[key] = paletteIndex
				palette[paletteIndex] = encodedVisuals
			end

			gateEntry.p = paletteIndex
		end

		encodedGates[record.specId] = encodedGates[record.specId] or {}
		table.insert(encodedGates[record.specId], gateEntry)
	end

	local wiresBySource = {}
	for order, connection in ipairs(saveTable.Connections or {}) do
		local fromRecord = recordsBySourceId[connection.fromGate]
		local toRecord = recordsBySourceId[connection.toGate]
		if fromRecord ~= nil and toRecord ~= nil then
			local fromNodeIndex = getIndex(fromRecord.specification.Nodes.Outputs, connection.fromNode)
			local toNodeIndex = getIndex(toRecord.specification.Nodes.Inputs, connection.toNode)
			if fromNodeIndex == nil or toNodeIndex == nil then
				error("Clipboard save contains an invalid connection node.")
			end

			wiresBySource[fromRecord.savedId] = wiresBySource[fromRecord.savedId] or {}
			table.insert(wiresBySource[fromRecord.savedId], {
				timestamp = if isFiniteNumber(connection.timestamp) then connection.timestamp else order,
				order = order,
				toId = toRecord.savedId,
				fromNodeIndex = fromNodeIndex,
				toNodeIndex = toNodeIndex,
			})
		end
	end

	local encodedConnections = {}
	for fromSavedId, wires in pairs(wiresBySource) do
		table.sort(wires, function(left, right)
			if left.timestamp == right.timestamp then
				return left.order < right.order
			end
			return left.timestamp < right.timestamp
		end)

		local sourceConnections = {}
		local currentGroup = nil
		for _, wire in ipairs(wires) do
			if currentGroup ~= nil and currentGroup[1] == wire.toId and currentGroup[2] == wire.fromNodeIndex then
				table.insert(currentGroup, wire.toNodeIndex)
			else
				currentGroup = { wire.toId, wire.fromNodeIndex, wire.toNodeIndex }
				table.insert(sourceConnections, currentGroup)
			end
		end

		if #sourceConnections > 0 then
			encodedConnections[fromSavedId] = sourceConnections
		end
	end

	return {
		P = palette,
		G = encodedGates,
		C = encodedConnections,
	}
end

function ClipboardCodec.DecodeLegacySave(encodedSave: any): any
	local decodedGates = {}
	for _, gateData in ipairs(encodedSave.Gates or {}) do
		local sourceId = tonumber(gateData.SourceId)
		if sourceId ~= nil then
			decodedGates[sourceId] = {
				Specification = gateData.Specification,
				Visuals = decodeValue(gateData.Visuals or {}),
				Attributes = decodeValue(gateData.Attributes or {}),
				CFrame = gateData.CFrame,
				State = decodeValue(gateData.State),
			}
		end
	end

	local decodedConnections = {}
	for index, connection in ipairs(encodedSave.Connections or {}) do
		decodedConnections[index] = {
			fromGate = connection.fromGate,
			toGate = connection.toGate,
			fromNode = connection.fromNode,
			toNode = connection.toNode,
			timestamp = connection.timestamp,
		}
	end

	return {
		Version = encodedSave.Version,
		Timestamp = encodedSave.Timestamp,
		Owner = decodeValue(encodedSave.Owner or {}),
		SaveName = encodedSave.SaveName,
		Offset = decodeValue(encodedSave.Offset or {}),
		BaseCFrame = encodedSave.BaseCFrame,
		BoxPosition = encodedSave.BoxPosition,
		BoxSize = encodedSave.BoxSize,
		Gates = decodedGates,
		Connections = decodedConnections,
	}
end

function ClipboardCodec.DecodeSave(encodedSave: any): any
	if type(encodedSave) == "table" and encodedSave.G ~= nil then
		return decodeCompactSave(encodedSave)
	end

	return ClipboardCodec.DecodeLegacySave(encodedSave)
end

function ClipboardCodec.GetSummary(encodedSave: any): (number, number)
	if type(encodedSave) == "table" and encodedSave.G ~= nil then
		return getCompactGateSummary(encodedSave), getCompactWireSummary(encodedSave)
	end

	local gateCount = if type(encodedSave) == "table" and type(encodedSave.Gates) == "table" then #encodedSave.Gates else 0
	local wireCount = if type(encodedSave) == "table" and type(encodedSave.Connections) == "table" then #encodedSave.Connections else 0
	return gateCount, wireCount
end

return ClipboardCodec
