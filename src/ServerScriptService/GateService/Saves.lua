-- SaveManager.lua
-- Save / Load subgraphs of gates (serializable table format)
-- Features:
--  - Save(gateIdArray, opts) -> saveTable
--  - Load(saveTable, owner, opts) -> success, resultOrError
--  - Batching on creation (20 gates per batch)
--  - Wait (configurable, default 1.5s) before connecting to ensure instantiation
--  - Save includes BoxPosition and BoxSize (AABB covering all saved gates)
--
-- Notes / requirements:
--  - GateService.Instantiate is called with an extra boolean `suppressInitialPropagate`
--    parameter. If your GateService does not accept it, either add it (recommended)
--    or implement Updates.Suspend/Resume and wrap Load with those calls.
--  - Visuals are applied by GateService.Instantiate automatically (per your system).
--  - This module avoids re-applying visuals after instantiate.
--  - Connections are created only between gates included in the save.
--  - Connection ordering is deterministic: sort by timestamp, then tie-break by
--    fromGate, toGate, fromNode, toNode.
--  - On any failure during Load, created gates are destroyed (rollback).
--
-- Usage:
--  local SaveManager = require(path.to.SaveManager)
--  local saveTable = SaveManager.Save({1,2,3}, { SaveName = "Example", Owner = { Name="Juan", Id = 0 } })
--  local ok, res = SaveManager.Load(saveTable, 0, { ConnectDelay = 1.5 })
--

local GateService = require(script.Parent)
local Connections = require(script.Parent.Connections)
local Updates = require(script.Parent.Updates)

local SaveManager = {}

-- Configurable defaults
local DEFAULT_BATCH_SIZE = 20
local DEFAULT_CONNECT_DELAY = 1.5

-- Helpers --------------------------------------------------------------------

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = deepCopy(v) end
    return out
end

local function serializeVector3(v)
    return { X = v.X, Y = v.Y, Z = v.Z }
end

local function deserializeVector3(t)
    return Vector3.new(t.X or 0, t.Y or 0, t.Z or 0)
end

local function serializeCFrame(cf)
    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
    return {
        Position = serializeVector3(Vector3.new(x, y, z)),
        R00 = r00, R01 = r01, R02 = r02,
        R10 = r10, R11 = r11, R12 = r12,
        R20 = r20, R21 = r21, R22 = r22,
    }
end

local function deserializeCFrame(t)
    if not t or not t.Position then return CFrame.new() end
    local p = deserializeVector3(t.Position)
    if t.R00 == nil then
        return CFrame.new(p)
    end

    return CFrame.new(
        p.X, p.Y, p.Z,
        t.R00, t.R01, t.R02,
        t.R10, t.R11, t.R12,
        t.R20, t.R21, t.R22
    )
end

local function nowTimestamp()
    return tick()
end

local function ensureTable(t)
    if type(t) ~= "table" then return {} end
    return t
end

-- Compute AABB (BoxPosition center, BoxSize extents) covering all model pivots
local function computeBoundingBox(gates)
    local first = true
    local minX, minY, minZ, maxX, maxY, maxZ
    for _, gate in pairs(gates) do
        if gate and gate.Model and gate.Model:GetPivot() then
            local pos = gate.Model:GetPivot().Position
            if first then
                minX, minY, minZ = pos.X, pos.Y, pos.Z
                maxX, maxY, maxZ = pos.X, pos.Y, pos.Z
                first = false
            else
                if pos.X < minX then minX = pos.X end
                if pos.Y < minY then minY = pos.Y end
                if pos.Z < minZ then minZ = pos.Z end
                if pos.X > maxX then maxX = pos.X end
                if pos.Y > maxY then maxY = pos.Y end
                if pos.Z > maxZ then maxZ = pos.Z end
            end
        end
    end
    if first then
        -- no gates
        return { Position = serializeVector3(Vector3.new()), Size = serializeVector3(Vector3.new()) }
    end
    minX -= 1; minZ -= 1; maxX += 1; maxY += 1; maxZ += 1
    local minV = Vector3.new(minX, minY, minZ)
    local maxV = Vector3.new(maxX, maxY, maxZ)
    local size = maxV - minV
    local center = size * 0.5
    return { Position = serializeVector3(center), Size = serializeVector3(size) }
