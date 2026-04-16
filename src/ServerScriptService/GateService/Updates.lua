--[[ UPDATES (CENTRALIZED TIME & ACTOR MODEL)
	Handles signal propagation and time-based state execution.
	
	Key Features:
	  1. Payload-Driven Wakeups: Gates schedule future Process(payload) calls natively.
	  2. Wakeup Keys: Gates can run multiple independent timers using string keys.
	  3. Same-frame propagation: Gates update immediately unless they exceed MAX_UPDATES_PER_GATE
	  4. True Determinism: All delays are tied to the internal TimeWheel, preventing thread leaks.
]]

-- Requires and Services
local RunService = game:GetService("RunService")
local Connections = require(script.Parent.Connections)
local Signals = require(script.Parent.Signals)

-- ----------------------------- ---------- CONFIGURATION ----------- ---------------------------

local TICK_RATE = 0.1  -- Time wheel quantization granularity
local MAX_UPDATES_PER_GATE = 30  -- Threshold before frame deferral
local MAX_TOTAL_STEPS = 1000  -- Circuit step limit (prevents infinite loops)

-- ----------------------------- ------------- TYPES ------------------ ---------------------------

type TGateID = number
type TNodeName = string
type TSignal = string | number | boolean

type ScheduledWakeup = {
	GateID: TGateID,
	WakeupKey: string,
	Payload: any,
	FireTime: number,
	Active: boolean,
}

type ExecutionContext = {
	GateID: TGateID,
	Depth: number,
	ForcePropagateOutputs: { [TNodeName]: true },
}

type TGateInstance = {
	Id: number,
	OwnerId: number,
	Model: Model,
	Nodes: {  Outputs: { [TNodeName]: { [TGateID]: { [TNodeName]: true } } }, Inputs: { [TNodeName]: { [TGateID]: { [TNodeName]: true } } }, Signals: { [TNodeName]: TSignal } },
	Attributes: { [string]: any },
	Process: (any, any?) -> () -- self, payload
}

-- ----------------------------- ------------- STATE ------------------ ---------------------------
-- Immediate processing queue: track which gate IDs need processing
local ImmediateQueue: { TGateID } = {}
local UpdateCounts: { [TGateID]: number } = {}

-- Frame overflow handling
local DeferredQueue: { TGateID } = {}
local DeferredSet: { [TGateID]: true } = {}

-- Delayed output scheduling: [FireTime] = { ScheduledWakeup, ... }
local TimeWheel: { [number]: { ScheduledWakeup } } = {}

-- Current execution stack (for ForcePropagation context)
local ExecutionStack: { ExecutionContext } = {}

-- Mapping gateID -> { WakeupKey: ScheduledWakeup }
local PendingWakeups: { [TGateID]: { [string]: ScheduledWakeup } } = {}
local PendingWireUpdates = setmetatable({}, { __mode = "k" })

local Updates = {}

-- Reference to GateService instances (injected at initialization)
local Instances: { [TGateID]: TGateInstance } = {}

-- ----------------------------- ---------- TIME WHEEL UTILITIES ------- ---------------------------

local function quantizeTime(delay: number): number
	local targetTime = os.clock() + delay
	return math.ceil(targetTime / TICK_RATE) * TICK_RATE
end

local function insertWakeup(gateID: TGateID, key: string, payload: any, delay: number)
	if not PendingWakeups[gateID] then
		PendingWakeups[gateID] = {}
	end

	-- Soft delete existing wakeup for this specific key
	local existing = PendingWakeups[gateID][key]
	if existing then
		existing.Active = false  
	end

	local targetTime = quantizeTime(delay)

	local wakeup: ScheduledWakeup = {
		GateID = gateID,
		WakeupKey = key,
		Payload = payload,
		FireTime = targetTime,
		Active = true,
	}

	PendingWakeups[gateID][key] = wakeup

	if not TimeWheel[targetTime] then
		TimeWheel[targetTime] = {}
	end
	table.insert(TimeWheel[targetTime], wakeup)
end

-- ----------------------------- ------- CORE UPDATE PROPAGATION -------- ---------------------------

