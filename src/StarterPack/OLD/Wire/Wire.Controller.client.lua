--!strict
--[[ WIRE CONTROLLER
		This manages the state machine:
			- Transitions
			- Connections to the PointerContext
		Check WireMode for information on the state machine.
]]

-- Requires and services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local LocalServices = StarterPlayerScripts.Services

local PointerService = require(LocalServices.PointerService)
local MessageService = require(LocalServices.MessageService)
local WireMode = require(StarterPlayerScripts.Tool.WireMode)

-- Events
local Query = ReplicatedStorage.Client.Queries.Query
local WireEvent = ReplicatedStorage.Client.Events.Wire

-- References
local Tool = script.Parent

-- State
local startGate: Instance? = nil
local startNode: Instance? = nil

-- ----------------------------- ----------- BEHAVIOURS ----------- -------------------------------

local function Activate()
	local gate, node = PointerService.HoveredGate, PointerService.HoveredNode
	if not gate or not node then return end

	local result, error = Query:InvokeServer(gate:GetAttribute("Id"), "Wire")
	if not result then
		return MessageService.SendMessage(error :: string)
	end
	
	startGate = gate
	startNode = node
	
	WireMode.Start(node)
end

local function Deactivate()
	local gate, endNode = PointerService.HoveredGate, PointerService.HoveredNode
	if not gate or not endNode then return end
	
	local startNode = startNode :: Instance
	local typeStart = startNode:GetAttribute("Type")
	
	if typeStart == endNode:GetAttribute("Type") then
		return MessageService.SendMessage("Cannot connect " .. typeStart .. "s to " .. typeStart .. "s")
	else
		if typeStart == "Input" then
			startGate, gate = gate, startGate
			startNode, endNode = endNode, startNode
		end
		local result, error = WireEvent:InvokeServer(startGate:GetAttribute("Id"), gate:GetAttribute("Id"), endNode.Name)
		if not result then
			return MessageService.SendMessage(error :: string)
		end
	end
	
	startGate = nil
	startNode = nil
	
	WireMode.Stop()
end

-- ----------------------------- --------- TOOL CALLBACKS --------- -------------------------------

Tool.Equipped:Connect(WireMode.ActivatePointer)
Tool.Activated:Connect(function() if WireMode.active then Deactivate() else Activate() end end)
Tool.Unequipped:Connect(function() WireMode.DeactivatePointer(); startNode = nil; startNode = nil; WireMode.Stop() end)