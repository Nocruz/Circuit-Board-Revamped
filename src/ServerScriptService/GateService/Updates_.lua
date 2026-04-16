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
local DepthQueues = {}
local MaxDepth = 0
local UpdateCounts: { [TGateID]: number } = {}

-- Frame overflow handling
local DeferredQueue: { TGateID } = {}
local DeferredSet: { [TGateID]: true } = {}

-- Delayed output scheduling: [FireTime] = { ScheduledWakeup, ... }
local TimeWheel: { [number]: { ScheduledWakeup } } = {}

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

local function pushCausal(gateID, payload, depth)
	depth = depth or 0
  if not DepthQueues[depth] then DepthQueues[depth] = {} end
  table.insert(DepthQueues[depth], { gateID = gateID, payload = payload })
  if depth > MaxDepth then MaxDepth = depth end
end
  
local function insertWakeup(gateID: TGateID, key: string, payload: any, delay: number)
	if not PendingWakeups[gateID] then PendingWakeups[gateID] = {} end
	local existing = PendingWakeups[gateID][key]
	if existing then existing.Active = false   end

	if not delay or delay <= TICK_RATE then
    -- zero-delay: attach to causal queue at current execution depth
    local depth = (#ExecutionStack > 0) and ExecutionStack[#ExecutionStack].Depth or 0
    local wakeup = { GateID = gateID, WakeupKey = key, Payload = payload, FireTime = 0, Active = true }
    PendingWakeups[gateID][key] = wakeup
    pushCausal(gateID, payload, depth)
    return
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

	TimeWheel[targetTime] = TimeWheel[targetTime] or {}
	table.insert(TimeWheel[targetTime], wakeup)
end

local function drainCausalQueues()
  local steps = 0
  while MaxDepth >= 0 do
    local q = DepthQueues[MaxDepth]
    if not q or #q == 0 then
      DepthQueues[MaxDepth] = nil
      MaxDepth = MaxDepth - 1
      if MaxDepth < 0 then break end
      return
    end
	
    local entry = table.remove(q, 1) -- FIFO within same depth
    local gateID, payload = entry.gateID, entry.payload
	
    if (UpdateCounts[gateID] or 0) >= MAX_UPDATES_PER_GATE then
      if not DeferredSet[gateID] then
          DeferredSet[gateID] = true
          table.insert(DeferredQueue, gateID)
      end
    else
      UpdateCounts[gateID] = (UpdateCounts[gateID] or 0) + 1
      -- process with forcedDepth = MaxDepth (so context.Depth matches queue depth)
      processGate(gateID, payload, MaxDepth)
    end

    steps = steps + 1
    if steps > MAX_TOTAL_STEPS then
      warn("[Updates] Simulation Panic! Step limit reached.")
      break
    end
  end
end

-- ----------------------------- ------- CORE UPDATE PROPAGATION -------- ---------------------------

-- Expose ScheduleWakeup to use insertWakeup
function Updates.ScheduleWakeup(gateID, delayTime, payload, wakeupKey)
    local key = wakeupKey or "Default"
    insertWakeup(gateID, key, payload, delayTime or 0)
end

--[[ 
	Updates.Propagate(gateID: TGateID): void
	
	Internal function. Queues a gate for immediate execution. If the gate has 
	already been updated MAX_UPDATES_PER_GATE times this frame, defer it to the next frame.
]]
function Updates.Propagate(gateID: TGateID, payload: any, explicitDepth: number?)
	local count = UpdateCounts[gateID] or 0
	
	if count >= MAX_UPDATES_PER_GATE then
		if not DeferredSet[gateID] then
			DeferredSet[gateID] = true
			table.insert(DeferredQueue, gateID)
		end
		return
	end
	
	UpdateCounts[gateID] = count + 1
	local depth = explicitDepth or ((#ExecutionStack > 0) and ExecutionStack[#ExecutionStack].Depth or 0)
  pushCausal(gateID, payload, depth)
end

--[[ 
	PropagateFromOutput(gateID: TGateID, outputName: TNodeName): void
	
	Internal function. Queues all downstream gates that are connected to a 
	specific output of this gate.
]]
local function PropagateFromOutput(gateID: TGateID, outputName: TNodeName, originDepth: number?)
	local gate = Instances[gateID]
	if not gate or not gate.Nodes.Outputs[outputName] then return end

	local outputNode = gate.Nodes.Outputs[outputName]
	local childDepth = (originDepth or ((#ExecutionStack > 0) and ExecutionStack[#ExecutionStack].Depth or 0)) + 1	
	
	for downstreamGateID, inputNodeNames in pairs(outputNode) do
		for _ in pairs(inputNodeNames) do
			Updates.Propagate(downstreamGateID, nil, childDepth)
		end
	end
end

--[[ 
	processGate(gateID: TGateID, payload: any?): void
	
	Executes a gate's Process function with an optional payload, handling 
	output change detection, visual updates, and propagation.
	Exposed publicly so GateService.Interact can trigger standard processing.
]]
function processGate(gateID: TGateID, payload: any?, forcedDepth: number?)
	local gate = Instances[gateID]
	if not gate or not gate.Process then return end

	local context: ExecutionContext = {
		GateID = gateID,
		Depth = forcedDepth or (#ExecutionStack + 1)
	}
	table.insert(ExecutionStack, context)

	-- Store previous signal state to detect changes
	local previousSignals: { [TNodeName]: TSignal } = {}
	for outputName, signal in pairs(gate.Nodes.Signals) do
		previousSignals[outputName] = signal
	end

	-- Execute gate logic with payload
	gate:Process(payload)

	local hasOutputsActive = false
	
	-- Propagate any outputs that changed (Or if flagged)
	for outputName, currentSignal in pairs(gate.Nodes.Signals) do
		if Signals.toBoolean(currentSignal) then hasOutputsActive = true end
		
		local previousSignal = previousSignals[outputName]
		if previousSignal ~= currentSignal then
			PropagateFromOutput(gateID, outputName, context.Depth + 1)
			
			local wires = Connections.GetOutgoing(gateID, outputName)
			for _, wire in ipairs(wires) do
				Updates.QueueWireColorUpdate(wire, currentSignal)
			end
		end
	end

	-- Pop execution context
	table.remove(ExecutionStack)

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
						processGate(gateID, wakeup.Payload)
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

	-- 1) inject deferred gates at front (priority)
  for _, g in ipairs(DeferredQueue) do
      pushCausal(g, nil, 0)
      UpdateCounts[g] = 1
  end
  table.clear(DeferredQueue); table.clear(DeferredSet)

  drainCausalQueues()

  -- Move due TimeWheel entries into CausalQueue (so they run same tick after current causal work)
  local quantizedNow = math.ceil(now / TICK_RATE) * TICK_RATE
  for timestamp, wakeups in pairs(TimeWheel) do
    if timestamp <= quantizedNow then
	    for _, wakeup in ipairs(wakeups) do
        if wakeup.Active then
          local gateID = wakeup.GateID
          local key = wakeup.WakeupKey
          if PendingWakeups[gateID] and PendingWakeups[gateID][key] == wakeup then
            PendingWakeups[gateID][key] = nil
          end
          -- insert into causal queue at depth 0 (external time-driven)
          pushCausal(gateID, wakeup.Payload, 0)
        end
	    end
	    TimeWheel[timestamp] = nil
    end
  end  

	-- Apply batched wire color updates
  for wire, data in pairs(PendingWireUpdates) do
    Connections.UpdateColor(data.wire, data.signal)
  end
  table.clear(PendingWireUpdates)
  table.clear(UpdateCounts)
end

-- ----------------------------- ----------- SCHEDULING API ----------- ---------------------------

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