end

-- Connections enumeration helper: returns list of wire Instances for outgoing from gateId, outputName
local function enumerateOutgoingWires(gateId, outputName)
    local wires = {}
    local gate = GateService.GetGateInstance(gateId)
    if not gate then return wires end
    local outNode = gate.Nodes.Outputs[outputName]
    if not outNode then return wires end
    -- Connections.GetOutgoing returns array of wire Instances (per GateService usage)
    local ok, list = pcall(function() return Connections.GetOutgoing(gateId, outputName) end)
    if ok and type(list) == "table" then
        for _, w in ipairs(list) do table.insert(wires, w) end
    end
    return wires
end

-- Save -----------------------------------------------------------------------

-- options:
--  SaveName (string)
--  Owner = { Name = string, Id = number }  -- optional
--  Timestamp (number) optional
function SaveManager.Save(gateIdArray, options)
    options = options or {}
    assert(type(gateIdArray) == "table", "gateIdArray must be a table of gate IDs")

    local save = {}
    save.Version = 1
    save.Timestamp = options.Timestamp or nowTimestamp()
    save.Owner = options.Owner or { Name = "Unknown", Id = -1 }
    save.SaveName = options.SaveName or ("Save_" .. tostring(save.Timestamp))
    save.Offset = options.Offset or { X = 0, Y = 0, Z = 0 }
    save.BaseCFrame = nil

    save.Gates = {}
    save.Connections = {}

    -- Build set of requested IDs for quick membership checks
    local requestedSet = {}
    for _, id in ipairs(gateIdArray) do requestedSet[id] = true end

    -- Collect gate data
    local gatesToComputeBBox = {}
    for _, id in ipairs(gateIdArray) do
        local gate = GateService.GetGateInstance(id)
        if gate then
            local entry = {}
            -- Specification name: GateService.Instantiate sets model.Name to specificationName
            entry.Specification = gate.Name
            -- Visual overrides: copy gate.Visuals (already a table)
            entry.Visuals = deepCopy(gate.Visuals or {})
            -- Attributes: copy
            entry.Attributes = deepCopy(gate.Attributes or {})
            -- CFrame: serialize model pivot
            if gate.Model and gate.Model:GetPivot() then
                entry.CFrame = serializeCFrame(gate.Model:GetPivot())
                if save.BaseCFrame == nil then
                    save.BaseCFrame = serializeCFrame(gate.Model:GetPivot())
                end
            else
                entry.CFrame = serializeCFrame(CFrame.new())
            end
            -- Optional runtime state: call Serialize if available
            if type(gate.Serialize) == "function" then
                local ok, state = pcall(function() return gate:Serialize() end)
                if ok and type(state) == "table" then
                    entry.State = deepCopy(state)
                end
            end
            save.Gates[id] = entry
            table.insert(gatesToComputeBBox, gate)
        else
            -- Gate not found: skip silently (or you can record a warning)
            warn("Gate " .. id .. " was saved but not found")
        end
    end

    save.BaseCFrame = save.BaseCFrame or serializeCFrame(CFrame.new())

    -- Compute bounding box
    local bbox = computeBoundingBox(gatesToComputeBBox)
    save.BoxPosition = bbox.Position
    save.BoxSize = bbox.Size

    -- Collect connections (only between saved gates)
    for _, fromId in ipairs(gateIdArray) do
        local fromGate = GateService.GetGateInstance(fromId)
        if fromGate then
            for outputName, _ in pairs(fromGate.Nodes.Outputs) do
                local wires = enumerateOutgoingWires(fromId, outputName)
                for _, wire in ipairs(wires) do
                    -- Expect wire to have attributes: ToGate, ToNode, FromGate, FromNode, Timestamp
                    local toGate = wire:GetAttribute("ToGate")
                    local toNode = wire:GetAttribute("ToNode")
                    local fromNode = wire:GetAttribute("FromNode") or outputName
                    local timestamp = wire:GetAttribute("Timestamp") or nowTimestamp()
                    if requestedSet[toGate] then
                        table.insert(save.Connections, {
                            fromGate = fromId,
                            toGate = toGate,
                            fromNode = fromNode,
                            toNode = toNode,
                            timestamp = timestamp
                        })
                    end
                end
            end
        end
    end

    -- Sort connections by timestamp (stable-ish)
    table.sort(save.Connections, function(a, b)
        if a.timestamp ~= b.timestamp then return a.timestamp < b.timestamp end
        if a.fromGate ~= b.fromGate then return a.fromGate < b.fromGate end
        if a.toGate ~= b.toGate then return a.toGate < b.toGate end
        if a.fromNode ~= b.fromNode then return tostring(a.fromNode) < tostring(b.fromNode) end
        return tostring(a.toNode) < tostring(b.toNode)
    end)

    return save
