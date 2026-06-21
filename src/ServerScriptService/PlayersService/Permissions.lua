--[[ PERMISSIONS
		Handles ownership and interaction rights.
		Permissions are stored as: [OwnerId] = { [Action] = { [AllowedUserId] = true } }
]]

-- ----------------------------- ------------ TYPE DEFINITIONS ----------- -----------------------------

export type ActionType = "Spawn" | "Move" | "Wire" | "Delete" | "Configure" | "Interact"
local ACTIONS = { Spawn = true, Move = true, Wire = true, Delete = true, Configure = true, Interact = true }

export type PermissionMode = "Whitelist" | "Blacklist"

export type PermissionData = { 
	Modes: { [ActionType]: PermissionMode	},
	Players: { [ActionType]: { [number]: true } },
	SpawnSpecificationBlacklist: { [string]: true },
}

-- ----------------------------- ---------------- HANDLER ---------------- -----------------------------

local Permissions = {}
local Handler: { [number]: PermissionData } = {
	[0] = {
		Modes = {
			Spawn			= "Blacklist" :: PermissionMode,
			Move			= "Whitelist" :: PermissionMode,
			Wire			= "Whitelist" :: PermissionMode,
			Delete		= "Whitelist" :: PermissionMode,
			Configure	= "Whitelist" :: PermissionMode,
			Interact	= "Whitelist" :: PermissionMode,
		},
		Players = {
			Spawn = {}, Move = {}, Wire = {}, Delete = {}, Configure = {}, Interact = {},
		},
		SpawnSpecificationBlacklist = {}
	}
}

-- ----------------------------- ------------- REGISTRATIONS ------------- -----------------------------

function Permissions.RegisterPlayer(userId: number)
	if Handler[userId] then return end
	
	Handler[userId] = {
		Modes = {
			Spawn 		= "Blacklist" :: PermissionMode,
			Move			= "Whitelist" :: PermissionMode,
			Wire			= "Whitelist" :: PermissionMode,
			Delete		= "Whitelist" :: PermissionMode,
			Configure	= "Whitelist" :: PermissionMode,
			Interact	= "Blacklist" :: PermissionMode,
		},
		Players = {
			Spawn = {}, Move = {}, Wire = {}, Delete = {}, Configure = {}, Interact = {},
		},
		SpawnSpecificationBlacklist = { }
	}
end

function Permissions.UnregisterPlayer(userId: number)
	Handler[userId] = nil
end

-- ----------------------------- -------------- PERMISSIONS -------------- -----------------------------

function Permissions.SetMode(ownerId: number, action: ActionType, mode: PermissionMode): ()
	if Handler[ownerId] then
		Handler[ownerId].Modes[action] = mode
	end
end

function Permissions.GrantPermission(ownerId: number, targetId: number, action: ActionType): ()
	if Handler[ownerId] then
		Handler[ownerId].Players[action][targetId] = true
	end
end

function Permissions.RevokePermission(ownerId: number, targetId: number, action: ActionType): ()
	if Handler[ownerId] then
		Handler[ownerId].Players[action][targetId] = nil
	end
end

-- ----------------------------- ---------------- GETTERS ---------------- -----------------------------

function Permissions.IsValidAction(action: string): boolean
	return ACTIONS[action] or false
end

function Permissions.CanPlayerDo(userId: number, ownerId: number, action: ActionType, objectType: string?): boolean
	-- Server rules above all
	if userId == 0 then return true end
	
	local data = Handler[ownerId]
	if not data then return false end
	
	-- Check for SPAWN action
	if action == "Spawn" then
		if objectType and Handler[userId].SpawnSpecificationBlacklist[objectType] then return false end
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
	
-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Permissions
