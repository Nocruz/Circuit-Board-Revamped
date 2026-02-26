--!strict
--[[ UPDATE SERVICE
		Handles the propagation of signals through the circuit.
		Features: High-Frequency Burst Logic + Cancellable Scheduled Events
]]

-- Requires and Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Logger = require(ReplicatedStorage.Services.LoggerService)
local log = Logger.new("UpdateManager")

local Types = require(ServerScriptService.Gates.Definitions.Types)
local SignalService = require(ServerScriptService.Gates.Services.SignalService)
local WireService = require(ServerScriptService.Gates.Services.WireService)

-- ----------------------------- ---------- CONFIGURATION ----------- ---------------------------

local TICK_RATE = 0.1
local MAX_UPDATES_PER_GATE = 30
local MAX_TOTAL_STEPS = 10000

-- ----------------------------- ------------- TYPES ------------------ ---------------------------

-- Wrapper para eventos agendados. Permite cancelación por referencia.
type ScheduledTask = {
	Gate: Types.TGate,
	Active: boolean, -- Si es false, la TimeWheel ignorará este evento
}

-- ----------------------------- ------------- STATE ------------------ ---------------------------

-- The Time Wheel: [QuantizedTimestamp] = { Task, Task, ... }
local TimeWheel: { [number]: { ScheduledTask } } = {}

-- Map for O(1) Cancellation: [Gate] = ActiveTask
local PendingSchedules: { [Types.TGate]: ScheduledTask } = {}

-- Immediate Processing
local ImmediateQueue: { Types.TGate } = {}
local UpdateCounts: { [Types.TGate]: number } = {}

-- Overflow handling
local DeferredQueue: { Types.TGate } = {}
local DeferredSet: { [Types.TGate]: true } = {}

local UpdateService = {}

-- ----------------------------- ----------- SCHEDULING ----------- ---------------------------

local function getQuantizedTime(delay: number): number
	local targetTime = os.clock() + delay
	return math.ceil(targetTime / TICK_RATE) * TICK_RATE
end

-- Cancels any pending schedule for a specific gate
function UpdateService.cancel(gate: Types.TGate)
	local activeTask = PendingSchedules[gate]
	if activeTask then
		-- "Soft delete": Marcamos la tarea como inactiva.
		-- La TimeWheel la encontrará, pero la ignorará.
		activeTask.Active = false
		PendingSchedules[gate] = nil
		-- log.info("Cancelled schedule for " .. gate.Class.name)
	end
end

-- Schedules a gate update. Automatically cancels any previous pending update.
function UpdateService.schedule(gate: Types.TGate, delay: number)
	-- 1. Enforce single-timer policy (Cancel previous)
	UpdateService.cancel(gate)

	-- 2. Create new task
	local targetTick = getQuantizedTime(delay)

	local newTask: ScheduledTask = {
		Gate = gate,
		Active = true
	}

	-- 3. Register logic
	PendingSchedules[gate] = newTask

	-- 4. Insert into Wheel
	if not TimeWheel[targetTick] then
		TimeWheel[targetTick] = {}
	end
	table.insert(TimeWheel[targetTick], newTask)

	-- log.info("Scheduled " .. gate.Class.name .. " for " .. targetTick)
end

-- Adds a gate to be updated ASAP
function UpdateService.propagate(gate: Types.TGate)
	local count = UpdateCounts[gate] or 0

	if count >= MAX_UPDATES_PER_GATE then
		if not DeferredSet[gate] then
			DeferredSet[gate] = true
			table.insert(DeferredQueue, gate)
		end
		return
	end

	UpdateCounts[gate] = count + 1
	table.insert(ImmediateQueue, gate)
end

-- ----------------------------- ------------ LOGIC CORE ------------ ---------------------------

local function updateGate(gate: Types.TGate, origin: "Signal" | "Schedule")
	if not gate.Class or not gate.Class.Update then return end

	-- Calculate logic
	local newSignal = gate.Class.Update(gate, origin)

	-- Delta check
	if gate.Output == nil then return end
	if not SignalService.equals(gate.Output, newSignal) then
		gate.Output = newSignal

		-- Propagate output
		if gate.Connections then
			for targetGate, _ in pairs(gate.Connections) do
				UpdateService.propagate(targetGate)
			end
			WireService.EnqueueUpdate(gate.Id, gate.Output)
		end
	end
end

-- ----------------------------- ------------- LOOP ----------------- ---------------------------

local function step(dt: number)
	local now = os.clock()
	local quantizedNow = math.ceil(now / TICK_RATE) * TICK_RATE

	-- 1. Inject Deferred Gates
	for _, gate in ipairs(DeferredQueue) do
		table.insert(ImmediateQueue, gate)
		UpdateCounts[gate] = 1
	end
	table.clear(DeferredQueue)
	table.clear(DeferredSet)

	-- 2. Move Scheduled Events (Time Wheel)
	for timestamp, tasks in pairs(TimeWheel) do
		if timestamp <= quantizedNow then
			for _, task in ipairs(tasks) do
				-- [CHECK] Is the task still valid?
				if task.Active then
					-- Limpiamos el registro de pendientes ya que se está ejecutando
					if PendingSchedules[task.Gate] == task then
						PendingSchedules[task.Gate] = nil
					end

					updateGate(task.Gate, "Schedule")
					UpdateCounts[task.Gate] = (UpdateCounts[task.Gate] or 0) + 1
				end
			end
			TimeWheel[timestamp] = nil
		end
	end

	-- 3. Process Immediate Queue
	local steps = 0
	local i = 1

	while i <= #ImmediateQueue do
		local gate = ImmediateQueue[i]
		updateGate(gate, "Signal")

		steps += 1
		if steps > MAX_TOTAL_STEPS then
			log.warn("Simulation Panic! Step limit reached.")
			break
		end
		i += 1
	end

	-- 4. Cleanup
	table.clear(ImmediateQueue)
	table.clear(UpdateCounts)

	if i > 1 then
		WireService.UpdateWireColours()
	end
end

-- ----------------------------- ---------- INITIALIZATION ---------- ---------------------------

RunService.Heartbeat:Connect(step)

return UpdateService
