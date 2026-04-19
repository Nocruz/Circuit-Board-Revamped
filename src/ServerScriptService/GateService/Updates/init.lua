-- Updates.lua (Fixed Rule 5: Self-Referential Buffering)
local RunService = game:GetService("RunService")
local Connections = require(script.Parent.Connections)
local Signals = require(script.Parent.Signals)
local VisualOptimizer = require(script.VisualOptimizer)

local Updates = {}

-- Config
local TICK_RATE = 0.1
local MAX_UPDATES_PER_GATE = 30
local MAX_TOTAL_STEPS = 5000

-- State
local Instances = {}
local UpdateCounts = {}
local isActive = false

-- Fast O(1) BFS Queue
local BFSQueue = {}
local queueHead = 1
local queueTail = 1
local InQueue = {}

-- Deferred limits & TimeWheel
local DeferredQueue = {}
local TimeWheel = {}
local PendingWakeups = {}

-- Self-Propagation Buffer (Rule 5)
local currentExecutingGate = nil
local localFollowups = {}

-------------------------------------------------
-- Queue Helpers
-------------------------------------------------
local function pushToBFS(gateID, payload)
    -- Deduplication (Rule 6)
    if payload == nil then
        if InQueue[gateID] then return end
        InQueue[gateID] = true
    end

    BFSQueue[queueTail] = { gateID = gateID, payload = payload }
    queueTail = queueTail + 1
end

local function popFromBFS()
    if queueHead < queueTail then
        local item = BFSQueue[queueHead]
        BFSQueue[queueHead] = nil
        queueHead = queueHead + 1
        
        -- Reset indices to prevent memory leak once queue is empty
        if queueHead == queueTail then
            queueHead = 1
            queueTail = 1
        end
        return item
    end
    return nil
end

-------------------------------------------------
-- Core Processing
-------------------------------------------------
local function quantizeTime(delay)
    local targetTime = os.clock() + delay
    return math.ceil(targetTime / TICK_RATE) * TICK_RATE
end

local function propagateFromOutput(gateID, outputName)
    local gate = Instances[gateID]
    if not gate or not gate.Nodes or not gate.Nodes.Outputs or not gate.Nodes.Outputs[outputName] then return end

    local outputNode = gate.Nodes.Outputs[outputName]
    for downstreamGateID, _ in pairs(outputNode) do
        -- Rule 5: If it propagates to itself, buffer it to be pushed LAST.
        if downstreamGateID == currentExecutingGate then
            table.insert(localFollowups, { gateID = downstreamGateID, payload = nil })
        else
            pushToBFS(downstreamGateID, nil)
        end
    end
end

local function processGate(gateID, payload)
    local gate = Instances[gateID]
    if not gate or not gate.Process then return end

    -- Capture previous signals
    local previousSignals = {}
    if gate.Nodes and gate.Nodes.Signals then
        for name, sig in pairs(gate.Nodes.Signals) do 
            previousSignals[name] = sig 
        end
    end

    -- Setup local buffer to intercept self-propagations
    local previousExecuting = currentExecutingGate
    local previousFollowups = localFollowups
    
    currentExecutingGate = gateID
    localFollowups = {}

    -- Execute Logic
    local ok, err = pcall(function() gate:Process(payload) end)
    if not ok then warn("Gate Process Error: " .. tostring(err)) end

    -- Check for signal changes
    if gate.Nodes and gate.Nodes.Signals then
        local hasOutputsActive = false
        
        for outputName, currentSignal in pairs(gate.Nodes.Signals) do
            local isTruthful = Signals.toBoolean(currentSignal)
            if isTruthful then hasOutputsActive = true end
            
            if previousSignals[outputName] ~= currentSignal then
                propagateFromOutput(gateID, outputName)
                
                -- Visual update for wires
                local wires = Connections.GetOutgoing(gateID, outputName)
                for _, wire in ipairs(wires) do
                    VisualOptimizer.Register(wire, { 
                        Color = ColorSequence.new(if isTruthful then Color3.new(0.9, 0.9, 1) else Color3.new(0, 0, 0.1)) 
                    })
                end
            end
        end

        -- Visual update for GUI
        local displayGui = (gate.Model and gate.Model.Decoration) and (gate.Model.Decoration:FindFirstChild("DisplayNameGui", true))
        if displayGui then
            local text = displayGui:FindFirstChildWhichIsA("TextLabel")
            if text then
                VisualOptimizer.Register(text, { TextStrokeTransparency = if hasOutputsActive then 0.7 else 1.0 })
            end
        end
    end

    -- Flush buffered self-propagations AFTER downstream propagations
    local currentFollowups = localFollowups
    
    currentExecutingGate = previousExecuting
    localFollowups = previousFollowups
    
    for _, followup in ipairs(currentFollowups) do
        pushToBFS(followup.gateID, followup.payload)
    end