--[[ 
	Updates.ForcePropagation(outputName: TNodeName): void
	
	Called from within a gate's Process function to force propagation of an output
	regardless of whether its signal value changed.
]]
function Updates.ForcePropagation(outputName: TNodeName)
	if #ExecutionStack == 0 then
		warn("[Updates.ForcePropagation] Called outside of gate execution context!")
		return
	end

	local context = ExecutionStack[#ExecutionStack]
	context.ForcePropagateOutputs[outputName] = true
end

--[[ 
	Updates.Propagate(gateID: TGateID): void
	
	Internal function. Queues a gate for immediate execution. If the gate has 
	already been updated MAX_UPDATES_PER_GATE times this frame, defer it to the next frame.
]]
function Updates.Propagate(gateID: TGateID)
	local count = UpdateCounts[gateID] or 0

	if count >= MAX_UPDATES_PER_GATE then
		if not DeferredSet[gateID] then
			DeferredSet[gateID] = true
			table.insert(DeferredQueue, gateID)
		end
		return
	end

	UpdateCounts[gateID] = count + 1
	table.insert(ImmediateQueue, gateID)
end

--[[ 
	PropagateFromOutput(gateID: TGateID, outputName: TNodeName): void
	
	Internal function. Queues all downstream gates that are connected to a 
	specific output of this gate.
]]
local function PropagateFromOutput(gateID: TGateID, outputName: TNodeName)
	local gate = Instances[gateID]
	if not gate or not gate.Nodes.Outputs[outputName] then
		return
	end

	local outputNode = gate.Nodes.Outputs[outputName]
	
	for downstreamGateID, inputNodeNames in pairs(outputNode) do
		for inputNodeName in pairs(inputNodeNames) do
			Updates.Propagate(downstreamGateID)
		end
	end
end

--[[ 
	Updates.ProcessGate(gateID: TGateID, payload: any?): void
	
	Executes a gate's Process function with an optional payload, handling 
	output change detection, visual updates, and propagation.
	Exposed publicly so GateService.Interact can trigger standard processing.
]]
function Updates.ProcessGate(gateID: TGateID, payload: any?)
	local gate = Instances[gateID]
	if not gate or not gate.Process then
		return
	end

	-- Push execution context
	local context: ExecutionContext = {
		GateID = gateID,
		Depth = #ExecutionStack + 1,
		ForcePropagateOutputs = {},
	}
	table.insert(ExecutionStack, context)

	-- Store previous signal state to detect changes
	local previousSignals: { [TNodeName]: TSignal } = {}
	for outputName, signal in pairs(gate.Nodes.Signals) do
		previousSignals[outputName] = signal
	end

	-- Execute gate logic with payload
	gate:Process(payload)

	-- Pop execution context
	table.remove(ExecutionStack)

	local hasOutputsActive = false
	
	-- Propagate any outputs that changed (Or if flagged)
	for outputName, currentSignal in pairs(gate.Nodes.Signals) do
		if Signals.toBoolean(currentSignal) then hasOutputsActive = true end
		
		local previousSignal = previousSignals[outputName]
		local wasForcePropagated = context.ForcePropagateOutputs[outputName]
	
		if previousSignal ~= currentSignal or wasForcePropagated then
			PropagateFromOutput(gateID, outputName)

			local wires = Connections.GetOutgoing(gateID, outputName)
			for _, wire in ipairs(wires) do
				Updates.QueueWireColorUpdate(wire, currentSignal)
			end
		end
	end

	-- Change DisplayName's color (if any)
	local displayGui = (gate.Model.Decoration :: Folder):FindFirstChild("DisplayNameGui", true)
	if displayGui then
		local text: TextLabel = displayGui:FindFirstChildWhichIsA("TextLabel")
		if text then
			if hasOutputsActive and text.TextStrokeTransparency ~= 0.7 then text.TextStrokeTransparency = 0.7 end
			if not hasOutputsActive and text.TextStrokeTransparency ~= 1.0 then text.TextStrokeTransparency = 1.0 end
		end
	end
end

--[[ 
	ProcessTimeWheel(now: number): void
	
	Internal function that fires all scheduled wakeups whose 
	FireTime has passed, supplying the payload to ProcessGate.
]]
local function ProcessTimeWheel(now: number)
	local quantizedNow = math.ceil(now / TICK_RATE) * TICK_RATE

	for timestamp, wakeups in pairs(TimeWheel) do
		if timestamp <= quantizedNow then
			for _, wakeup in ipairs(wakeups) do
				if wakeup.Active then
					local gateID = wakeup.GateID
					local key = wakeup.WakeupKey
					local gate = Instances[gateID]

					if gate then
						-- Clear pending mapping
						if PendingWakeups[gateID] and PendingWakeups[gateID][key] == wakeup then
							PendingWakeups[gateID][key] = nil
						end

						-- Process the gate with its scheduled payload!
						Updates.ProcessGate(gateID, wakeup.Payload)
					end
				end
			end
			TimeWheel[timestamp] = nil
		end
	end
end

--[[ 
	Updates.QueueWireColorUpdate(wire: Beam, signal: TSignal): void
	
	Queues a wire color update to be applied at the end of the frame.
]]
function Updates.QueueWireColorUpdate(wire: any, signal: TSignal)
	PendingWireUpdates[wire] = { wire = wire, signal = signal }
end

-- ----------------------------- ------------- MAIN LOOP -------------- ---------------------------

local function step(dt: number)
	local now = os.clock()

	-- Phase 1: Fire scheduled delayed wakeups
	ProcessTimeWheel(now)

	-- Phase 2: Inject deferred gates from last frame
	for _, gateID in ipairs(DeferredQueue) do
		table.insert(ImmediateQueue, gateID)
		UpdateCounts[gateID] = 1  -- Reset counter for new frame
	end
	table.clear(DeferredQueue)
	table.clear(DeferredSet)

	-- Phase 3: Process immediate queue
	local steps = 0
	local i = 1

	while i <= #ImmediateQueue do
		local gateID = ImmediateQueue[i]
		Updates.ProcessGate(gateID) -- No payload for standard propagation

		steps += 1
		if steps > MAX_TOTAL_STEPS then
			warn("[Updates] Simulation Panic! Step limit reached. Possible infinite loop detected.")
			break
		end
		i += 1
	end

	-- Phase 4: Cleanup
	table.clear(ImmediateQueue)

	-- Phase 5: Apply batched wire color updates
	for wire, data in pairs(PendingWireUpdates) do
		Connections.UpdateColor(data.wire, data.signal)
	end
	table.clear(PendingWireUpdates)
	table.clear(UpdateCounts)
end

-- ----------------------------- ----------- SCHEDULING API ----------- ---------------------------

--[[ 
	Updates.ScheduleWakeup(gateID: TGateID, delayTime: number, payload: any, wakeupKey: string?): void
	
	Schedules the gate to be evaluated in the future. The gate's `Process` function 
	will be called with the provided `payload`.
	`wakeupKey` is optional (defaults to "Default") and allows running multiple concurrent timers.
]]
function Updates.ScheduleWakeup(gateID: TGateID, delayTime: number, payload: any, wakeupKey: string?)
	local key = wakeupKey or "Default"
	insertWakeup(gateID, key, payload, delayTime or 0)
end

--[[ 
	Updates.CancelWakeup(gateID: TGateID, wakeupKey: string?): void
	
	Cancels a specific pending wakeup for a gate.
]]
function Updates.CancelWakeup(gateID: TGateID, wakeupKey: string?)
	local key = wakeupKey or "Default"
	if not PendingWakeups[gateID] then
		return
	end

	local wakeup = PendingWakeups[gateID][key]
	if wakeup then
		wakeup.Active = false
		PendingWakeups[gateID][key] = nil
	end
end

--[[ 
	Updates.CancelAllWakeups(gateID: TGateID): void
	
	Cancels all pending wakeups for a gate. Call this inside GateService.Destroy!
]]
function Updates.CancelAllWakeups(gateID: TGateID)
	if not PendingWakeups[gateID] then
		return
	end

	for key, wakeup in pairs(PendingWakeups[gateID]) do
		if wakeup then
			wakeup.Active = false
		end
	end
	table.clear(PendingWakeups[gateID])
end

--[[ 
	Updates.IsWakeupScheduled(gateID: TGateID, wakeupKey: string?): boolean
	
	Returns true if a specific wakeup is currently pending.
]]
function Updates.IsWakeupScheduled(gateID: TGateID, wakeupKey: string?): boolean
	local key = wakeupKey or "Default"
	if not PendingWakeups[gateID] then
		return false
	end

	local wakeup = PendingWakeups[gateID][key]
	return wakeup ~= nil and wakeup.Active
end

-- ----------------------------- ---------- INITIALIZATION ---------- ---------------------------

local isActive = false
function Updates.Initialize(instances: { [TGateID]: TGateInstance })
	if isActive then warn("Updates is already active! Ignoring..") return end
	Instances = instances
	RunService.Heartbeat:Connect(step)
	isActive = true
end

-- ----------------------------- ----------- END OF MODULE ------------ ---------------------------

return Updates
