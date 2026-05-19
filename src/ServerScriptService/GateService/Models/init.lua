--[[ MODELS
	Handles everything that is Model-related.
	
	=== CONCEPTS ===
	
	STYLE
		A plain Folder in the script tree.
		Children are ModelType ModuleScripts — only those that differ from Classic need to exist.
		An optional "Defaults" child ModuleScript provides style-level DefaultVisuals overrides.
	
	MODELTYPE (Handler protocol)
		A ModuleScript that returns a table implementing some or all of:
			Instantiate(nodes, resolvedType, styleName)  -> TGateModel (raw, no Tracks/State yet)
			UpdateVisuals(model, visuals)
			Trigger(model, action)                       -- dispatches to named event callbacks
			Destroy(model)
			ApplyLogicalState(model, state)              -- optional; used on style swaps
			DefaultVisuals: TVisuals                     -- optional; ModelType-level visual defaults
	
	HANDLER
		The resolved (Style, ModelType) pair. Not a class you instantiate —
		it is a read-through proxy over (StyleImpl → ClassicBase).
		Built by BuildHandler; stored in handlerCache.
	
	TGateModel
		The runtime record owned by a Gate. Carries the Roblox Instance,
		the resolved Style/Type names, an opaque LogicalState, and a TrackManager.
		Handlers read/write LogicalState so SwapStyle can restore it on the new model.
	
	TrackManager
		Attached to every TGateModel at Instantiate time.
		Animations are registered under named tracks. Starting a track that is
		already running cancels it first. Tracks that don't share a name are
		completely independent — only the relevant ones get cancelled when an
		event fires. Destroy always calls CancelAll before tearing down the Instance.
	
	TVisuals proxy (from ResolveVisuals)
		A lazily-evaluated proxy that walks the 5-layer resolution chain:
			Gate.Visuals -> Spec.DefaultVisuals -> Handler.DefaultVisuals
			-> Style.Defaults module -> GLOBAL_DEFAULTS
		Offset arrays are resolved to the correct count-indexed slice at this layer,
		so handlers never need to know about node counts.
	
	Trigger queue
		RegisterTrigger deduplicates by action.Source (last write wins per frame).
		ExecuteAllTriggers flushes the queue once per frame, after update logic.
		This prevents expensive operations (e.g. Display text updates) from firing
		more than once per frame no matter how many logic ticks ran.
		For animation events the deduplication is also correct: the most recent
		state wins, and LogicalState + ApplyLogicalState handle visual continuity.
	
	=== RELATIONSHIPS ===
	
		Models (service)
		  ├── StyleFolders  registry  [name: Folder]
		  ├── StyleIDs      registry  [id: name]       (for save/load)
		  ├── handlerCache             [cacheKey: {handler, typeName}]
		  ├── pendingTriggers          [TGateModel: {Source: action}]  (weak keys)
		  │
		  ├── BuildHandler(styleFolder, typeName) -> proxy(StyleImpl: ClassicBase)
		  ├── GetHandler(styleName, specTypes[])  -> (handler, resolvedTypeName)
		  │     pass 1: requested style, spec types in priority order
		  │     pass 2: Classic style, same type order
		  │     fallback: Classic.Basic
		  │
		  ├── ResolveVisuals(gateVisuals, specVisuals, handler, styleName, nodeCount)
		  │   	-> TVisuals proxy (5-layer chain)
		  │
		  └── MakeTrackManager() -> TTrackManager
		        Start(name, startFn)  — cancels existing track of that name first
		        Cancel(name)
		        CancelAll()           — called by Destroy and SwapStyle
		
		TGateModel
		  ├── Instance:     Model         (Roblox scene object)
		  ├── Style:        string        (resolved style name)
		  ├── Type:         string        (resolved modeltype name)
		  ├── Visuals:      table         (resolved visuals of the instance)
		  ├── LogicalState: table         (opaque; written by Trigger, read by ApplyLogicalState)
		  └── Tracks:       TTrackManager (composition)
]]

local Models = {}

-- ============================================================
-- TYPE DEFINITIONS
-- ============================================================

export type TStyleName = string
export type TModelType = string

