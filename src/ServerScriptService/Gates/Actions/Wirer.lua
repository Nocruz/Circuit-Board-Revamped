--!strict
--[[ WIRER
		Connects gates. If gates have models, also spawns a wire.
]]

-- Requires and services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")

local UpdateService = require(ServerScriptService.Gates.Services.UpdateService)
local WireService = require(ServerScriptService.Gates.Services.WireService)

local Types = require(ServerScriptService.Gates.Definitions.Types)
type TGate = Types.TGate
type TNode = Types.TNode

-- Debugger
local Logger = require(ReplicatedStorage.LoggerService)
local log = Logger.new("Wire")

local Wirer = {}

-- ----------------------------- ----------- HELPER METHODS ----------- ---------------------------


-- ----------------------------- ------------ CONNECT GATE ------------ ---------------------------

function Wirer.Wire(from: TGate, to: TGate, node: string)
	assert(from.Connections and from.Output ~= nil)
	assert(to.Inputs and to.Inputs[node])
	assert(not (to.Inputs[node][from] or (from.Connections[to] and from.Connections[to][node])))
	
	log.info("Wiring " .. from.Class.name .. " with ID " .. from.Id .. " to " .. to.Class.name .. " with ID " .. to.Id .. " (Node " .. node ..")")
	
	from.Connections[to] = from.Connections[to] or {}
	from.Connections[to][node] = { existance = true }
	to.Inputs[node] = to.Inputs[node] or {}
	to.Inputs[node][from] = true
	
	log.info("Connections from " .. from.Id .. ": ")
	for gate, nodes in pairs(from.Connections) do
		log.info("		-" .. gate.Class.name .. " (" .. gate.Id .. ")")
	end
	
	log.info("Connections to " .. node .. ": ")
	for gate in pairs(to.Inputs[node]) do
		log.info("		-" .. gate.Class.name .. " (" .. gate.Id .. ")")
	end
	
	-- Instantiate wire
	local fromModel = from.Model
	local toModel = to.Model
	if fromModel and toModel then 
		log.info("Both have models. Instantiating wire")
		
		local wire = WireService.new(from, to, node)
		
		from.Connections[to][node].Wire = wire
	end
	
	UpdateService.propagate(to)
end

-- ----------------------------- ----------- DISCONNECT GATE ---------- ---------------------------

function Wirer.Cut(from: TGate, to: TGate, node: string)
	assert(from.Connections)
	assert(to.Inputs and to.Inputs[node])
	
	local outConnections = from.Connections[to]
	if not outConnections or not node or not outConnections[node] then return end

	-- Dispose wire
	if outConnections[node].Wire ~= nil then
		WireService.destroy(from.Id, outConnections[node].Wire)
	end
	outConnections[node] = nil

	-- Disconnect from input node
	to.Inputs[node][from] = nil

	if next(outConnections) == nil then from.Connections[to] = nil end
	
	UpdateService.propagate(to)
end

function Wirer.CutAllOut(gate: TGate)
	if not gate.Class.output then return end
	
	log.info("Cutting all connections from " .. gate.Id)
	for to, nodes in pairs(gate.Connections) do
		log.info("Cutting " .. to.Id)
		for node, data in pairs(nodes) do
			Wirer.Cut(gate, to, node)
		end
	end
	table.clear(gate.Connections)
end

function Wirer.CutAllIn(gate: TGate)
	if not gate.Inputs then return end
	
	-- Clean up connections (In)
	for name, node in pairs(gate.Inputs) do
		for outputGate in pairs(node) do
			Wirer.Cut(outputGate, gate, name)
		end
		table.clear(node)
	end
end

-- ----------------------------- ----------- END OF MODULE ------------ -----------------------------

return Wirer
