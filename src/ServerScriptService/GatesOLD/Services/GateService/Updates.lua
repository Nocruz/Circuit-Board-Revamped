--!strict
--[[ GATE SERVICE UPDATES
		Central propagation and scheduling loop for GateService.
]]

local RunService = game:GetService("RunService")

local SignalService = require(script.Parent.Parent.SignalService)
local Wires = require(script.Parent.Wires)

local Updates = {}

local TICK_RATE = 0.1
local MAX_UPDATES_PER_GATE = 30
local MAX_TOTAL_STEPS = 10000

--- Helpers

-- ----------------------------- ------------ HELPERS ------------------- -----------------------------

local function getQuantizedTime(delay: number): number
	local targetTime = os.clock() + delay
	return math.ceil(targetTime / TICK_RATE) * TICK_RATE
end

local function queueDeferred(state: any, item: any)
	local existing = state.DeferredItems[item.Gate]
	if existing == nil then
		state.DeferredItems[item.Gate] = item
		table.insert(state.DeferredOrder, item.Gate)
		return
	end

	if existing.Origin ~= "Schedule" and item.Origin == "Schedule" then
		state.DeferredItems[item.Gate] = item
	end
end

local function enqueueWork(state: any, item: any)
	local count = state.UpdateCounts[item.Gate] or 0
	if count >= MAX_UPDATES_PER_GATE then
		queueDeferred(state, item)
		return
	end

	state.UpdateCounts[item.Gate] = count + 1
	table.insert(state.ImmediateQueue, item)
end

local function releaseScheduledTask(state: any, item: any): boolean
	local task = item.Task
	if task == nil then
		return true
	end

	if not task.Active then
		if state.PendingSchedules[item.Gate] == task then
			state.PendingSchedules[item.Gate] = nil
		end
		return false
	end

	if state.PendingSchedules[item.Gate] == task then
		state.PendingSchedules[item.Gate] = nil
	end

	return true
end

local function flushDeferredQueue(state: any)
	for _, gate in ipairs(state.DeferredOrder) do
		local item = state.DeferredItems[gate]
		if item ~= nil then
			state.UpdateCounts[gate] = 1
			table.insert(state.ImmediateQueue, item)
		end
	end

	table.clear(state.DeferredOrder)
	table.clear(state.DeferredItems)
end

local function flushDueScheduledTasks(state: any, tickNow: number)
	for timestamp, tasks in pairs(state.TimeWheel) do
		if timestamp <= tickNow then
			for _, task in ipairs(tasks) do
				enqueueWork(state, {
					Gate = task.Gate,
					Origin = "Schedule",
					Task = task,
				})
			end
			state.TimeWheel[timestamp] = nil
		end
	end
end

local function updateGate(state: any, gate: any, origin: "Signal" | "Schedule")
	if gate.Destroyed then
		return
	end

	local previousOutput = gate.Output
	local nextOutput = gate.Specification.Process(gate, origin)

	if previousOutput == nil then
		return
	end
	if nextOutput == nil then
		nextOutput = previousOutput
	end

	if not SignalService.equals(previousOutput, nextOutput) then
		gate.Output = nextOutput

		if gate.Connections ~= nil then
			for targetGate in pairs(gate.Connections) do
				Updates.Propagate(state, targetGate)
			end
			Wires.EnqueueColour(state, gate.Id, nextOutput)
		end
	end
end

local function step(state: any, logger: any)
	local tickNow = math.ceil(os.clock() / TICK_RATE) * TICK_RATE

	state.CurrentTick = tickNow
	state.IsStepping = true

	flushDeferredQueue(state)
	flushDueScheduledTasks(state, tickNow)

	local index = 1
	local steps = 0

	while index <= #state.ImmediateQueue do
		local item = state.ImmediateQueue[index]
		index += 1

		if releaseScheduledTask(state, item) then
			updateGate(state, item.Gate, item.Origin)
		end

		steps += 1
		if steps >= MAX_TOTAL_STEPS then
			logger.warn("Simulation panic prevented: deferring remaining work.")
			break
		end
	end

	if index <= #state.ImmediateQueue then
		for queueIndex = index, #state.ImmediateQueue do
			queueDeferred(state, state.ImmediateQueue[queueIndex])
		end
	end

	table.clear(state.ImmediateQueue)
	table.clear(state.UpdateCounts)

	state.IsStepping = false
	state.CurrentTick = nil
	Wires.FlushColours(state)
end

-- ----------------------------- ------------- PUBLIC API ------------- -----------------------------

function Updates.Start(state: any, logger: any)
	if state.HeartbeatConnection ~= nil then
		return
	end

	state.HeartbeatConnection = RunService.Heartbeat:Connect(function()
		step(state, logger)
	end)
end

function Updates.Propagate(state: any, gateOrId: any)
	local gate = if type(gateOrId) == "number" then state.GatesById[gateOrId] else gateOrId
	if gate == nil or gate.Destroyed then
		return
	end

	enqueueWork(state, {
		Gate = gate,
		Origin = "Signal",
	})
end

function Updates.Cancel(state: any, gateOrId: any)
	local gate = if type(gateOrId) == "number" then state.GatesById[gateOrId] else gateOrId
	if gate == nil then
		return
	end

	local activeTask = state.PendingSchedules[gate]
	if activeTask ~= nil then
		activeTask.Active = false
		state.PendingSchedules[gate] = nil
	end
end

function Updates.Schedule(state: any, gateOrId: any, delay: number)
	local gate = if type(gateOrId) == "number" then state.GatesById[gateOrId] else gateOrId
	if gate == nil or gate.Destroyed then
		return
	end

	Updates.Cancel(state, gate)

	local targetTick = getQuantizedTime(delay)
	local task = {
		Gate = gate,
		Active = true,
		TargetTick = targetTick,
	}

	state.PendingSchedules[gate] = task

	if state.IsStepping and state.CurrentTick ~= nil and targetTick <= state.CurrentTick then
		enqueueWork(state, {
			Gate = gate,
			Origin = "Schedule",
			Task = task,
		})
		return
	end

	state.TimeWheel[targetTick] = state.TimeWheel[targetTick] or {}
	table.insert(state.TimeWheel[targetTick], task)
end

return Updates