export type TVisuals = {
	MainMaterial:  Enum.Material?,
	MainColor:     Color3?,
	DisplayName:   string?,
	InputOffsets:  { Vector2 }?,
	OutputOffsets: { Vector2 }?,
}

export type TNodeCount = {
	Input:  number,
	Output: number,
}

export type TTrackManager = {
	Start:     (name: string, startFn: () -> (() -> ())?) -> (),
	Cancel:    (name: string) -> (),
	CancelAll: () -> (),
}

export type TGateModel = {
	Instance:     Model,
	Style:        TStyleName,
	Type:         TModelType,
	Visuals:      TVisuals,
	LogicalState: { [string]: any },
	Tracks:       TTrackManager,
}

-- ============================================================
-- GLOBAL DEFAULTS
-- ============================================================
-- Last resort for every visual property.
-- Offset arrays are keyed by node count; ResolveVisuals selects the right slice.

local GLOBAL_DEFAULTS: TVisuals & { InputOffsets: { [number]: { Vector2 } }, OutputOffsets: { [number]: { Vector2 } } } = {
	MainMaterial = Enum.Material.Marble,
	MainColor    = Color3.new(1, 0.2, 0.7),
	DisplayName  = "ERROR",
	
	InputOffsets = {
		[1] = { Vector2.new( 0.00,  0.50) },
		[2] = { Vector2.new(-0.20,  0.50), Vector2.new( 0.20,  0.50) },
		[3] = { Vector2.new(-0.35,  0.50), Vector2.new( 0.00,  0.50), Vector2.new( 0.35,  0.50) },
		[4] = { Vector2.new(-0.35,  0.50), Vector2.new( 0.00,  0.50), Vector2.new( 0.35,  0.50), Vector2.new( 0.50,  0.00) },
		[5] = { Vector2.new(-0.35,  0.50), Vector2.new( 0.00,  0.50), Vector2.new( 0.35,  0.50), Vector2.new( 0.50,  0.20), Vector2.new( 0.50, -0.20) },
	},
	OutputOffsets = {
		[1] = { Vector2.new( 0.00, -0.50) },
		[2] = { Vector2.new(-0.20, -0.50), Vector2.new( 0.20, -0.50) },
		[3] = { Vector2.new(-0.35, -0.50), Vector2.new( 0.00, -0.50), Vector2.new( 0.35, -0.50) },
		[4] = { Vector2.new(-0.20, -0.50), Vector2.new( 0.20, -0.50), Vector2.new(-0.50,  0.20), Vector2.new(-0.50, -0.20) },
		[5] = { Vector2.new(-0.35, -0.50), Vector2.new( 0.00, -0.50), Vector2.new( 0.35, -0.50), Vector2.new(-0.50,  0.20), Vector2.new(-0.50, -0.20) },
	},
}

-- ============================================================
-- STYLE REGISTRY
-- ============================================================

local StyleFolders: { [TStyleName]: Folder } = {}
local StyleIDs: { [number]: TStyleName } = {}

function Models.RegisterStyle(name: TStyleName, id: number, folder: Folder)
	assert(StyleFolders[name] == nil, 'Style "' .. name .. '" is already registered.')
	assert(StyleIDs[id]       == nil, 'Style ID ' .. id .. ' is already in use.')
	StyleFolders[name] = folder
	StyleIDs[id]       = name
end

-- Reverse lookup for save/load: numeric ID → style name
function Models.GetStyleName(id: number): TStyleName?
	return StyleIDs[id]
end

-- ============================================================
-- HANDLER RESOLUTION
-- ============================================================

local handlerCache: { [string]: { handler: any, typeName: TModelType } } = {}

