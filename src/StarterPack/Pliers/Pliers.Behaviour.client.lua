--[[ PLIERS
		This tool to remove all connections of gate
]]

-- Requires and services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local LocalServices = StarterPlayerScripts.Services

local PointerService = require(LocalServices.PointerService)
local MessageService = require(LocalServices.MessageService)
local PliersMode = require(StarterPlayerScripts.Tool.PliersMode)

-- Events
local DisconnectEvent = ReplicatedStorage.Client.Events.CutAll
local CutEvent = ReplicatedStorage.Client.Events.Cut

-- References
local Tool = script.Parent

-- ----------------------------- --------- HELPER METHODS -------- ------------------------------

local function isWire(instance: Instance?): (boolean, Beam?)
	if instance and instance:IsA("Part") and instance.Name == "Hitbox" then
		local parent = instance.Parent
		if parent ~= nil and typeof(parent) == "Instance" and parent:IsA("Beam") then
			return true, parent
		end
	end
	return false, nil
end

-- ----------------------------- ----------- BEHAVIOURS ----------- -------------------------------

local function Activated()
	local instance = PointerService.HoveredInstance
	if not instance then return end
	
	local validWire, wireInstance = isWire(instance)
	if validWire and wireInstance then
		local fromId = wireInstance:GetAttribute("FromGate")
		local toId = wireInstance:GetAttribute("ToGate")
		local fromNode = wireInstance:GetAttribute("FromNode")
		local toNode = wireInstance:GetAttribute("ToNode")
		
		local result, error = CutEvent:InvokeServer(fromId, toId, fromNode, toNode)
		if not result then
			return MessageService.SendMessage(error :: string)
		end
		return
	end
	
	local gate = PointerService.HoveredGate
	if gate then
		local result, error = DisconnectEvent:InvokeServer(gate:GetAttribute("GateId"))
		if not result then
			return MessageService.SendMessage(error :: string)
		end
	end
end

-- ----------------------------- --------- TOOL CALLBACKS --------- -------------------------------

Tool.Equipped:Connect(PliersMode.Start)
Tool.Unequipped:Connect(PliersMode.Stop)
Tool.Activated:Connect(Activated)
