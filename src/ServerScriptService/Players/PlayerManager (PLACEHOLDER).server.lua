--!strict
-- Requires and Services
local PermissionService = require(script.Parent.PermissionService)

-- This folder contains all gates
local GatesFolder = workspace.Gates
local CharactersFolder = workspace.Characters

local function OnCharacterAdded(character)
	task.wait()
	if character and character.Parent then character.Parent = CharactersFolder end
end

local function OnPlayerAdded(player: Player)
	local stringId = tostring(player.UserId) -- Use UserId as the folder name
	-- Check if a folder with this UserId already exists
	if GatesFolder:FindFirstChild(stringId) then
		print("Folder already exists for player " .. player.Name)
	else
		local newFolder = Instance.new("Folder")
		newFolder.Name = stringId
		newFolder.Parent = GatesFolder
		print("Created folder for player " .. player.Name .. " with ID " .. stringId)
	end

	-- Register the player in the permission service
	PermissionService.registerPlayer(player.UserId)
	print("Registered player " .. player.Name .. " with ID " .. stringId)
	
	player.CharacterAdded:Connect(OnCharacterAdded)
	if player.Character then OnCharacterAdded(player.Character) end
end
game.Players.PlayerAdded:Connect(OnPlayerAdded)


local function OnDisconnect(player: Player, reason: Enum.PlayerExitReason)

	-- Unregister the player in the permission service
	PermissionService.unregisterPlayer(player.UserId)
	print("Unregistered player " .. player.Name .. " with ID " .. player.UserId)

end
game.Players.PlayerRemoving:Connect(OnDisconnect)