--[[
	BuildHandler
	Creates a read-through proxy: StyleImpl → ClassicBase.
	Neither module table is mutated (require cache stays clean).
	If the style folder has no child for typeName, ClassicBase is returned directly.
]]
local function BuildHandler(styleFolder: Folder, typeName: TModelType): any
	local classicFolder = StyleFolders["Classic"]
	local classicModule = classicFolder and classicFolder:FindFirstChild(typeName)
	local classicBase   = classicModule and require(classicModule)
	
	local styleModule = styleFolder:FindFirstChild(typeName)
	if not styleModule then
		-- Style has no override for this type; use Classic directly.
		return classicBase
	end
	
	local impl = require(styleModule)
	if not classicBase or impl == classicBase then
		return impl
	end
	
	-- Proxy: impl fields take priority; Classic fills in anything not overridden.
	-- This means a Prism.Activator only needs to define what it changes.
	return setmetatable({}, {
		__index = function(_, k)
			local v = rawget(impl, k)
			if v ~= nil then return v end
			return classicBase[k]
		end
	})
end

--[[
	GetHandler
	Resolves a (styleName, specTypes) pair to a (handler, resolvedTypeName).
	
	specTypes is the Specification's ordered ModelType priority list, e.g.:
		{ "Display", "Basic" }
	- meaning: use Display if this style implements it, else fall back to Basic.
	
	Resolution passes:
		1. Requested style   — first specType the folder has a child for
		2. Classic style     — same search (if requested style was missing or had none)
		3. fallback  — Classic.Basic
	
	Result is cached by "styleName:typeA,typeB" key.
]]
local function GetHandler(styleName: TStyleName, specTypes: { TModelType }): (any, TModelType)
	local cacheKey = styleName .. ":" .. table.concat(specTypes, ",")
	if handlerCache[cacheKey] then
		local cached = handlerCache[cacheKey]
		return cached.handler, cached.typeName
	end
	
	local requestedFolder = StyleFolders[styleName]
	if not requestedFolder then
		warn('Models: Style "' .. styleName .. '" is not registered. Falling back to Classic.')
	end
	
	-- Two passes: requested style first, then Classic as fallback.
	for pass = 1, 2 do
		local folder = (pass == 1) and requestedFolder or StyleFolders["Classic"]
		if not folder then continue end
		
		for _, typeName in ipairs(specTypes) do
			if folder:FindFirstChild(typeName) then
				local handler = BuildHandler(folder, typeName)
				handlerCache[cacheKey] = { handler = handler, typeName = typeName }
				return handler, typeName
			end
		end
		
		if pass == 1 and requestedFolder then
			warn('Models: Style "' .. styleName .. '" implements none of ['
				.. table.concat(specTypes, ", ") .. "]. Falling back to Classic.")
		end
	end
	
	-- Fallback: Classic.Basic must always exist.
	warn("Models: All fallbacks exhausted. Using Classic.Basic.")
	local handler = BuildHandler(StyleFolders["Classic"], "Basic")
	handlerCache[cacheKey] = { handler = handler, typeName = "Basic" }
	return handler, "Basic"
end

-- ============================================================
-- VISUALS RESOLUTION
-- ============================================================

