--[[ UPDATES (MULTI-OUTPUT GATES)
	Handles signal propagation through the circuit with frame-aware batching.
	
	Key Features:
	  1. Multi-output gates: Each gate can have multiple independent outputs
	  2. Same-frame propagation: Gates update immediately unless they exceed MAX_UPDATES_PER_GATE
	  3. Frame deferrals: Overflowing gates defer to next frame with reset counter
	  4. Per-output delays: Gates can pause signal propagation for specific outputs via Updates.Wait(outputName, delayTime)
	  5. Cancellable delays: Any gate can cancel its own delayed outputs
	  6. Output-aware propagation: Only affected downstream gates are re-processed
]]

-- Requires and Services
local RunService = game:GetService("RunService")
local Connections = require(script.Parent.Connections)

-- ----------------------------- ---------- CONFIGURATION ----------- ---------------------------

local TICK_RATE = 0.1  -- Time wheel quantization granularity
local MAX_UPDATES_PER_GATE = 30  -- Threshold before frame deferral
local MAX_TOTAL_STEPS = 10000  -- Circuit step limit (prevents infinite loops)

-- ----------------------------- ------------- TYPES ------------------ ---------------------------

type TGateID = number
type TNodeName = string
type TSignal = string | number | boolean

type DelayedOutput = {
	GateID: TGateID,
	OutputName: TNodeName,
	Signal: TSignal,
	FireTime: number,
	Active: boolean,
}

type ExecutionContext = {
	GateID: TGateID,
	Depth: number,
	DeferredOutputs: { [TNodeName]: number },  -- { outputName: delayTime }
}

type TGateInstance = {
	Id: number,
	OwnerId: number,
	Model: Model,

	Nodes: {  Outputs: { [TNodeName]: { [TGateID]: { [TNodeName]: true } } }, Inputs: { [TNodeName]: { [TGateID]: { [TNodeName]: true } } }, Signals: { [TNodeName]: TSignal } },
	Attributes: { [string]: any }
}

-- ----------------------------- ------------- STATE ------------------ ---------------------------

-- Immediate processing queue: track which gate IDs need processing
local ImmediateQueue: { TGateID } = {}
local UpdateCounts: { [TGateID]: number } = {}

-- Frame overflow handling
local DeferredQueue: { TGateID } = {}
local DeferredSet: { [TGateID]: true } = {}

-- Delayed output scheduling: [FireTime] = { DelayedOutput, ... }
local TimeWheel: { [number]: { DelayedOutput } } = {}

-- Current execution stack (for Updates.Wait context)
local ExecutionStack: { ExecutionContext } = {}

-- Mapping gateID -> { outputName: DelayedOutput } (one delay per output per gate)
local PendingDelayedOutputs: { [TGateID]: { [TNodeName]: DelayedOutput } } = {}
local PendingWireUpdates --[[: { [number]: { wire: any, signal: TSignal } }]] = setmetatable({}, { __mode = "k" })

local Updates = {}

-- Reference to GateService instances (injected at initialization)
local Instances: { [TGateID]: TGateInstance } = {}

-- ----------------------------- ---------- TIME WHEEL UTILITIES ------- ---------------------------

local function quantizeTime(delay: number): number
	local targetTime = os.clock() + delay
	return math.ceil(targetTime / TICK_RATE) * TICK_RATE
end

local function insertDelayedOutput(gateID: TGateID, outputName: TNodeName, signal: TSignal, delay: number)
	-- Cancel any existing delayed output for this gate's output node
	if not PendingDelayedOutputs[gateID] then
		PendingDelayedOutputs[gateID] = {}
	end

	local existing = PendingDelayedOutputs[gateID][outputName]
	if existing then
		existing.Active = false  -- Soft delete
	end

	local targetTime = quantizeTime(delay)

	local delayedOutput: DelayedOutput = {
		GateID = gateID,
		OutputName = outputName,
		Signal = signal,
		FireTime = targetTime,
		Active = true,
	}

	PendingDelayedOutputs[gateID][outputName] = delayedOutput

	if not TimeWheel[targetTime] then
		TimeWheel[targetTime] = {}
	end
	table.insert(TimeWheel[targetTime], delayedOutput)
end

-- ----------------------------- ------- CORE UPDATE PROPAGATION -------- ---------------------------

