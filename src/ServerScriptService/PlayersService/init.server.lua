--[[ PLAYERS SERVICE
		Exposes events to cross the Server-Client boundary.
		Handles Permissions, Cooldowns, Filtering and Input sanitization.    
]]

-- Requires and Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Permissions = require(script.Permissions)
local Interactions = require(script.Interactions)
local GateService = require(script.Parent.GateService)

-- References
local gatesFolder = Workspace:FindFirstChild("Gates")
assert(gatesFolder, "No Gates folder under Workspace!")

-- ----------------------------- --------- PLAYER LIFETIME EVENTS -------- -----------------------------

local TIME_TO_DESTROY_GATES_AFTER_LEAVING = 5 * 60 -- 5 minutes
local destroyAllGatesTimeouts: { [number]: thread } = {}

Players.PlayerAdded:Connect(function(player: Player)
	local stringID = tostring(player.UserId)
	
	-- If the player disconnected recently
	if gatesFolder:FindFirstChild(stringID) then
		if destroyAllGatesTimeouts[player.UserId] ~= nil then
			task.cancel(destroyAllGatesTimeouts[player.UserId])
			destroyAllGatesTimeouts[player.UserId] = nil
		end
	else
		local folder = Instance.new("Folder") do
			folder.Name = stringID
			folder.Parent = gatesFolder
		end
	end
	
	-- Register the player in the Permissions service
	Permissions.RegisterPlayer(player.UserId)
end)

Players.PlayerRemoving:Connect(function(player: Player, reason: Enum.PlayerExitReason)
	-- Start a timer to destroy all their gates
	destroyAllGatesTimeouts[player.UserId] = task.delay(TIME_TO_DESTROY_GATES_AFTER_LEAVING, function()
		local playerFolder = gatesFolder:FindFirstChild(tostring(player.UserId))
		if playerFolder then
			-- TODO: Implement gate destruction
			warn("Leave timer has ran out for player " .. player.UserId .. ", but I have not implemented all gate destruction!")
		end
		
		destroyAllGatesTimeouts[player.UserId] = nil
	end)
	
	Permissions.UnregisterPlayer(player.UserId)
end)

-- ----------------------------- ------------ CLIENT REQUESTS ------------ -----------------------------

-- Permission request
Interactions.CreateQuery("Permission", { "GateID", "Action" }, function(player: Player, gate, action: Permissions.ActionType)
	if not Permissions.CanPlayerDo(player.UserId, gate.OwnerID, action, gate.Specification.Name) then
		print("Player " .. tostring(player.UserId) .. " lacks permissions to " .. action .. " a gate owned by " .. gate.OwnerID .. " of type " .. gate.Specification.Name)
		return false, "Lacks permissions to do this!"
	end
	
	return true		
end)

-- Gate spawner
Interactions.CreateEvent("Spawn", { "GateID", "CFrame" }, function(player: Player, gate, cframe: CFrame)
	if not Permissions.CanPlayerDo(player.UserId, gate.OwnerID, "Spawn", gate.Specification.Name) then
		return false, "Lacks permissions to spawn a gate of this type"
	end		
	
	GateService.Instantiate(player.UserId, gate.Specification.Name, cframe, gate.Visuals, gate.Attributes)
	return true
end)

-- Gate mover
Interactions.CreateEvent("Move", { "GateID", "CFrame" }, function(player: Player, gate, cframe: CFrame)
	if not Permissions.CanPlayerDo(player.UserId, gate.OwnerID, "Move") then
		return false, "Lacks permissions to move this gate"
	end		
	
	GateService.Move(gate.ID, cframe)
	return true
end)
