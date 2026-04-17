--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local GateService = require(ServerScriptService.GateService)

local ClipboardValidation = {}

local MAX_SAVE_NAME_LENGTH = 32
local MAX_GATES_PER_SAVE = 250
local MAX_CONNECTIONS_PER_SAVE = 1000
local MAX_RECURSION_DEPTH = 8

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function validateVector3Table(value: any, path: string): (boolean, string?)
	if type(value) ~= "table" then
		return false, path .. " must be a table."
	end
	if not isFiniteNumber(value.X) or not isFiniteNumber(value.Y) or not isFiniteNumber(value.Z) then
		return false, path .. " must contain finite X, Y and Z numbers."
	end
	return true, nil
end

local function validateSerializedCFrame(value: any, path: string): (boolean, string?)
	if type(value) ~= "table" then
		return false, path .. " must be a table."
	end

	local ok, err = validateVector3Table(value.Position, path .. ".Position")
	if not ok then
		return false, err
	end

	if value.R00 ~= nil then
		local rotationKeys = { "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22" }
		for _, key in ipairs(rotationKeys) do
			if not isFiniteNumber(value[key]) then
				return false, path .. "." .. key .. " must be a finite number."
			end
		end
	end

	return true, nil
end

local function validateDynamicValue(value: any, path: string, depth: number): (boolean, string?)
	if depth > MAX_RECURSION_DEPTH then
		return false, path .. " is nested too deeply."
	end

	local valueType = typeof(value)
	if value == nil or valueType == "string" or valueType == "boolean" then
		return true, nil
	end
	if valueType == "number" then
		if not isFiniteNumber(value) then
			return false, path .. " contains a non-finite number."
		end
		return true, nil
	end
	if valueType == "Color3" or valueType == "Vector2" or valueType == "Vector3" or valueType == "CFrame" or valueType == "EnumItem" then
		return true, nil
	end
	if valueType ~= "table" then
		return false, path .. " contains unsupported type " .. valueType .. "."
	end

	for key, nestedValue in pairs(value) do
		local keyType = typeof(key)
		if keyType ~= "string" and keyType ~= "number" then
			return false, path .. " contains an unsupported key type."
		end

		local ok, err = validateDynamicValue(nestedValue, path .. "[" .. tostring(key) .. "]", depth + 1)
		if not ok then
			return false, err
		end
	end

	return true, nil
end