--[[ 
	Updates.Wait(outputName: string, delayTime: number): void
	
	Called from within a gate's Process function to delay the propagation 
	of a specific output. The gate logic completes normally, but this specific
	output signal won't propagate downstream until after the delay.
	
	Can be called conditionally - if Process returns before calling Wait(),
	the output propagates immediately (no delay).
	
	Supports multiple outputs: can delay different outputs for different durations
	by calling Wait multiple times.
	
	Example DELAY gate:
	  function Process(self)
	    local input = self:ReadInput("Input").Raw
	    local delayTime = self.Attributes.Time
	    
	    self.Nodes.Signals["Output"] = input
	    Updates.Wait("Output", delayTime)
	  end
	
	Example REPEATER with cancellation:
	  function Process(self)
	    local isEnabled = self:ReadInput("Enable").AsBoolean()
	    
	    if not isEnabled then
	      self.Nodes.Signals["Output"] = false
	      Updates.CancelOutput(self.Id, "Output")
	      return
	    end
	    
	    if Updates.IsOutputWaiting(self.Id, "Output") then
	      return  -- Already scheduled, wait for it to fire
	    end
	    
	    self.Nodes.Signals["Output"] = not self.Nodes.Signals["Output"]
	    Updates.Wait("Output", self.Attributes.Frequency)
	  end
]]
function Updates.Wait(outputName: TNodeName, delayTime: number)
	if #ExecutionStack == 0 then
		warn("[Updates.Wait] Called outside of gate execution context!")
		return
	end
	
	local context = ExecutionStack[#ExecutionStack]
	local gateID = context.GateID
	local gate = Instances[gateID]
	
	if not gate then
		warn("[Updates.Wait] Gate " .. gateID .. " does not exist!")
		return
	end
	
	if not gate.Nodes.Signals[outputName] then
		warn("[Updates.Wait] Gate " .. gateID .. " has no output '" .. outputName .. "'")
		return
	end
	
	if delayTime and delayTime > 0 then
		-- Schedule this gate's output for delayed propagation
		insertDelayedOutput(gateID, outputName, gate.Nodes.Signals[outputName], delayTime)
		context.DeferredOutputs[outputName] = delayTime
	end
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
	
	-- For each gate connected to this output
	for downstreamGateID, inputNodeNames in pairs(outputNode) do
		for inputNodeName in pairs(inputNodeNames) do
			-- Queue the downstream gate
			Updates.Propagate(downstreamGateID)
		end
	end
end

--[[ 
	ProcessGate(gateID: TGateID): void
	
	Internal function that executes a gate's Process function and handles 
	output change detection and propagation.
]]
local function ProcessGate(gateID: TGateID)
	local gate = Instances[gateID]
	if not gate or not gate.Process then
		return
	end

	-- Push execution context for Updates.Wait
	local context: ExecutionContext = {
		GateID = gateID,
		Depth = #ExecutionStack + 1,
		DeferredOutputs = {},
	}
	table.insert(ExecutionStack, context)

	-- Store previous signal state to detect changes
	local previousSignals: { [TNodeName]: TSignal } = {}
	for outputName, signal in pairs(gate.Nodes.Signals) do
		previousSignals[outputName] = signal
	end

	-- Execute gate logic
	gate:Process()

	-- Pop execution context
	table.remove(ExecutionStack)

	-- Propagate any outputs that changed and weren't deferred
	for outputName, currentSignal in pairs(gate.Nodes.Signals) do
		local previousSignal = previousSignals[outputName]
		local wasDeferred = context.DeferredOutputs[outputName] ~= nil
	
		-- Only propagate if: (1) signal changed AND (2) wasn't deferred via Updates.Wait
		if previousSignal ~= currentSignal and not wasDeferred then
			PropagateFromOutput(gateID, outputName)

			local outputNode = gate.Nodes.Outputs[outputName]
			if outputNode then
			local wireParent = gate.Model.Nodes[outputName]
				for _, wire in ipairs(wireParent:GetChildren()) do
					if wire:IsA("Beam") then
						Updates.QueueWireColorUpdate(wire, currentSignal)
					end
				end
			end
		end
	end
end

--[[ 
	ProcessTimeWheel(now: number): void
	
	Internal function that fires all scheduled delayed outputs whose 
	FireTime has passed.
]]
local function ProcessTimeWheel(now: number)
	local quantizedNow = math.ceil(now / TICK_RATE) * TICK_RATE

	for timestamp, delayedOutputs in pairs(TimeWheel) do
		if timestamp <= quantizedNow then
			for _, delayedOutput in ipairs(delayedOutputs) do
				if delayedOutput.Active then
					local gateID = delayedOutput.GateID
					local outputName = delayedOutput.OutputName
					local gate = Instances[gateID]

					if gate then
						-- Clear pending mapping
						if PendingDelayedOutputs[gateID] and PendingDelayedOutputs[gateID][outputName] == delayedOutput then
							PendingDelayedOutputs[gateID][outputName] = nil
						end

						-- Apply delayed signal
						gate.Nodes.Signals[outputName] = delayedOutput.Signal

						-- Queue wire color updates
						local outputNode = gate.Nodes.Outputs[outputName]
						if outputNode then
							local wireParent = gate.Model.Nodes[outputName]
								for _, wire in ipairs(wireParent:GetChildren()) do
									if wire:IsA("Beam") then
										Updates.QueueWireColorUpdate(wire, delayedOutput.Signal)
									end
								end
						end

						-- Propagate downstream
						PropagateFromOutput(gateID, outputName)
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
	Multiple updates to the same wire are coalesced into one.
]]
function Updates.QueueWireColorUpdate(wire: any, signal: TSignal)
	PendingWireUpdates[wire] = { wire = wire, signal = signal }
