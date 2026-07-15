--[[ REMOVER TOOL
		Click a gate to destroy it.
		
		Drag the cursor to form a bounding box.
		Use the bounding box to delete circuits.
		
		Can also delete all circuits made by the player.
]]

-- Requires and services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")

local LocalServices = StarterPlayerScripts.Services
local MessageService = require(LocalServices.MessageService)
local PointerService = require(LocalServices.PointerService)

-- AI STUFF
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local gatesFolder = Workspace:WaitForChild("Gates")
local serverGatesFolder = gatesFolder:WaitForChild("Server")

-- References
local highlightPrefab: Highlight = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("RemoverHighlight")
local selectionBoxPrefab: SelectionBox = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("RemoverSelectionBox")
local confirmationGui: BillboardGui = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("RemoverConfirmationGui")
local destroyAllGui: ScreenGui = ReplicatedStorage:WaitForChild("Client"):WaitForChild("UI"):WaitForChild("RemoverDestroyAllGui")

-- Detections
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include

-- Events
local destroyEvent: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Events"):WaitForChild("Destroy")

-- State definition
local State = {}
State.__index = State

-- ----------------------------- ------------ HELPER METHODS ------------- -----------------------------

local function toGridEdgePosition(position)
	return Vector3.new(math.round(position.X - 1) + 1, math.round(position.Y), math.round(position.Z - 1) + 1)
end

-- ----------------------------- ------------- GUI METHODS --------------- -----------------------------

function State:CreateDestroyAllGui()
	local gui = destroyAllGui:Clone()
	gui.Parent = playerGui
	
	self.destroyAllConnection = gui.Button.Activated:Connect(function()
		self:ExecuteDestroyAll()
	end)
	
	self.destroyAllGui = gui
end

function State:CreateConfirmGui(adornee)
	if self.confirmGui then self.confirmGui:Destroy() end
	
	local billboard = confirmationGui:Clone()
	billboard.Adornee = adornee
	billboard.Parent = playerGui
	
	self.confirmGuiConnection = billboard.ConfirmButton.Activated:Connect(function()
		self:ExecuteDestroySelected()
	end)
	
	self.confirmGui = billboard
end

function State:DestroyUI()
	if self.destroyAllGui then
		self.destroyAllGui:Destroy()
		self.destroyAllGui = nil
	end
	if self.destroyAllConnection then
		self.destroyAllConnection:Disconnect()
		self.destroyAllConnection = nil
	end
	if self.confirmGui then
		self.confirmGui:Destroy()
		self.confirmGui = nil
	end
	if self.confirmGuiConnection then
		self.confirmGuiConnection:Disconnect()
		self.confirmGuiConnection = nil
	end
end

-- ----------------------------- ---------- DESTROY EXECUTION ---------- -----------------------------

function State:ExecuteDestroySingle(gate: Instance)
	local gateID = gate:GetAttribute("GateID")
	if not gateID then return end
	
	local targetGates = { [gateID] = true }
	local success, message = destroyEvent:InvokeServer(targetGates)
	
	if not self.IsEquipped then return end
	if not success then 
		MessageService.SendMessage(message)
	else 
		self:ResetHoverHighlight() 
	end
end

function State:ExecuteDestroySelected()
	if not self.gates or next(self.gates) == nil then
		self:DestroyBoundingBox()
		return
	end
	
	-- self.gates is already a dictionary { [id] = true } 
	local success, message = destroyEvent:InvokeServer(self.gates)
	
	if not self.IsEquipped then return end
	if not success then 
		MessageService.SendMessage(message)
	else
		MessageService.SendColouredMessage("Circuits destroyed!", Color3.new(0, 1, 0))
	end
	
	self:DestroyBoundingBox()
end

function State:ExecuteDestroyAll()
	local playerGatesFolder = gatesFolder:FindFirstChild(tostring(localPlayer.UserId))
	if not playerGatesFolder then 
		MessageService.SendMessage("You have no gates to destroy.")
		return 
	end
	
	local targetGates = {}
	local count = 0
	
	for _, gate in ipairs(playerGatesFolder:GetChildren()) do
		local id = gate:GetAttribute("GateID")
		if id and type(id) == "number" then
			targetGates[id] = true
			count += 1
		end
	end
	
	if count == 0 then
		MessageService.SendMessage("You have no gates to destroy.")
		return
	end
	
	local success, message = destroyEvent:InvokeServer(targetGates)
	if not self.IsEquipped then return end
	
	if not success then 
		MessageService.SendMessage(message)
	else
		MessageService.SendColouredMessage("All circuits destroyed!", Color3.new(0, 1, 0))
		self:DestroyBoundingBox()
	end
