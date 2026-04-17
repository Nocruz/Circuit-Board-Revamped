--!strict

local ClipboardCodec = {}

local TYPE_KEY = "__clipType"

local function isFiniteNumber(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
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

local function decodeCFrame(value)
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
			EnumType = value.EnumType.Name,
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
		decoded[key] = decodeValue(nestedValue)
	end
	return decoded
end

function ClipboardCodec.EncodeSave(saveTable: any): any
	local encodedGates = {}
	for gateId, gateData in pairs(saveTable.Gates or {}) do
		table.insert(encodedGates, {
			SourceId = gateId,
			Specification = gateData.Specification,
			Visuals = encodeValue(gateData.Visuals or {}),
			Attributes = encodeValue(gateData.Attributes or {}),
			CFrame = gateData.CFrame,
			State = encodeValue(gateData.State),
		})
	end

	table.sort(encodedGates, function(a, b)
		return (a.SourceId :: number) < (b.SourceId :: number)
	end)

	local encodedConnections = {}
	for index, connection in ipairs(saveTable.Connections or {}) do
		encodedConnections[index] = {
			fromGate = connection.fromGate,
			toGate = connection.toGate,
			fromNode = connection.fromNode,
			toNode = connection.toNode,
			timestamp = connection.timestamp,
		}
	end

	return {
		Version = saveTable.Version,
		Timestamp = saveTable.Timestamp,
		Owner = encodeValue(saveTable.Owner),
		SaveName = saveTable.SaveName,
		Offset = encodeValue(saveTable.Offset),
		BaseCFrame = saveTable.BaseCFrame,
		BoxPosition = saveTable.BoxPosition,
		BoxSize = saveTable.BoxSize,
		Gates = encodedGates,
		Connections = encodedConnections,
	}
end

function ClipboardCodec.DecodeSave(encodedSave: any): any
	local decodedGates = {}
	for _, gateData in ipairs(encodedSave.Gates or {}) do
		decodedGates[gateData.SourceId] = {
			Specification = gateData.Specification,
			Visuals = decodeValue(gateData.Visuals or {}),
			Attributes = decodeValue(gateData.Attributes or {}),
			CFrame = gateData.CFrame,
			State = decodeValue(gateData.State),
		}
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

return ClipboardCodec