end

-------------------------------------------------
-- Public API
-------------------------------------------------
function Updates.Propagate(gateID, payload)
    -- Rule 5 Intercept: Explicit self-propagation
    if gateID == currentExecutingGate then
        table.insert(localFollowups, { gateID = gateID, payload = payload })
    else
        pushToBFS(gateID, payload)
    end
end

function Updates.ScheduleWakeup(gateID, delayTime, payload, wakeupKey)
    local key = wakeupKey or "Default"
    
    if PendingWakeups[gateID] and PendingWakeups[gateID][key] then
        PendingWakeups[gateID][key].Active = false
    end

    if not delayTime or delayTime <= 0 then
        -- Rule 5 Intercept: 0-delay self-wakeup
        if gateID == currentExecutingGate then
            table.insert(localFollowups, { gateID = gateID, payload = payload })
        else
            pushToBFS(gateID, payload)
        end
        return
    end

    local targetTime = quantizeTime(delayTime)
    local wakeupNode = { GateID = gateID, WakeupKey = key, Payload = payload, Active = true }
    
    if not PendingWakeups[gateID] then PendingWakeups[gateID] = {} end
    PendingWakeups[gateID][key] = wakeupNode

    if not TimeWheel[targetTime] then TimeWheel[targetTime] = {} end
    table.insert(TimeWheel[targetTime], wakeupNode)
end

function Updates.CancelWakeup(gateID, wakeupKey)
    local key = wakeupKey or "Default"
    if PendingWakeups[gateID] and PendingWakeups[gateID][key] then
        PendingWakeups[gateID][key].Active = false
        PendingWakeups[gateID][key] = nil
    end
end

function Updates.CancelAllWakeups(gateID)
    if not PendingWakeups[gateID] then return end
    for k, w in pairs(PendingWakeups[gateID]) do
        w.Active = false
    end
    table.clear(PendingWakeups[gateID])
end

function Updates.IsWakeupScheduled(gateID, wakeupKey)
    local key = wakeupKey or "Default"
    if not PendingWakeups[gateID] then return false end
    local wakeup = PendingWakeups[gateID][key]
    return wakeup ~= nil and wakeup.Active
end

function Updates.RegisterVisualChange(instance, properties)
    VisualOptimizer.Register(instance, properties)
end

-------------------------------------------------
-- Main Loop (RunService)
-------------------------------------------------
local function step()
    local now = os.clock()
    local quantizedNow = math.ceil(now / TICK_RATE) * TICK_RATE

    local currentDeferred = DeferredQueue
    DeferredQueue = {}
    for _, item in ipairs(currentDeferred) do
        pushToBFS(item.gateID, item.payload)
    end

    for timestamp, wakeups in pairs(TimeWheel) do
        if timestamp <= quantizedNow then
            for _, wakeup in ipairs(wakeups) do
                if wakeup.Active then
                    pushToBFS(wakeup.GateID, wakeup.Payload)
                    if PendingWakeups[wakeup.GateID] then
                        PendingWakeups[wakeup.GateID][wakeup.WakeupKey] = nil
                    end
                end
            end
            TimeWheel[timestamp] = nil
        end
    end

    local steps = 0
    while queueHead < queueTail do
        local item = popFromBFS()
        local gateID = item.gateID
        local payload = item.payload

        if payload == nil then
            InQueue[gateID] = nil
        end

        local currentCount = (UpdateCounts[gateID] or 0)
        if currentCount >= MAX_UPDATES_PER_GATE then
            table.insert(DeferredQueue, item)
            continue
        end

        local Instances = Instances
        UpdateCounts[gateID] = currentCount + 1
        processGate(gateID, payload)

        steps = steps + 1
        if steps > MAX_TOTAL_STEPS then
            warn("[Updates] BFS Panic! Step limit reached. Possible runaway cycle.")
            break
        end
    end

    VisualOptimizer.ApplyAll()
    table.clear(UpdateCounts)
end

function Updates.Initialize(instances)
    if isActive then warn("Updates already active") return end
    Instances = instances or {}
    RunService.Heartbeat:Connect(step)
    isActive = true
end

return Updates
