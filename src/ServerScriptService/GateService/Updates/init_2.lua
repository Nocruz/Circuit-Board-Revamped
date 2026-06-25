-- Updates.lua (BFS propagation, followups, and timed wakeups)
-- Ready-to-apply replacement implementing breadth-first propagation semantics.
local RunService = game:GetService("RunService")
local Connections = require(script.Parent.Connections)
local Signals = require(script.Parent.Signals)
local VisualOptimizer = require(script.VisualOptimizer)

local Updates = {}

-- Config
local TICK_RATE = 0.1
local MAX_UPDATES_PER_GATE = 30
local MAX_TOTAL_STEPS = 1000

-- State
local Instances = {}
local ExecutionStack = {}            -- stack of { GateID, Depth, LocalFollowups = { {gateID,payload,depth,kind} } }
local UpdateCounts = {}             -- per-tick counts
local DeferredQueue = {}            -- list of gateIDs
local DeferredSet = {}              -- set of deferred gateIDs
local DeferredPayloads = {}         -- payloads for deferred gates
local TimeWheel = {}                -- timestamp -> { wakeup, ... }
local PendingWakeups = {}           -- gateID -> key -> wakeup
local DepthQueues = {}              -- depth -> { {gateID, payload, kind}, ... }
local MaxDepth = -1
local isActive = false

-- Kinds: "prop" (propagation from outputs), "followup" (self-enqueue flushed after Process), "wakeup" (timed/immediate wakeup)
local function quantizeTime(delay)
    local targetTime = os.clock() + delay
    return math.ceil(targetTime / TICK_RATE) * TICK_RATE
end

local function pushDepthQueueEntry(entry)
    local depth = entry.depth or 0
    if not DepthQueues[depth] then DepthQueues[depth] = {} end
    table.insert(DepthQueues[depth], entry)
    if depth > MaxDepth then MaxDepth = depth end
end

-- Convenience wrapper to preserve old pushDepthQueue signature
local function pushDepthQueue(gateID, payload, depth, kind)
    pushDepthQueueEntry({ gateID = gateID, payload = payload, depth = depth or 0, kind = kind or "prop" })
end

local function findDepthInStack(gateID)
    for i = #ExecutionStack, 1, -1 do
        if ExecutionStack[i].GateID == gateID then
            return ExecutionStack[i].Depth
        end
    end
    return nil
end

