-- Updates.lua (redesigned)
local RunService = game:GetService("RunService")
local Connections = require(script.Parent.Connections)
local Signals = require(script.Parent.Signals)

local Updates = {}

-- Config
local TICK_RATE = 0.1
local MAX_UPDATES_PER_GATE = 30
local MAX_TOTAL_STEPS = 1000

-- Types omitted for brevity

-- State
local Instances = {}
local ExecutionStack = {}
local UpdateCounts = {}
local DeferredQueue = {}
local DeferredSet = {}
local DeferredPayloads = {}
local TimeWheel = {}
local PendingWakeups = {}
local DepthQueues = {} -- [depth] = { {gateID, payload}, ... }
local MaxDepth = -1
local PendingWireUpdates = setmetatable({}, { __mode = "k" })
local isActive = false

-- Utilities
local function quantizeTime(delay)
    local targetTime = os.clock() + delay
    return math.ceil(targetTime / TICK_RATE) * TICK_RATE
end

local function pushDepthQueue(gateID, payload, depth)
    depth = depth or 0
    if not DepthQueues[depth] then DepthQueues[depth] = {} end
    table.insert(DepthQueues[depth], { gateID = gateID, payload = payload })
    if depth > MaxDepth then MaxDepth = depth end
end

local function findDepthInStack(gateID)
    for i = #ExecutionStack, 1, -1 do
        if ExecutionStack[i].GateID == gateID then
            return ExecutionStack[i].Depth
        end
    end
    return nil
end