end

-- ----------------------------- ------------- MAIN LOOP -------------- ---------------------------

local function step(dt: number)
	local now = os.clock()

	-- Phase 1: Fire scheduled delayed outputs
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
		ProcessGate(gateID)

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
	table.clear(PendingWireUpdates)table.clear(UpdateCounts)
end

-- ----------------------------- ----------- CANCELLATION API ----------- ---------------------------

--[[ 
	Updates.CancelOutput(gateID: TGateID, outputName: TNodeName): void
	
	Cancels any pending delayed output for the given gate output.
	
	Example REPEATER cancellation:
	  if not isEnabled then
	    Updates.CancelOutput(self.Id, "Output")
	    self.Nodes.Signals["Output"] = false
	    return
	  end
]]
function Updates.CancelOutput(gateID: TGateID, outputName: TNodeName)
	if not PendingDelayedOutputs[gateID] then
		return
	end

	local delayedOutput = PendingDelayedOutputs[gateID][outputName]
	if delayedOutput then
		delayedOutput.Active = false
		PendingDelayedOutputs[gateID][outputName] = nil
	end
end

--[[ 
	Updates.CancelAllOutputs(gateID: TGateID): void
	
	Cancels all pending delayed outputs for a gate.
]]
function Updates.CancelAllOutputs(gateID: TGateID)
	if not PendingDelayedOutputs[gateID] then
		return
	end

	for outputName, delayedOutput in pairs(PendingDelayedOutputs[gateID]) do
		if delayedOutput then
			delayedOutput.Active = false
		end
	end
	table.clear(PendingDelayedOutputs[gateID])
end

--[[ 
	Updates.IsOutputWaiting(gateID: TGateID, outputName: TNodeName): boolean
	
	Returns true if a specific output has a pending delayed signal.
	
	Useful for gates like REPEATER that want to check if they're already scheduled.
]]
function Updates.IsOutputWaiting(gateID: TGateID, outputName: TNodeName): boolean
	if not PendingDelayedOutputs[gateID] then
		return false
	end

	local delayedOutput = PendingDelayedOutputs[gateID][outputName]
	return delayedOutput ~= nil and delayedOutput.Active
end

-- ----------------------------- ---------- INITIALIZATION ---------- ---------------------------

--[[ 
	Updates.Initialize(instances: { [number]: TGateInstance }): void
	
	Must be called by GateService to inject the gate instances reference.
	This is required for Updates to access gate data during processing.
]]
local isActive = false
function Updates.Initialize(instances: { [TGateID]: TGateInstance })
	if isActive then warn("Updates is already active! Ignoring..") end
	Instances = instances
	RunService.Heartbeat:Connect(step)
	isActive = true
end

-- ----------------------------- ----------- END OF MODULE ------------ ---------------------------

return Updates
