--!strict
--[[ GATE SERVICE HELPERS
		Shared pure-ish helper methods for GateService children.
]]

local TextService = game:GetService("TextService")

local Helpers = {}

local ACTION_COOLDOWN = 0.05

-- ----------------------------- ------------ CLONING ------------------- -----------------------------

function Helpers.CloneInputOffsets(offsets: any): { [string]: Vector2 }
	local cloned = {}
	if type(offsets) ~= "table" then
		return cloned
	end

	for inputName, offset in pairs(offsets) do
		if typeof(offset) == "Vector2" then
			cloned[inputName] = offset
		end
	end

	return cloned
end

function Helpers.CloneVisuals(visuals: any): any
	return {
		MainColor = visuals.MainColor,
		MainMaterial = visuals.MainMaterial,
		DisplayName = visuals.DisplayName,
		PrefabName = visuals.PrefabName,
		OutputOffset = visuals.OutputOffset,
		InputOffsetOverrides = Helpers.CloneInputOffsets(visuals.InputOffsetOverrides or visuals.InputOffsets),
	}
end

function Helpers.CloneAttributeValues(values: { [string]: any }): { [string]: any }
	local cloned = {}
	for key, value in pairs(values) do
		cloned[key] = value
	end
	return cloned
end

-- ----------------------------- ----------- VALIDATION ----------------- -----------------------------

function Helpers.IsFiniteNumber(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge
end

function Helpers.ValidateCFrame(cframe: any): (boolean, string?)
	if typeof(cframe) ~= "CFrame" then
		return false, "Invalid position"
	end

	local position = cframe.Position
	if position.Magnitude > 1000 then
		return false, "Too far from middle"
	end
	if position.Y < -5 then
		return false, "Too low"
	end
	if not Helpers.IsFiniteNumber(position.X) or not Helpers.IsFiniteNumber(position.Y) or not Helpers.IsFiniteNumber(position.Z) then
		return false, "Invalid position"
	end

	return true, nil
end

function Helpers.ValidateVector3(value: any): (boolean, string?)
	if typeof(value) ~= "Vector3" then
		return false, "Invalid selection"
	end

	if value.Magnitude > 1000 then
		return false, "Selection is too far from the board"
	end
	if not Helpers.IsFiniteNumber(value.X) or not Helpers.IsFiniteNumber(value.Y) or not Helpers.IsFiniteNumber(value.Z) then
		return false, "Invalid selection"
	end

	return true, nil
end

-- ----------------------------- ------------ PLAYERS ------------------- -----------------------------

function Helpers.ConsumeCooldown(state: any, player: Player): (boolean, string?)
	if state.PlayerCooldowns[player.UserId] ~= nil then
		return false, "Too fast!"
	end

	state.PlayerCooldowns[player.UserId] = true
	task.delay(ACTION_COOLDOWN, function()
		state.PlayerCooldowns[player.UserId] = nil
	end)

	return true, nil
end

function Helpers.FilterText(player: Player, text: string, maxLength: number): string
	local success, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)

	if success and type(result) == "string" then
		return string.sub(result, 1, maxLength)
	end

	return string.sub(text, 1, maxLength)
end

function Helpers.GetPlayerFolder(state: any, ownerId: number): Folder
	local folderName = if ownerId == 0 then "Server" else tostring(ownerId)
	local cached = state.PlayerFolders[folderName]
	if cached ~= nil then
		return cached
	end

	local existing = state.GatesRoot:FindFirstChild(folderName)
	if existing and existing:IsA("Folder") then
		state.PlayerFolders[folderName] = existing
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = state.GatesRoot
	state.PlayerFolders[folderName] = folder
	return folder
end

-- ----------------------------- ----------- GEOMETRY ------------------- -----------------------------

function Helpers.ContainsPoint(minBounds: Vector3, maxBounds: Vector3, point: Vector3): boolean
	return point.X >= minBounds.X and point.X <= maxBounds.X
		and point.Y >= minBounds.Y and point.Y <= maxBounds.Y
		and point.Z >= minBounds.Z and point.Z <= maxBounds.Z
end

function Helpers.NormalizeBounds(a: Vector3, b: Vector3): (Vector3, Vector3)
	return Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)),
		Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
end

function Helpers.NormalizeTitle(title: string): string
	return string.sub(title:match("^%s*(.-)%s*$") or "", 1, 32)
end

function Helpers.RotationToCFrame(position: Vector3, rotation: any): CFrame
	if rotation == "PosX" then
		return CFrame.lookAt(position, position + Vector3.xAxis)
	elseif rotation == "NegX" then
		return CFrame.lookAt(position, position - Vector3.xAxis)
	elseif rotation == "PosZ" then
		return CFrame.lookAt(position, position + Vector3.zAxis)
	end

	return CFrame.lookAt(position, position - Vector3.zAxis)
end

return Helpers