-- Wakeup insertion
local function insertWakeup(gateID, key, payload, delay)
    if not PendingWakeups[gateID] then PendingWakeups[gateID] = {} end
    local existing = PendingWakeups[gateID][key]
    if existing then existing.Active = false end

    if not delay or delay <= 0 then
        local wakeup = { GateID = gateID, WakeupKey = key, Payload = payload, FireTime = 0, Active = true }
        PendingWakeups[gateID][key] = wakeup
        local depth = (#ExecutionStack > 0) and ExecutionStack[#ExecutionStack].Depth or 0
        pushDepthQueue(gateID, payload, depth)
        return
    end

    local targetTime = quantizeTime(delay)
    local wakeup = { GateID = gateID, WakeupKey = key, Payload = payload, FireTime = targetTime, Active = true }
    PendingWakeups[gateID][key] = wakeup
    TimeWheel[targetTime] = TimeWheel[targetTime] or {}
    table.insert(TimeWheel[targetTime], wakeup)
end

-- PropagateFromOutput: choose child depth (SCC/self-loop aware)
local function PropagateFromOutput(originGateID, outputName, originDepth)
    local gate = Instances[originGateID]
    if not gate or not gate.Nodes or not gate.Nodes.Outputs or not gate.Nodes.Outputs[outputName] then return end

    local outputNode = gate.Nodes.Outputs[outputName]
    local baseDepth = originDepth or ((#ExecutionStack > 0) and ExecutionStack[#ExecutionStack].Depth or 0)

    for downstreamGateID, _ in pairs(outputNode) do
        local existingDepth = findDepthInStack(downstreamGateID)
        local childDepth
        if existingDepth then
            childDepth = existingDepth
        elseif downstreamGateID == originGateID then
            childDepth = baseDepth
        else
            childDepth = baseDepth + 1
        end
        Updates.Propagate(downstreamGateID, nil, childDepth)
    end
end

-- Queue wire color update
function Updates.QueueWireColorUpdate(wire, signal)
    PendingWireUpdates[wire] = { wire = wire, signal = signal }
end

-- Private gate processing
local function _processGate(gateID, payload, forcedDepth)
    local gate = Instances[gateID]
    if not gate or not gate.Process then return end

    local context = {
        GateID = gateID,
        Depth = forcedDepth or (#ExecutionStack + 1),
        ForcePropagateOutputs = {},
    }
    table.insert(ExecutionStack, context)

    local previousSignals = {}
    if gate.Nodes and gate.Nodes.Signals then
        for name, sig in pairs(gate.Nodes.Signals) do previousSignals[name] = sig end
    end

    local ok, err = pcall(function() gate:Process(payload) end)

    -- detect changes and enqueue propagation while context still on stack
    if gate.Nodes and gate.Nodes.Signals then
        local hasOutputsActive = false
        for outputName, currentSignal in pairs(gate.Nodes.Signals) do
            if Signals.toBoolean(currentSignal) then hasOutputsActive = true end
            local previousSignal = previousSignals[outputName]
            local wasForced = context.ForcePropagateOutputs[outputName]
            if previousSignal ~= currentSignal or wasForced then
                PropagateFromOutput(gateID, outputName, context.Depth)
                local wires = Connections.GetOutgoing(gateID, outputName)
                for _, wire in ipairs(wires) do
                    Updates.QueueWireColorUpdate(wire, currentSignal)
                end
            end
        end

        -- display GUI update (if present)
        local displayGui = (gate.Model and gate.Model.Decoration) and (gate.Model.Decoration:FindFirstChild("DisplayNameGui", true))
        if displayGui then
            local text = displayGui:FindFirstChildWhichIsA("TextLabel")
            if text then
                if hasOutputsActive and text.TextStrokeTransparency ~= 0.7 then text.TextStrokeTransparency = 0.7 end
                if not hasOutputsActive and text.TextStrokeTransparency ~= 1.0 then text.TextStrokeTransparency = 1.0 end
            end
        end
    end

    table.remove(ExecutionStack)
    if not ok then error(err) end
end

-- Public Propagate (payload optional, explicitDepth optional)
function Updates.Propagate(gateID, payload, explicitDepth)
    local count = UpdateCounts[gateID] or 0
    if count >= MAX_UPDATES_PER_GATE then
        -- preserve or merge payload
        local existing = DeferredPayloads[gateID]
        local merged = payload
        local gate = Instances[gateID]
        if existing and gate and gate.Attributes and type(gate.Attributes.MergeDeferredPayloads) == "function" then
            merged = gate.Attributes.MergeDeferredPayloads(existing, payload)
        elseif payload == nil then
            merged = existing
        end
        DeferredPayloads[gateID] = merged
        if not DeferredSet[gateID] then
            DeferredSet[gateID] = true
            table.insert(DeferredQueue, gateID)
        end
        return
    end

    local depth = explicitDepth
    if depth == nil then
        depth = (#ExecutionStack > 0) and ExecutionStack[#ExecutionStack].Depth or 0
    end
    pushDepthQueue(gateID, payload, depth)
end

-- Wakeup API
function Updates.ScheduleWakeup(gateID, delayTime, payload, wakeupKey)
    local key = wakeupKey or "Default"
    insertWakeup(gateID, key, payload, delayTime or 0)
end

function Updates.CancelWakeup(gateID, wakeupKey)
    local key = wakeupKey or "Default"
    if not PendingWakeups[gateID] then return end
    local wakeup = PendingWakeups[gateID][key]
    if wakeup then
        wakeup.Active = false
        PendingWakeups[gateID][key] = nil
    end
end

function Updates.CancelAllWakeups(gateID)
    if not PendingWakeups[gateID] then return end
    for k, w in pairs(PendingWakeups[gateID]) do
        if w then w.Active = false end
    end
    table.clear(PendingWakeups[gateID])
end

function Updates.IsWakeupScheduled(gateID, wakeupKey)
    local key = wakeupKey or "Default"
    if not PendingWakeups[gateID] then return false end
    local wakeup = PendingWakeups[gateID][key]
    return wakeup ~= nil and wakeup.Active
end

-- Inject deferred gates at start of tick
local function injectDeferred()
    if #DeferredQueue == 0 then return end
    for i = #DeferredQueue, 1, -1 do
        local g = DeferredQueue[i]
        local payload = DeferredPayloads[g]
        pushDepthQueue(g, payload, 0)
        DeferredPayloads[g] = nil
    end
    table.clear(DeferredQueue)
    table.clear(DeferredSet)
end

-- Move due TimeWheel entries into depth 0
local function moveDueTimeWheel(now)
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
                    pushDepthQueue(gateID, wakeup.Payload, 0)
                end
            end
            TimeWheel[timestamp] = nil
        end
    end
end

-- Drain depth queues (highest depth first)
local function drainDepthQueues()
    local steps = 0
    while MaxDepth >= 0 do
        local q = DepthQueues[MaxDepth]
        if not q or #q == 0 then
            DepthQueues[MaxDepth] = nil
            MaxDepth = MaxDepth - 1
            if MaxDepth >= 0 then continue
            else return end
        end

        local entry = table.remove(q, 1)
        local gateID, payload = entry.gateID, entry.payload

        if (UpdateCounts[gateID] or 0) >= MAX_UPDATES_PER_GATE then
            if not DeferredSet[gateID] then
                DeferredSet[gateID] = true
                table.insert(DeferredQueue, gateID)
                DeferredPayloads[gateID] = payload
            end
        else
            UpdateCounts[gateID] = (UpdateCounts[gateID] or 0) + 1
            _processGate(gateID, payload, MaxDepth)
        end

        steps = steps + 1
        if steps > MAX_TOTAL_STEPS then
            warn("[Updates] Simulation Panic! Step limit reached.")
            break
        end
    end
end

-- Main step
local function step(dt)
    local now = os.clock()

    -- Inject deferred gates (priority)
    injectDeferred()

    -- Drain depth queues (process deeper work first)
    drainDepthQueues()

    -- Move due timewheel entries into depth 0 (they will run next tick or after current drain if any)
    moveDueTimeWheel(now)

    -- Apply wire color updates
    for wire, data in pairs(PendingWireUpdates) do
        Connections.UpdateColor(data.wire, data.signal)
    end
    table.clear(PendingWireUpdates)
    table.clear(UpdateCounts)
end

-- Initialization
function Updates.Initialize(instances)
    if isActive then warn("Updates already active") return end
    Instances = instances or {}
    RunService.Heartbeat:Connect(step)
    isActive = true
end

return Updates
