--!strict
--[[ NEEDLE TOOL
		Inspects and Configures Gates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local LocalServices = StarterPlayerScripts.Services

local PointerService = require(LocalServices.PointerService)
local MessageService = require(LocalServices.MessageService)

local NeedleMode = require(StarterPlayerScripts.Tool.NeedleMode)
local NeedleUI = require(StarterPlayerScripts.Tool.NeedleUI)

-- Events
local QueryEvent = ReplicatedStorage.Client.Queries.Query
local GetGateInfo = ReplicatedStorage.Client.Queries.GateConfiguration

-- Tool
local Tool = script.Parent

-- ----------------------------- ----------- BEHAVIOURS ----------- -------------------------------

local function Activated()
	local gate = PointerService.HoveredGate
	if not gate then return end

	local id = gate:GetAttribute("Id")
	if not id then return end

	local allowed, reason, data = GetGateInfo:InvokeServer(id)

	if not allowed then
		MessageService.SendMessage(reason or "No permissions to configure this gate")
		return
	end

	if data then
		if next(data) == nil then
			MessageService.SendMessage("No configuration data available for this gate")
		else
			NeedleUI.Open(id, data)
		end
	else
		MessageService.SendMessage("Failed to fetch gate data")
	end
end

local function Equipped()
	NeedleMode.Start()
end

local function Unequipped()
	NeedleMode.Stop()
	NeedleUI.Close()
end

-- ----------------------------- --------- TOOL CALLBACKS --------- -------------------------------

Tool.Equipped:Connect(Equipped)
Tool.Unequipped:Connect(Unequipped)
Tool.Activated:Connect(Activated)