end

-- ----------------------------- --------- HOVER & HIGHLIGHTS ---------- -----------------------------

function State:ResetHoverHighlight()
	if self.SelectedGateHighlight then
		self.SelectedGateHighlight.Adornee = nil
		self.SelectedGateHighlight.Parent = nil
	end
	self.SelectedGate = nil
end

function State:SetHoverHighlight(gate: Instance)
	if not self.IsEquipped or not gate or not gate.Parent then return end
	if gate:IsDescendantOf(serverGatesFolder) then return end
	
	self.SelectedGate = gate
	self.SelectedGateHighlight.Adornee = gate
	self.SelectedGateHighlight.Parent = gate
end

function State:UpdateHover(instance: Instance?, gate: Model?)
	if not self.IsEquipped then return end
	
	-- Hide standard hover highlight if we are dragging a bounding box
	if self.boundingBox ~= nil then
		self:ResetHoverHighlight()
		return
	end
	
	if not gate or not gate.Parent then
		self:ResetHoverHighlight()
	elseif self.SelectedGate ~= gate then
		self:ResetHoverHighlight()
		self:SetHoverHighlight(gate)
	end
end

-- ----------------------------- --------- BOUNDING BOX METHODS ---------- -----------------------------

function State:UpdateBoundingBox()
	if not self.IsEquipped or not self.boundingBox or not PointerService.HitPosition then return end
	
	local pointA, pointB = self.boundingBoxStartPos, toGridEdgePosition(PointerService.HitPosition)
	if pointB == self.boundingBoxEndPos then return end
	
	self.boundingBoxEndPos = pointB
	local startPoint = Vector3.new(math.min(pointA.X, pointB.X), math.min(pointA.Y, pointB.Y), math.min(pointA.Z, pointB.Z))
	local endPoint = Vector3.new(math.max(pointA.X, pointB.X), math.max(pointA.Y, pointB.Y), math.max(pointA.Z, pointB.Z))
	
	self.boundingBox.Size = endPoint - startPoint
	self.boundingBox.CFrame = CFrame.new((startPoint + endPoint) / 2)
	
	-- Check if we actually dragged beyond the starting cell
	if (pointA - pointB).Magnitude > 0.1 then
		self.hasDragged = true
	end
	
	self:UpdateSelectionHighlights()
end

function State:StartBoundingBox()
	if not self.IsEquipped or not PointerService.HitPosition then return end
	
	local startPos = toGridEdgePosition(PointerService.HitPosition)
	local box = Instance.new("Part") do
		box.Name = "RemoverZone"
		box.Anchored = true
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.Transparency = 1
		
		local visuals = selectionBoxPrefab:Clone()
		visuals.Color3 = Color3.fromRGB(220, 50, 50) -- Make the box red for danger
		visuals.Adornee = box
		visuals.Parent = box
		
		PointerService.AddToFilter(box)
		box.Parent = Workspace
	end
	
	self.boundingBox = box
	self.boundingBoxStartPos = startPos
	self.boundingBoxEndPos = nil
	self.hasDragged = false
	
	self:UpdateBoundingBox()
	
	self.boundingBoxUpdateConnection = RunService.RenderStepped:Connect(function()
		if not self.IsEquipped then return end
		if self.isDragging then
			self:UpdateBoundingBox()
		end
	end)
end

function State:DestroyBoundingBox()
	self:DestroySelectionHighlights()
	
	if self.boundingBox then
		self.boundingBox:Destroy()
		self.boundingBox = nil
	end
	
	self.boundingBoxStartPos = nil
	self.boundingBoxEndPos = nil
	self.hasDragged = false
	
	if self.boundingBoxUpdateConnection then
		self.boundingBoxUpdateConnection:Disconnect()
		self.boundingBoxUpdateConnection = nil
	end
	
	if self.confirmGui then
		self.confirmGui:Destroy()
		self.confirmGui = nil
	end
	
	-- Restore hover highlight logic
	self:UpdateHover(PointerService.HoveredInstance, PointerService.HoveredGate)
