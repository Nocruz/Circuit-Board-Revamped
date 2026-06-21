--[[ PLAYERS SERVICE
		Exposes events to cross the Server-Client boundary.
		Handles Permissions, Cooldowns, Filtering and Input sanitization.    
]]

-- Requires and Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Permissions = require(script.Permissions)

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
		-- Cancel destruction timeout
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
			warn("Leave timer has ran out for player " .. player.UserId .. ", but I have not implemented all gate destruction!")
		end
		
		destroyAllGatesTimeouts[player.UserId] = nil
	end)
end)