end

-- Load -----------------------------------------------------------------------

-- opts:
--  BatchSize (default 20)
--  ConnectDelay (seconds to wait before connecting; default 1.5)
--  OffsetCFrame (CFrame to apply to all saved CFrames)
--  Owner (player id) - if nil, uses save.Owner.Id or 0
function SaveManager.Load(saveTable, owner, opts)
    opts = opts or {}
    local batchSize = opts.BatchSize or DEFAULT_BATCH_SIZE
    local connectDelay = opts.ConnectDelay or DEFAULT_CONNECT_DELAY
    local anchorValue = opts.Offset
    if anchorValue == nil then
        anchorValue = opts.OffsetCFrame
    end
    local hasAnchor = anchorValue ~= nil
    local anchorCFrame = CFrame.new()
    if typeof(anchorValue) == "CFrame" then
        anchorCFrame = anchorValue
    elseif typeof(anchorValue) == "Vector3" then
        anchorCFrame = CFrame.new(anchorValue)
    end
    owner = owner or (saveTable and saveTable.Owner and saveTable.Owner.Id) or 0

    -- Basic validation
    if type(saveTable) ~= "table" or type(saveTable.Gates) ~= "table" then
        return false, "Malformed saveTable"
    end

    -- Preflight: ensure all specifications exist
    for oldId, g in pairs(saveTable.Gates) do
        if type(g.Specification) ~= "string" or not GateService.GetSpecification(g.Specification) then
            return false, ("Unknown specification '%s' for gate %s"):format(tostring(g.Specification), tostring(oldId))
        end
    end

    -- Prepare lists
    local idMap = {}        -- oldId -> newId
    local created = {}      -- list of newIds for rollback
    local createdSet = {}   -- set of newIds
    local oldIds = {}
    for oldId in pairs(saveTable.Gates) do table.insert(oldIds, oldId) end
    table.sort(oldIds) -- deterministic order for instantiation

    -- Calculate the base pivot point (position only, stripping any accidental base rotation)
    local basePivot = CFrame.new()
    if hasAnchor and saveTable.BaseCFrame then
        local basePosition = deserializeCFrame(saveTable.BaseCFrame).Position
        basePivot = CFrame.new(basePosition)
    end

    -- Instantiate in batches
    local function instantiateOne(oldId, entry)
        local gateCFrame = deserializeCFrame(entry.CFrame)
        local finalCFrame = gateCFrame
        
        if hasAnchor then
            -- 1. Get the gate's offset relative to the original save's base position
            local relativeOffset = basePivot:Inverse() * gateCFrame
            -- 2. Apply this offset to the new anchor (which preserves the client's rotation)
            finalCFrame = anchorCFrame * relativeOffset
        end

        local visuals = entry.Visuals or {}
        local attributes = entry.Attributes or {}
        local ok, newIdOrErr = pcall(function()
            return GateService.Instantiate(owner, entry.Specification, finalCFrame, visuals, attributes)
        end)
        
        if not ok then
            return false, tostring(newIdOrErr)
        end
        local newId = newIdOrErr
        if type(newId) ~= "number" then
            return false, ("Instantiate returned invalid id for oldId %s: %s"):format(tostring(oldId), tostring(newId))
        end
        idMap[oldId] = newId
        table.insert(created, newId)
        createdSet[newId] = true
        return true
    end

    local i = 1
    while i <= #oldIds do
        local batchEnd = math.min(i + batchSize - 1, #oldIds)
        for j = i, batchEnd do
            local oldId = oldIds[j]
            local entry = saveTable.Gates[oldId]
            local ok, err = instantiateOne(oldId, entry)
            if not ok then
                -- rollback
                for _, nid in ipairs(created) do
                    pcall(function()
                        Updates.CancelAllWakeups(nid)
                        GateService.Destroy(nid)
                    end)
                end
                return false, ("Instantiate failed for oldId %s: %s"):format(tostring(oldId), tostring(err))
            end
        end
        -- yield a frame to avoid long blocking; allow physics/replication to settle a bit
        task.wait(0)
        i = batchEnd + 1
    end

    -- Optional: restore runtime state (Deserialize) before connecting
    for oldId, entry in pairs(saveTable.Gates) do
        local newId = idMap[oldId]
        if newId then
            local inst = GateService.GetGateInstance(newId)
            if inst and type(entry.State) == "table" and type(inst.Deserialize) == "function" then
                local ok, err = pcall(function() inst:Deserialize(entry.State) end)
                if not ok then
                    -- rollback
                    for _, nid in ipairs(created) do
                        pcall(function()
                            Updates.CancelAllWakeups(nid)
                            GateService.Destroy(nid)
                        end)
                    end
                    return false, ("Deserialize failed for oldId %s: %s"):format(tostring(oldId), tostring(err))
                end
            end
        end
    end

    -- Wait a bit to ensure models are fully created and replication has settled
    task.wait(connectDelay)

    -- Filter connections to only those internal to the saved set
    local savedSet = {}
    for oldId in pairs(saveTable.Gates) do savedSet[oldId] = true end
    local filtered = {}
    for _, conn in ipairs(saveTable.Connections or {}) do
        if savedSet[conn.fromGate] and savedSet[conn.toGate] then
            table.insert(filtered, conn)
        end
    end

    -- Sort connections deterministically by timestamp then tie-breakers
    table.sort(filtered, function(a, b)
        if a.timestamp ~= b.timestamp then return a.timestamp < b.timestamp end
        if a.fromGate ~= b.fromGate then return a.fromGate < b.fromGate end
        if a.toGate ~= b.toGate then return a.toGate < b.toGate end
        if a.fromNode ~= b.fromNode then return tostring(a.fromNode) < tostring(b.fromNode) end
        return tostring(a.toNode) < tostring(b.toNode)
    end)

    -- Create connections in order
    for _, conn in ipairs(filtered) do
        local fromNew = idMap[conn.fromGate]
        local toNew = idMap[conn.toGate]
        if not fromNew or not toNew then
            -- Shouldn't happen due to filtering, but guard
            for _, nid in ipairs(created) do
                pcall(function()
                    Updates.CancelAllWakeups(nid)
                    GateService.Destroy(nid)
                end)
            end
            return false, ("Missing mapping for connection: %s -> %s"):format(tostring(conn.fromGate), tostring(conn.toGate))
        end

        local ok, err = pcall(function()
            GateService.Connect(fromNew, toNew, { from = conn.fromNode, to = conn.toNode })
        end)
        if not ok then
            -- rollback
            for _, nid in ipairs(created) do
                pcall(function()
                    Updates.CancelAllWakeups(nid)
                    GateService.Destroy(nid)
                end)
            end
            return false, ("Connect failed for %s:%s -> %s:%s : %s"):format(
                tostring(conn.fromGate), tostring(conn.fromNode), tostring(conn.toGate), tostring(conn.toNode), tostring(err))
        end
    end

    -- Finalize: allow propagation for created gates
    for _, nid in ipairs(created) do
        pcall(function() Updates.Propagate(nid) end)
    end

    return true, { idMap = idMap, created = created }
end

-- Utility: LoadFromSerializedString / SaveToSerializedString (optional helpers)
function SaveManager.Serialize(saveTable)
    -- simple JSON-like serialization using HttpService if available
    local HttpService = game:GetService("HttpService")
    return HttpService:JSONEncode(saveTable)
end

function SaveManager.Deserialize(serialized)
    local HttpService = game:GetService("HttpService")
    return HttpService:JSONDecode(serialized)
end

return SaveManager
