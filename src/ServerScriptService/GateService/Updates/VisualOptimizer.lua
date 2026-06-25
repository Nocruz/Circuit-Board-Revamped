-- VisualOptimizer.lua
local VisualOptimizer = {}

-- pending[instance] = propsTable
local pending = setmetatable({}, { __mode = "k" }) -- weak keys so instances can be GC'd

-- shallow copy helper
local local_copy = function(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

-- recursive merge: incoming overrides existing at leaf fields
local function mergeRecursive(existing, incoming)
    if type(incoming) ~= "table" then
        return incoming
    end
    if type(existing) ~= "table" then
        existing = {}
    end
    for k, v in pairs(incoming) do
        if type(v) == "table" then
            existing[k] = mergeRecursive(existing[k], v)
        else
            existing[k] = v
        end
    end
    return existing
end

-- Register an update for an instance. Last write wins per leaf.
function VisualOptimizer.Register(instance, props)
    if not instance or type(props) ~= "table" then return end
    local entry = pending[instance]
    if not entry then
        -- copy props to avoid accidental external mutation
        pending[instance] = local_copy(props)
        return
    end
    pending[instance] = mergeRecursive(entry, props)
end

function VisualOptimizer.GetPending()
    return pending
end

function VisualOptimizer.Clear()
    pending = setmetatable({}, { __mode = "k" })
end

-- Helper to apply a props table to an instance
local function applyPropsToInstance(instance, props)
    if not instance or type(props) ~= "table" then return end

    for key, value in pairs(props) do
        if type(value) == "table" then
            -- treat key as a child name; try to find child (search descendants)
            local child = instance:FindFirstChild(key, true)
            if child then
                applyPropsToInstance(child, value)
            else
                -- If no child found, it might be a nested property table (e.g., Decoration = { Main = { ... } })
                -- Try direct descendant by name first; if not found, skip silently
                -- This keeps behavior simple and predictable
            end
        else
            -- set property if it exists on the instance
            local success, err = pcall(function()
                instance[key] = value
            end)
            if not success then
                -- ignore invalid property sets to keep ApplyAll robust
            end
        end
    end
end

-- Apply all pending updates and clear them
function VisualOptimizer.ApplyAll()
    -- iterate a snapshot to avoid mutation issues during apply
    local snapshot = {}
    for inst, props in pairs(pending) do
        snapshot[inst] = props
    end

    -- apply each
    for inst, props in pairs(snapshot) do
        if inst and inst.Parent then
            applyPropsToInstance(inst, props)
        end
    end

    -- clear pending
    VisualOptimizer.Clear()
end

return VisualOptimizer