function ClipboardValidation.ValidateSave(saveTable: any): (boolean, string?)
	if type(saveTable) ~= "table" then
		return false, "Save must be a table."
	end

	if not isFiniteNumber(saveTable.Version) then
		return false, "Save version is invalid."
	end
	if not isFiniteNumber(saveTable.Timestamp) then
		return false, "Save timestamp is invalid."
	end
	if type(saveTable.SaveName) ~= "string" or saveTable.SaveName == "" or #saveTable.SaveName > MAX_SAVE_NAME_LENGTH then
		return false, "Save name is invalid."
	end

	if type(saveTable.Owner) ~= "table" or type(saveTable.Owner.Name) ~= "string" or not isFiniteNumber(saveTable.Owner.Id) then
		return false, "Save owner is invalid."
	end

	local ok, err = validateVector3Table(saveTable.Offset, "Offset")
	if not ok then
		return false, err
	end

	ok, err = validateSerializedCFrame(saveTable.BaseCFrame, "BaseCFrame")
	if not ok then
		return false, err
	end

	ok, err = validateVector3Table(saveTable.BoxPosition, "BoxPosition")
	if not ok then
		return false, err
	end

	ok, err = validateVector3Table(saveTable.BoxSize, "BoxSize")
	if not ok then
		return false, err
	end

	if type(saveTable.Gates) ~= "table" then
		return false, "Save gates are invalid."
	end

	local gateEntries = {}
	local gateCount = 0
	for gateId, gateData in pairs(saveTable.Gates) do
		gateCount += 1
		if gateCount > MAX_GATES_PER_SAVE then
			return false, "Save contains too many gates."
		end
		if type(gateId) ~= "number" or not isFiniteNumber(gateId) then
			return false, "Save contains an invalid gate id."
		end
		if type(gateData) ~= "table" then
			return false, "Save contains an invalid gate entry."
		end
		if type(gateData.Specification) ~= "string" then
			return false, "Gate " .. tostring(gateId) .. " is missing its specification."
		end

		local specification = GateService.GetSpecification(gateData.Specification)
		if specification == nil then
			return false, "Gate " .. tostring(gateId) .. " uses unknown specification '" .. gateData.Specification .. "'."
		end

		ok, err = validateSerializedCFrame(gateData.CFrame, "Gates[" .. tostring(gateId) .. "].CFrame")
		if not ok then
			return false, err
		end

		ok, err = validateDynamicValue(gateData.Visuals or {}, "Gates[" .. tostring(gateId) .. "].Visuals", 0)
		if not ok then
			return false, err
		end

		if type(gateData.Attributes) ~= "table" then
			return false, "Gate " .. tostring(gateId) .. " has invalid attributes."
		end
		for attributeName, attributeValue in pairs(gateData.Attributes) do
			if type(attributeName) ~= "string" then
				return false, "Gate " .. tostring(gateId) .. " has an invalid attribute name."
			end
			if specification.AttributeData[attributeName] == nil then
				return false, "Gate " .. tostring(gateId) .. " uses unknown attribute '" .. attributeName .. "'."
			end
			local attributeType = typeof(attributeValue)
			if attributeType ~= "string" and attributeType ~= "number" and attributeType ~= "boolean" then
				return false, "Gate " .. tostring(gateId) .. " has an invalid attribute value."
			end
			if attributeType == "number" and not isFiniteNumber(attributeValue) then
				return false, "Gate " .. tostring(gateId) .. " has a non-finite attribute value."
			end
		end

		if gateData.State ~= nil then
			ok, err = validateDynamicValue(gateData.State, "Gates[" .. tostring(gateId) .. "].State", 0)
			if not ok then
				return false, err
			end
		end

		gateEntries[gateId] = {
			Gate = gateData,
			Specification = specification,
		}
	end

	if gateCount == 0 then
		return false, "Save contains no gates."
	end

	if type(saveTable.Connections) ~= "table" then
		return false, "Save connections are invalid."
	end
	if #saveTable.Connections > MAX_CONNECTIONS_PER_SAVE then
		return false, "Save contains too many connections."
	end

	for index, connection in ipairs(saveTable.Connections) do
		if type(connection) ~= "table" then
			return false, "Connection " .. tostring(index) .. " is invalid."
		end
		if type(connection.fromGate) ~= "number" or gateEntries[connection.fromGate] == nil then
			return false, "Connection " .. tostring(index) .. " references an invalid source gate."
		end
		if type(connection.toGate) ~= "number" or gateEntries[connection.toGate] == nil then
			return false, "Connection " .. tostring(index) .. " references an invalid target gate."
		end
		if type(connection.fromNode) ~= "string" or type(connection.toNode) ~= "string" then
			return false, "Connection " .. tostring(index) .. " uses invalid node names."
		end
		if not isFiniteNumber(connection.timestamp) then
			return false, "Connection " .. tostring(index) .. " has an invalid timestamp."
		end

		local fromSpecification = gateEntries[connection.fromGate].Specification
		local toSpecification = gateEntries[connection.toGate].Specification

		local hasFromNode = false
		for _, outputName in ipairs(fromSpecification.Nodes.Outputs) do
			if outputName == connection.fromNode then
				hasFromNode = true
				break
			end
		end
		if not hasFromNode then
			return false, "Connection " .. tostring(index) .. " references missing output '" .. connection.fromNode .. "'."
		end

		local hasToNode = false
		for _, inputName in ipairs(toSpecification.Nodes.Inputs) do
			if inputName == connection.toNode then
				hasToNode = true
				break
			end
		end
		if not hasToNode then
			return false, "Connection " .. tostring(index) .. " references missing input '" .. connection.toNode .. "'."
		end
	end

	return true, nil
end

return ClipboardValidation