--[[
	ResolveVisuals
	Returns a proxy table that lazily walks the 5-layer visual chain.
	Callers index it like a plain table; missing keys fall through automatically.
	
	Chain (first non-nil wins):
		1. gateVisuals        — Gate.Visuals (player overrides)
		2. specVisuals        — Specification.DefaultVisuals
		3. handlerDefaults    — Handler.DefaultVisuals (the ModelType module's table)
		4. styleDefaults      — Style folder's optional "Defaults" child module
		5. GLOBAL_DEFAULTS    — final fallback; offset arrays resolved by nodeCount here
	
	Offset arrays are resolved to the correct count-indexed slice at this layer.
	Handlers always receive { Vector2, ... }, never a { [count]: { Vector2 } } table.
]]
function Models.ResolveVisuals(
	gateVisuals:  TVisuals?,
	specVisuals:  TVisuals?,
	handler:      any,
	styleName:    TStyleName,
	nodeCount:    TNodeCount
) -- TVisuals & @metatable
	local styleFolder   = StyleFolders[styleName]
	local styleDefaults = nil
	if styleFolder then
		local m = styleFolder:FindFirstChild("Defaults")
		if m then styleDefaults = require(m) end
	end
	
	local handlerDefaults = rawget(handler, "DefaultVisuals")
	
	return setmetatable({}, {
		__index = function(_, key)
			local result = GLOBAL_DEFAULTS[key];
			if styleDefaults   and styleDefaults[key]   ~= nil then result = styleDefaults[key]   end
			if handlerDefaults and handlerDefaults[key] ~= nil then result = handlerDefaults[key] end
			if specVisuals     and specVisuals[key]     ~= nil then result = specVisuals[key]     end
			if gateVisuals     and gateVisuals[key]     ~= nil then result = gateVisuals[key]     end

			if key == "InputOffsets" then return result[nodeCount.Input] end
			if key == "OutputOffsets" then return result[nodeCount.Output] end
			return result
		end
	})
end

-- ============================================================
-- TRACK MANAGER
-- ============================================================

--[[
	MakeTrackManager
	Creates a per-model animation track registry.
	
	Each track is identified by a name string. Handlers register tracks in their
	event callbacks (OnInstantiate, OnConnect, etc.). A track's startFn should
	return a cancelFn, or nil if the animation is fire-and-forget.
	
	Animation independence: only tracks with a shared name interfere.
	If OnInstantiate starts "emerge" and "gears", and OnConnect only starts "gears",
	then Connecting mid-animation cancels "gears" and retriggers it — but "emerge"
	keeps playing untouched.
]]
local function MakeTrackManager(): TTrackManager
	local active = {}  -- [trackName]: cancelFn
	
	local manager = {}
	
	function manager.Start(name: string, startFn: () -> (() -> ())?)
		-- Cancel the existing track of this name first, if any.
		if active[name] then
			pcall(active[name])
			active[name] = nil
		end
		local cancelFn = startFn()
		if cancelFn then
			active[name] = cancelFn
		end
	end
	
	function manager.Cancel(name: string)
		if active[name] then
			pcall(active[name])
			active[name] = nil
		end
	end
	
	-- Called before destroying the Instance. pcall guards against partially
	-- destroyed objects inside the cancel callbacks.
	function manager.CancelAll()
		for _, fn in pairs(active) do pcall(fn) end
		table.clear(active)
	end
	
	return manager
end

-- ============================================================
-- TRIGGER QUEUE
-- ============================================================

--[[
	Triggers are deduplicated by action.Source (last write wins per frame).
	This is intentional for two reasons:
		- Value events (Signal, Text, Light): only the final state matters.
		- Animation events (Instantiate, Connect, Destroy): the most recent
		  event determines the target state; LogicalState + ApplyLogicalState
		  restore visual continuity on the new model.
	
	The queue is flushed once per frame by ExecuteAllTriggers, which is called
	by the Updates system after all logic ticks for that frame have run.
	
	The weak key metatable lets TGateModel tables be GC'd without leaks if a
	gate is destroyed before its triggers are flushed.
]]
local pendingTriggers = {}
setmetatable(pendingTriggers, { __mode = "k" })

function Models.RegisterTrigger(model: TGateModel, action: { Source: string, [string]: any })
	if pendingTriggers[model] == nil then pendingTriggers[model] = {} end
	pendingTriggers[model][action.Source] = action
end

function Models.ExecuteAllTriggers()
	for model, entries in pairs(pendingTriggers) do
		-- Use the stored type name for lookup; no Specification context needed here.
		local handler = GetHandler(model.Style, { model.Type })
		
		for _, action in pairs(entries) do
			if handler.Trigger then
				handler.Trigger(model, action)
			end
		end
		
		pendingTriggers[model] = nil
	end
end

-- ============================================================
-- PUBLIC API
-- ============================================================

--[[
	Models.Instantiate
	Creates a TGateModel for the given Specification, style, and resolved visuals.
	Attaches a fresh TrackManager and an empty LogicalState table.
	
	@param specTypes   Ordered ModelType priority list from the Specification.
	@param nodes       { Inputs: { string }, Outputs: { string } }
	@param styleName   Requested style name.
	@param visuals     TVisuals proxy from Models.ResolveVisuals.
	@return            Fully initialized TGateModel.
]]
function Models.Instantiate(
	specTypes:   { TModelType },
	nodes:       { Inputs: { string }, Outputs: { string } },
	styleName:   TStyleName,
	visuals:     TVisuals,
	specVisuals: TVisuals
): TGateModel
	local handler, resolvedType = GetHandler(styleName, specTypes)
	local solvedVisuals = Models.ResolveVisuals(
		visuals,
		specVisuals,
		handler,
		styleName,
		{Input = #nodes.Inputs, Output = #nodes.Outputs}
	)
	
	-- Handler.Instantiate builds the raw model table and Roblox Instance.
	-- It does NOT touch LogicalState or Tracks — that is this layer's job.
	local model: TGateModel = handler.Instantiate(nodes, resolvedType, styleName)
	model.Style        = styleName
	model.Type         = resolvedType
	model.Visuals      = visuals
	model.LogicalState = model.LogicalState or {}
	model.Tracks       = MakeTrackManager()
	
	handler.UpdateVisuals(model, solvedVisuals)
	
	return model
end

--[[
	Models.Destroy
	Cancels all active animation tracks, then delegates to the handler.
	Always cancel tracks before touching the Instance — cancel callbacks
	may reference parts of it.
]]
function Models.Destroy(model: TGateModel)
	model.Tracks.CancelAll()
	
	local handler = GetHandler(model.Style, { model.Type })
	handler.Destroy(model)
	-- Note: handler.Destroy should table.clear(model) but NOT set model = nil.
	-- That only nils the local; callers are responsible for clearing their reference.
end

--[[
	Models.SwapStyle
	Replaces a gate's model Style while preserving its LogicalState.
	
	The gate table must expose:
		gate.Model                        (current TGateModel)
		gate.Specification.ModelTypes     ({ TModelType })
		gate.Specification.DefaultVisuals (TVisuals?)
		gate.Visuals                      (TVisuals?)
		gate.NodeCount                    (TNodeCount)
		gate.Specification.Nodes          ({ Inputs, Outputs })
	
	Visual continuity:
		After Instantiate + UpdateVisuals the new model is in its default visual
		state. ApplyLogicalState (if the handler defines it) then snaps it to the
		saved LogicalState without playing transition animations.
]]
function Models.SwapStyle(gate, newStyleName: TStyleName)
	local function copyAttributes(attributes: any, b: Instance)
		for name, value in pairs(attributes) do
			b:SetAttribute(name, value)
		end
	end
	
	local oldModel   = gate.Model
	local specTypes  = gate.Specification.ModelTypes
	local savedState = oldModel.LogicalState  -- snapshot before destruction
	
	-- Destroy old model. CancelAll is called inside Destroy.
	local oldName = oldModel.Instance.Name
	local oldParent = oldModel.Instance.Parent
	local oldCFrame = oldModel.Instance:GetPivot()
	local oldAttributes = oldModel.Instance:GetAttributes()
	Models.Destroy(oldModel)
	
	-- Resolve and build the new model.
	local newHandler, resolvedType = GetHandler(newStyleName, specTypes)
	local visuals = Models.ResolveVisuals(
		gate.Visuals,
		gate.Specification.DefaultVisuals,
		newHandler,
		newStyleName,
		gate.NodeCount
	)
	
	local newModel: TGateModel = newHandler.Instantiate(gate.Specification.Nodes, resolvedType, newStyleName)
	newModel.Style        = newStyleName
	newModel.Type         = resolvedType
	newModel.LogicalState = savedState
	newModel.Tracks       = MakeTrackManager()
	
	newHandler.UpdateVisuals(newModel, visuals)
	
	-- Restore logical state without animations.
	if newHandler.ApplyLogicalState then
		newHandler.ApplyLogicalState(newModel, savedState)
	end

	-- Replace instance properties
	newModel.Instance.Name = oldName
	newModel.Instance:PivotTo(oldCFrame)
	copyAttributes(oldAttributes, newModel.Instance)
	newModel.Instance.Parent = oldParent
	
	return newModel
end

-- ============================================================
-- STYLE REGISTRATION
-- ============================================================

Models.RegisterStyle("Classic", 1, script.Classic)
Models.RegisterStyle("Modern",  2, script.Modern)

-- ============================================================

return Models
