--!strict
--[[ PERMISSIONS PANEL CONTROLLER
		This panel automatically adds and removes players to PlayerListContainer
			It also triggers the events to grant or revoke permissions
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local MessageService = require(game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts").Services.MessageService)

-- GUI References
local PermissionsGui = Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("PermissionsGui")
local MainFrame = PermissionsGui.MainFrame
local PlayerListContainer = MainFrame.PlayerListContainer
local ActionPanelContainer = MainFrame.ActionPanelContainer

local PlayerTemplate = PlayerListContainer.ScrollingFrame.PlayerTemplate
PlayerTemplate.Visible = false

-- References
local Tool = script.Parent

-- Events
local ChangePermissionEvent = ReplicatedStorage.Client.Events.ChangePermission

-- State
local selectedPlayer = nil
PermissionsGui.Enabled = false

-- ----------------------------- --------- HELPER METHODS -------- ------------------------------

local function addPlayerButton(player: Player)
	local button = PlayerTemplate:Clone() :: TextButton
	button.Name = tostring(player.UserId)
	button.Text = player.DisplayName
	button.Visible = true
	button.Parent = PlayerListContainer.ScrollingFrame
	local profileImage = button:WaitForChild("ProfilePicture") :: ImageLabel
	local success, content = pcall(Players.GetUserThumbnailAsync, Players, player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
	if success then profileImage.Image = content end
	
	button.MouseButton1Click:Connect(function() selectedPlayer = player end)
end

local function removePlayerButton(player: Player)
	local button = PlayerListContainer.ScrollingFrame:FindFirstChild(tostring(player.UserId))
	if button then button:Destroy() end
	if selectedPlayer == player then selectedPlayer = nil end
end

-- ----------------------------- --------- TOOL CALLBACKS --------- -------------------------------

Tool.Equipped:Connect(function() PermissionsGui.Enabled = true; print("Enabled") end)
Tool.Unequipped:Connect(function() PermissionsGui.Enabled = false; print("Disabled") end)

for _, player in ipairs(Players:GetPlayers()) do addPlayerButton(player) end
Players.PlayerAdded:Connect(addPlayerButton)
Players.PlayerRemoving:Connect(removePlayerButton)

-- ----------------------------- ------- BUTTON CALLBACKS --------- -------------------------------

-- Spawn
local SpawnFrameCanvasGroup = ActionPanelContainer.SpawnFrame.CanvasGroup
local SpawnAllowButton: TextButton = SpawnFrameCanvasGroup.Allow
local SpawnBlockButton: TextButton = SpawnFrameCanvasGroup.Block

SpawnAllowButton.MouseButton1Click:Connect(function()
	if not selectedPlayer then return MessageService.SendMessage("No player selected") end
	local result, error = ChangePermissionEvent:InvokeServer(selectedPlayer.UserId, "Spawn", true)
	if not result then return MessageService.SendMessage(error) end
end)
SpawnBlockButton.MouseButton1Click:Connect(function()
	if not selectedPlayer then return MessageService.SendMessage("No player selected") end
	local result, error = ChangePermissionEvent:InvokeServer(selectedPlayer.UserId, "Spawn", false)
	if not result then return MessageService.SendMessage(error) end
end)

-- Move
local MoveFrameCanvasGroup = ActionPanelContainer.MoveFrame.CanvasGroup
local MoveAllowButton: TextButton = MoveFrameCanvasGroup.Allow
local MoveBlockButton: TextButton = MoveFrameCanvasGroup.Block

MoveAllowButton.MouseButton1Click:Connect(function()
	if not selectedPlayer then return MessageService.SendMessage("No player selected") end
	local result, error = ChangePermissionEvent:InvokeServer(selectedPlayer.UserId, "Move", true)
	if not result then return MessageService.SendMessage(error) end
end)
MoveBlockButton.MouseButton1Click:Connect(function()
	if not selectedPlayer then return MessageService.SendMessage("No player selected") end
	local result, error = ChangePermissionEvent:InvokeServer(selectedPlayer.UserId, "Move", false)
	if not result then return MessageService.SendMessage(error) end
end)

-- Wire
local WireFrameCanvasGroup = ActionPanelContainer.WireFrame.CanvasGroup
local WireAllowButton: TextButton = WireFrameCanvasGroup.Allow
local WireBlockButton: TextButton = WireFrameCanvasGroup.Block

WireAllowButton.MouseButton1Click:Connect(function()
	if not selectedPlayer then return MessageService.SendMessage("No player selected") end
	local result, error = ChangePermissionEvent:InvokeServer(selectedPlayer.UserId, "Wire", true)
	if not result then return MessageService.SendMessage(error) end
end)
WireBlockButton.MouseButton1Click:Connect(function()
	if not selectedPlayer then return MessageService.SendMessage("No player selected") end
	local result, error = ChangePermissionEvent:InvokeServer(selectedPlayer.UserId, "Wire", false)
	if not result then return MessageService.SendMessage(error) end
end)

-- Delete
local DeleteFrameCanvasGroup = ActionPanelContainer.DeleteFrame.CanvasGroup
local DeleteAllowButton: TextButton = DeleteFrameCanvasGroup.Allow
local DeleteBlockButton: TextButton = DeleteFrameCanvasGroup.Block

DeleteAllowButton.MouseButton1Click:Connect(function()
	if not selectedPlayer then return MessageService.SendMessage("No player selected") end
	local result, error = ChangePermissionEvent:InvokeServer(selectedPlayer.UserId, "Delete", true)
	if not result then return MessageService.SendMessage(error) end
end)
DeleteBlockButton.MouseButton1Click:Connect(function()
	if not selectedPlayer then return end
	local result, error = ChangePermissionEvent:InvokeServer(selectedPlayer.UserId, "Delete", false)
	if not result then return MessageService.SendMessage(error) end
end)

-- Configure
local ConfigureFrameCanvasGroup = ActionPanelContainer.ConfigureFrame.CanvasGroup
local ConfigureAllowButton: TextButton = ConfigureFrameCanvasGroup.Allow
local ConfigureBlockButton: TextButton = ConfigureFrameCanvasGroup.Block

ConfigureAllowButton.MouseButton1Click:Connect(function()
	if not selectedPlayer then return MessageService.SendMessage("No player selected") end
	local result, error = ChangePermissionEvent:InvokeServer(selectedPlayer.UserId, "Configure", true)
	if not result then return MessageService.SendMessage(error) end
end)
ConfigureBlockButton.MouseButton1Click:Connect(function()
	if not selectedPlayer then return end
	local result, error = ChangePermissionEvent:InvokeServer(selectedPlayer.UserId, "Configure", false)
	if not result then return MessageService.SendMessage(error) end
end)

-- Interact
local InteractFrameCanvasGroup = ActionPanelContainer.InteractFrame.CanvasGroup
local InteractAllowButton: TextButton = InteractFrameCanvasGroup.Allow
local InteractBlockButton: TextButton = InteractFrameCanvasGroup.Block

InteractAllowButton.MouseButton1Click:Connect(function()
	if not selectedPlayer then return MessageService.SendMessage("No player selected") end
	local result, error = ChangePermissionEvent:InvokeServer(selectedPlayer.UserId, "Interact", true)
	if not result then return MessageService.SendMessage(error) end
end)
InteractBlockButton.MouseButton1Click:Connect(function()
	if not selectedPlayer then return end
	local result, error = ChangePermissionEvent:InvokeServer(selectedPlayer.UserId, "Interact", false)
	if not result then return MessageService.SendMessage(error) end
end)