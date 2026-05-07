--[[ PERMISSION SERVICE
	Handles ownership and interaction rights.
	Permissions are stored as: [OwnerId] = { [Action] = { [AllowedUserId] = true } }
]]

-- ----------------------------- ---------- TYPE DEFINITIONS ----------- -----------------------------

export type ActionType = "Spawn" | "Move" | "Wire" | "Delete" | "Configure" | "Interact"
local ACTIONS = { Spawn = true, Move = true, Wire = true, Delete = true, Configure = true, Interact = true, }

local ADMIN_USERS: { [number]: true } = {
	[159768840] = true,
}

export type PermissionMode = "Whitelist" | "Blacklist"

export type PermissionData = { 
	Modes: { [ActionType]: PermissionMode	},
	Players: { [ActionType]: { [number]: true } },
	SpawnBlacklist: { [string]: true },
}

-- ----------------------------- -------------- REGISTRY --------------- -----------------------------

local PermissionService = {}
local Registry: { [number]: PermissionData } = {
	[0] = {
		Modes = {
			Spawn = "Blacklist" :: PermissionMode,
			Move = "Whitelist" :: PermissionMode,
			Wire = "Whitelist" :: PermissionMode,
			Delete = "Whitelist" :: PermissionMode,
			Configure = "Whitelist" :: PermissionMode,
			Interact = "Whitelist" :: PermissionMode,
		},
		Players = {
			Spawn = {}, Move = {}, Wire = {}, Delete = {}, Configure = {}, Interact = {},
		},
		SpawnBlacklist = {}
	}
}

-- ----------------------------- ------------ REGISTRATIONS ------------ -----------------------------

function PermissionService.registerPlayer(userId: number)
	if Registry[userId] then return end
	
	Registry[userId] = {
		Modes = {
			Spawn = "Blacklist" :: PermissionMode,
			Move = "Whitelist" :: PermissionMode,
			Wire = "Whitelist" :: PermissionMode,
			Delete = "Whitelist" :: PermissionMode,
			Configure = "Whitelist" :: PermissionMode,
			Interact = "Blacklist" :: PermissionMode,
		},
		Players = {
			Spawn = {}, Move = {}, Wire = {}, Delete = {}, Configure = {}, Interact = {},
		},
		SpawnBlacklist = {
			["FENCE"] = true,
		}
	}
end

function PermissionService.unregisterPlayer(userId: number)
	Registry[userId] = nil
end

-- ----------------------------- ------------- PERMISSIONS ------------- -----------------------------

function PermissionService.setMode(ownerId: number, action: ActionType, mode: PermissionMode): ()
	if Registry[ownerId] then
		Registry[ownerId].Modes[action] = mode
	end
end

function PermissionService.grantPermission(ownerId: number, targetId: number, action: ActionType): ()
	if Registry[ownerId] then
		Registry[ownerId].Players[action][targetId] = true
	end
end

function PermissionService.revokePermission(ownerId: number, targetId: number, action: ActionType): ()
	if Registry[ownerId] then
		Registry[ownerId].Players[action][targetId] = nil
	end
end

-- ----------------------------- --------------- GETTERS --------------- -----------------------------

function PermissionService.isValidAction(action: string): boolean
	return ACTIONS[action] or false
end

function PermissionService.isAdmin(userId: number): boolean
	return ADMIN_USERS[userId] == true
end

function PermissionService.canPlayerDo(userId: number, ownerId: number, action: ActionType, objectType: string?): boolean
	-- Server rules above all
	if userId == 0 then return true end
	if PermissionService.isAdmin(userId) then return true end
	
	local data = Registry[ownerId]
	if not data then return false end
	
	-- Check for SPAWN action
	if action == "Spawn" then
		if objectType and Registry[userId].SpawnBlacklist[objectType] then return false end
		if userId == ownerId then return true end
	end
	
	local mode = data.Modes[action]
	local isInList = data.Players[action][userId] or false
	
	if mode == "Whitelist" then
		return userId == ownerId or isInList
	else -- Blacklist
		return userId == ownerId or not isInList
	end
end
	
-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

local function OnPlayerAdded(player: Player)
	-- Register the player in the permission service
	PermissionService.registerPlayer(player.UserId)
	print("Registered player " .. player.Name .. " with ID " .. player.UserId)
end
game.Players.PlayerAdded:Connect(OnPlayerAdded)

local function OnDisconnect(player: Player, reason: Enum.PlayerExitReason)

	-- Unregister the player in the permission service
	PermissionService.unregisterPlayer(player.UserId)
	print("Unregistered player " .. player.Name .. " with ID " .. player.UserId)

end
game.Players.PlayerRemoving:Connect(OnDisconnect)

return PermissionService
