local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- References to your module and UI
local PointerService = require(game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts"):FindFirstChild("Services").PointerService) -- Adjust path if needed
local gateUIPath = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("OwnerText")

local player = Players.LocalPlayer
local Players = game:GetService("Players")

-- Clone the UI once and parent it to PlayerGui
local displayUI = gateUIPath:Clone()
displayUI.Enabled = false
displayUI.Parent = player:WaitForChild("PlayerGui")

-- Helper to check if the player is holding a tool
local function isHoldingTool()
	local character = player.Character
	if character then
		return character:FindFirstChildOfClass("Tool") ~= nil
	end
	return false
end

-- Listen to your Module's custom event
PointerService.OnHoverChanged:Connect(function(instance, gate, node)
	-- Condition: Must have a gate hovered AND not be holding a tool
	if gate and not isHoldingTool() then
		-- Set the Adornee to the "Base" or "Main" part of your gate for centering
		local adornee = gate:FindFirstChild("Base") or gate:FindFirstChild("Main") or gate.PrimaryPart

		if adornee then
			local ownerId = gate:GetAttribute("Owner")
			if ownerId == 0 then return end
			
			displayUI.Adornee = adornee
			displayUI.Enabled = true
			
			local ownerName = Players:GetNameFromUserIdAsync(ownerId)
			displayUI.TextLabel.Text = ownerName
		end
	else
		-- Hide if no gate is hovered or a tool is equipped
		displayUI.Enabled = false
		displayUI.Adornee = nil
	end
end)

-- Optional: Update visibility instantly when a tool is equipped/unequipped
-- This prevents the UI from staying up if you equip a tool while already hovering
player.CharacterAdded:Connect(function(character) character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			displayUI.Enabled = false
		end
	end)
end)