end

function State:UpdateSelectionHighlights()
	if not self.IsEquipped or not self.boundingBox then return end
	self:DestroySelectionHighlights()
	
	overlapParams.FilterDescendantsInstances = { gatesFolder }
	local parts = Workspace:GetPartBoundsInBox(self.boundingBox.CFrame, self.boundingBox.Size, overlapParams)
	
	for _, part in ipairs(parts) do
		local gate = part:FindFirstAncestorWhichIsA("Model")
		if gate == nil then continue end
		if gate:IsDescendantOf(serverGatesFolder) then continue end
		
		local id = gate:GetAttribute("GateID")
		if id == nil or type(id) ~= "number" then continue end 
		if self.gates[id] then continue end
		
		self.gates[id] = true
		local highlight = highlightPrefab:Clone() do
			highlight.Name = "RemoveHighlight"
			highlight.FillColor = Color3.fromRGB(220, 50, 50) -- Red fill
			highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
			highlight.Adornee = gate
			highlight.Parent = gate
		end
		table.insert(self.highlights, highlight)
	end
end

function State:DestroySelectionHighlights()
	if self.highlights ~= nil then
		for _, highlight in ipairs(self.highlights) do
			if highlight then highlight:Destroy() end
		end
		table.clear(self.highlights)
	end
	
	if self.gates ~= nil then
		table.clear(self.gates)
	end
end

-- ----------------------------- --------- STATE IMPLEMENTATION ---------- -----------------------------

function State.new()
	local self = setmetatable({}, State)
	
	self.HoverConnection = nil
	self.SelectedGate = nil
	self.SelectedGateHighlight = nil
	
	self.IsEquipped = true
	
	-- Drag & Box State
	self.isDragging = false
	self.hasDragged = false
	self.boundingBox = nil
	self.boundingBoxStartPos = nil
	self.boundingBoxEndPos = nil
	self.boundingBoxUpdateConnection = nil
	
	-- Selection State
	self.highlights = {}
	self.gates = {}
	
	-- UI State
	self.destroyAllGui = nil
	self.destroyAllConnection = nil
	self.confirmGui = nil
	self.confirmGuiConnection = nil
	
	return self
end

function State:Enter()
	self.SelectedGateHighlight = highlightPrefab:Clone()
	
	self.HoverConnection = PointerService.OnHoverChanged:Connect(function(instance, gate)
		self:UpdateHover(instance, gate)
	end)
	
	self:CreateDestroyAllGui()
	self:UpdateHover(PointerService.HoveredInstance, PointerService.HoveredGate)
end

function State:Activated()
	if not self.IsEquipped then return end
	
	-- Always clear previous box on a fresh click
	if self.boundingBox then
		self:DestroyBoundingBox()
	end
	
	if not PointerService.HitPosition then return end
	
	self.isDragging = true
	self.hasDragged = false
	self:StartBoundingBox()
end

function State:Deactivated()
	if not self.IsEquipped then return end
	self.isDragging = false
	
	if not self.hasDragged then
		-- It was a single click
		self:DestroyBoundingBox()
		
		-- If they clicked on a gate, destroy just that gate
		if self.SelectedGate and self.SelectedGate.Parent then
			self:ExecuteDestroySingle(self.SelectedGate)
		end
	else
		-- They finished dragging a box. Prompt for destruction if gates are selected.
		if next(self.gates) ~= nil then
			self:CreateConfirmGui(self.boundingBox)
		else
			-- No gates selected in the box, just clean up
			self:DestroyBoundingBox()
		end
	end
end

function State:Exit()
	if not self.IsEquipped then return end
	self.IsEquipped = false
	
	if self.HoverConnection then
		self.HoverConnection:Disconnect()
		self.HoverConnection = nil
	end
	
	self:DestroyBoundingBox()
	self:ResetHoverHighlight()
	self:DestroyUI()
	
	if self.SelectedGateHighlight then
		self.SelectedGateHighlight:Destroy()
		self.SelectedGateHighlight = nil
	end
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return State
