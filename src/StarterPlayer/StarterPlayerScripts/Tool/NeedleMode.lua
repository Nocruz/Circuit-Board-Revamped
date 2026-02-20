--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local PointerService = require(StarterPlayerScripts.Services.PointerService)

local NeedleMode = {}
local selectionBox: SelectionBox?

function NeedleMode.Start()
	if selectionBox then return end
	
	selectionBox = Instance.new("SelectionBox")
	selectionBox.Name = "NeedleSelection"
	selectionBox.Color3 = Color3.fromRGB(0, 255, 100)
	selectionBox.LineThickness = 0.05
	selectionBox.SurfaceTransparency = 1
	selectionBox.SurfaceColor3 = Color3.fromRGB(0, 255, 100)
	selectionBox.Parent = Players.LocalPlayer.PlayerGui

	PointerService.OnGateHovered:Connect(function(gateModel)
		if selectionBox then
			selectionBox.Adornee = gateModel
		end
	end)

	selectionBox.Adornee = PointerService.HoveredGate
end

function NeedleMode.Stop()
	if selectionBox then
		selectionBox:Destroy()
		selectionBox = nil
	end
end

return NeedleMode