-- Wakeup insertion (timed or immediate)
local function insertWakeup(gateID, key, payload, delay)
    if not PendingWakeups[gateID] then PendingWakeups[gateID] = {} end
    local existing = PendingWakeups[gateID][key]
    if existing then existing.Active = false end

    if not delay or delay <= 0 then
        local wakeup = { GateID = gateID, WakeupKey = key, Payload = payload, FireTime = 0, Active = true }
        PendingWakeups[gateID][key] = wakeup

        local depth = (#ExecutionStack > 0) and ExecutionStack[#ExecutionStack].Depth or 0

        -- If scheduling a wakeup for the gate currently executing, buffer as a followup
        local top = ExecutionStack[#ExecutionStack]
        if top and top.GateID == gateID then
            top.LocalFollowups = top.LocalFollowups or {}
            table.insert(top.LocalFollowups, { gateID = gateID, payload = payload, depth = top.Depth + 1, kind = "wakeup" })
        else
            pushDepthQueue(gateID, payload, depth, "wakeup")
        end
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
        -- Propagate to downstream as a propagation entry
        Updates.Propagate(downstreamGateID, nil, childDepth)
    end
end

-- Internal gate processing
local function _processGate(gateID, payload, forcedDepth)
    local gate = Instances[gateID]
    if not gate or not gate.Process then return end

    local context = {
        GateID = gateID,
        Depth = forcedDepth or ((#ExecutionStack > 0) and ExecutionStack[#ExecutionStack].Depth or 0),
        LocalFollowups = {}, -- buffered followups/wakeups for this execution
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
            if previousSignal ~= currentSignal then
                PropagateFromOutput(gateID, outputName, context.Depth + 1)
                local wires = Connections.GetOutgoing(gateID, outputName)
                for _, wire in ipairs(wires) do
                    VisualOptimizer.Register(wire, { Color = ColorSequence.new(if Signals.toBoolean(currentSignal) then Color3.new(0.9, 0.9, 1) else Color3.new(0, 0, 0.1)) })
                end
            end
        end

        -- display GUI update (if present)
        local displayGui = (gate.Model and gate.Model.Decoration) and (gate.Model.Decoration:FindFirstChild("DisplayNameGui", true))
        if displayGui then
            local text = displayGui:FindFirstChildWhichIsA("TextLabel")
            if text then
                VisualOptimizer.Register(text, { TextStrokeTransparency = if hasOutputsActive then 0.7 else 1.0 })
            end
        end
    end

    -- Flush local followups AFTER propagation checks.
    -- Followups are pushed with kind = "followup" or "wakeup" and are lower priority at same depth.
    if context.LocalFollowups and #context.LocalFollowups > 0 then
        for _, e in ipairs(context.LocalFollowups) do
            local g = e.gateID
            local pushDepth = e.depth or (context.Depth + 1)
            if (UpdateCounts[g] or 0) >= MAX_UPDATES_PER_GATE then
                if not DeferredSet[g] then
                    DeferredSet[g] = true
                    table.insert(DeferredQueue, g)
                    DeferredPayloads[g] = e.payload
                end
            else
                pushDepthQueue(e.gateID, e.payload, pushDepth, e.kind or "followup")
            end
        end
    end

    table.remove(ExecutionStack)
    if not ok then error(err) end
end

function Updates.RegisterVisualChange(instance, properties)
    VisualOptimizer.Register(instance, properties)
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

    -- If the gate is currently executing, buffer the self-propagation as a followup
    local top = ExecutionStack[#ExecutionStack]
    if top and top.GateID == gateID then
        top.LocalFollowups = top.LocalFollowups or {}
        table.insert(top.LocalFollowups, { gateID = gateID, payload = payload, depth = top.Depth + 1, kind = "followup" })
        return
    end

    -- Normal propagation entry
    pushDepthQueue(gateID, payload, depth, "prop")
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
        if w then w.Active = false
    end
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
        pushDepthQueue(g, payload, 0, "prop")
        DeferredPayloads[g] = nil
    end
    table.clear(DeferredQueue)
    table.clear(DeferredSet)
end

-- Move due TimeWheel entries into depth 0 as wakeup entries
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
                    pushDepthQueue(gateID, wakeup.Payload, 0, "wakeup")
                end
            end
            TimeWheel[timestamp] = nil
        end
    end
end

-- Helper: pick an entry from a depth queue preferring prop/wakeup over followup
local function pickEntryFromDepthQueue(q)
    -- prefer first entry whose kind ~= "followup"
    for i = 1, #q do
        if q[i].kind ~= "followup" then
            return table.remove(q, i)
        end
    end
    -- otherwise pop FIFO
    return table.remove(q, 1)
end

-- Drain depth queues using BFS rounds: iterate depths (deepest-first) and pick one entry per depth per round,
-- preferring prop/wakeup entries over followups at the same depth.
local function drainDepthQueues()
    local steps = 0

    -- build list of active depths
    local activeDepths = {}
    for d = 0, MaxDepth do
        if DepthQueues[d] and #DepthQueues[d] > 0 then
            table.insert(activeDepths, d)
        end
    end
    if #activeDepths == 0 then
        MaxDepth = -1
        return
    end

    -- sort so we prefer deeper depths first in each round
    table.sort(activeDepths, function(a, b) return a > b end)

    local idx = 1
    while #activeDepths > 0 do
        local depth = activeDepths[idx]
        local q = DepthQueues[depth]

        if not q or #q == 0 then
            -- remove this depth from activeDepths
            table.remove(activeDepths, idx)
            if #activeDepths == 0 then break end
            if idx > #activeDepths then idx = 1 end
            continue
        end

        local entry = pickEntryFromDepthQueue(q)
        if not entry then
            -- nothing to process at this depth
            table.remove(activeDepths, idx)
            if #activeDepths == 0 then break end
            if idx > #activeDepths then idx = 1 end
            continue
        end

        local gateID, payload = entry.gateID, entry.payload

        if (UpdateCounts[gateID] or 0) >= MAX_UPDATES_PER_GATE then
            if not DeferredSet[gateID] then
                DeferredSet[gateID] = true
                table.insert(DeferredQueue, gateID)
                DeferredPayloads[gateID] = payload
            end
        else
            UpdateCounts[gateID] = (UpdateCounts[gateID] or 0) + 1
            _processGate(gateID, payload, depth)
        end

        steps = steps + 1
        if steps > MAX_TOTAL_STEPS then
            warn("[Updates] Simulation Panic! Step limit reached.")
            break
        end

        -- advance index (wrap)
        idx = idx + 1
        if idx > #activeDepths then idx = 1 end
    end

    -- recompute MaxDepth (cleanup)
    local newMax = -1
    for d = 0, MaxDepth do
        if DepthQueues[d] and #DepthQueues[d] > 0 then
            newMax = math.max(newMax, d)
        end
    end
    MaxDepth = newMax
end

-- Main step
local function step(dt)
    local now = os.clock()

    -- Inject deferred gates (priority)
    injectDeferred()

    -- Drain depth queues (BFS rounds, deeper-first preference)
    drainDepthQueues()

    -- Move due timewheel entries into depth 0 (they will run next tick)
    moveDueTimeWheel(now)

    -- Trigger all visual changes
    VisualOptimizer.ApplyAll()

    table.clear(UpdateCounts)
end

-- Initialization
function Updates.Initialize(instances)
    if isActive then warn("Updates already active") return end
    Instances = instances or {}
    RunService.Heartbeat:Connect(step)
    isActive = true
end

-- For testing / debugging: expose internals (optional)
function Updates._debug_getQueues()
    return {
        DepthQueues = DepthQueues,
        TimeWheel = TimeWheel,
        DeferredQueue = DeferredQueue,
        PendingWakeups = PendingWakeups,
        ExecutionStack = ExecutionStack,
    }
end

return Updates
