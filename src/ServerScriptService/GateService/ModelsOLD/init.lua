--[[ MODELS
		Handles everything that is Model related.
		Every Gate instance must have a Model.
		The Model can be of different Styles (Skins in other games), and be of
			diferent ModelTypes (BUTTON has a different Prefab than an AND gate, but both are still GateModels).
		Each Style must implement its own version of all ModelTypes.
		Each Style also handles special interactions per ModelType
		
		Styles are ModuleScripts with all the ModelType prefabs as children.
		Styles follow the guidelines defined in this ModuleScript.
		
		This script handles Style registration. While implementing new ModelTypes will be a pain,
			this should make it easy to implement new Styles by just adding children to this module.
		
		It also is a rerouter for more programmer friendly access to the Styles implementations.
]]

local Models = {}

-- ----------------------------- ----------- TYPE DEFINITIONS ------------ -----------------------------

export type TStyleType = "Classic" | "Prism"
export type TModelType = "Basic" | "Activator" | "Display" | "Light"

export type TVisuals = {
	MainMaterial: Enum.Material,
	MainColor:    Color3,
	DisplayName:  string,
	
	OutputOffsets: { Vector2 },
	InputOffsets:  { Vector2 }
}

export type TGateModel = {
	-- Attributes stored in the model instance
	Instance: Model & { Decorations: Folder, Nodes: Folder },
	Style: TStyleType,
	Type: TModelType,
	
	State: any,
}

-- -----------------------------------------------------------------------------------------------------

local Defaults = {
	MainMaterial = Enum.Material.Concrete,
	MainColor = Color3.new(1, 0.2, 0.7),
	DisplayName = "ERROR",
	
	InputOffsets = {
		{ Vector2.new( 0.00,  0.50) },
		{ Vector2.new(-0.20,  0.50), Vector2.new( 0.20,  0.50) },
		{ Vector2.new(-0.27,  0.50), Vector2.new( 0.00,  0.50), Vector2.new( 0.27,  0.50) },
		{ Vector2.new(-0.27,  0.50), Vector2.new( 0.00,  0.50), Vector2.new( 0.27,  0.50), Vector2.new( 0.50,  0.00) },
		{ Vector2.new(-0.27,  0.50), Vector2.new( 0.00,  0.50), Vector2.new( 0.27,  0.50), Vector2.new( 0.50,  0.20), Vector2.new( 0.50, -0.20) }
	},
	OutputOffsets = {
		{ Vector2.new( 0.00, -0.50) },
		{ Vector2.new(-0.20, -0.50), Vector2.new( 0.20, -0.50) },
		{ Vector2.new(-0.27, -0.50), Vector2.new( 0.00, -0.50), Vector2.new( 0.27, -0.50) },
		{ Vector2.new(-0.20, -0.50), Vector2.new( 0.20, -0.50), Vector2.new(-0.50,  0.20), Vector2.new(-0.50, -0.20) },
		{ Vector2.new(-0.27, -0.50), Vector2.new( 0.00, -0.50), Vector2.new( 0.27, -0.50), Vector2.new(-0.50,  0.20), Vector2.new(-0.50, -0.20) }
	}
}

-- -----------------------------------------------------------------------------------------------------

-- Styles is a Dictionary of key "TStyleType" and as values required ModuleScripts. These ModuleScripts implement all the Style methods, and the "Classic" Style is a child of this ModuleScript
-- StylesMap is the same as Styles but in array form.

local Styles = {}
local StylesMap = {}

local handlerCache = {} -- { [StyleName]: { [TypeName]: require(Style) } }

local function GetStyle(styleName: TStyleType)
	local style = Styles[styleName]
	if style == nil then
		warn("Style \"" .. styleName .. "\" has not been registered. Using \"Classic\" instead.")
		style = Styles["Classic"]
	end
	return require(style)
end

local function GetHandler(styleName: TStyleType, typeName: TModelType)
	if handlerCache[styleName] and handlerCache[styleName][typeName] then
		return handlerCache[styleName][typeName]
	end
	
	local requestedStyle = Styles[styleName]
	local style = requestedStyle
	if style == nil then
		warn("Style \"" .. styleName .. "\" has not been registered. Using \"Classic\" instead.")
		style = Styles["Classic"]
	end
	
	local requestedTypeModule = style:FindFirstChild(typeName)
	local typeModule = requestedTypeModule
	if typeModule == nil then
		warn("Style \"" .. styleName .. "\" has no implementation of type \"" .. typeName .. "\". Using \"Basic\" instead.")
		typeModule = style.Basic
	end
	
	if requestedStyle ~= nil and requestedTypeModule ~= nil then
		handlerCache[styleName] = handlerCache[styleName] or {}
		handlerCache[styleName][typeName] = require(typeModule)
	end
	
	return require(typeModule)
end

function Models.RegisterStyle(name: TStyleType, id: number, style)
	assert(StylesMap[id] == nil, "Can't register style \"" .. name .. "\" with ID " .. id .. ". Reason: Style with that ID has already been registered.")
	assert(Styles[name] == nil,  "Can't register style \"" .. name .. "\", Reason: Style with that name has already been registered.")
	Styles[name] = style
	StylesMap[id] = style
end

function Models.GetStyleDefaults(styleName, nodeAmount)
	local style = GetStyle(styleName)
	
	local styleOverrides = {}
	if style.DefaultVisuals then
		local v = style.DefaultVisuals
		styleOverrides.MainMaterial = v.MainMaterial
		styleOverrides.MainColor = v.MainColor
		styleOverrides.DisplayName = v.DisplayName
		
		styleOverrides.InputOffsets = v.InputOffsets and v.InputOffsets[nodeAmount.Input]
		styleOverrides.OutputOffsets = v.OutputOffsets and v.OutputOffsets[nodeAmount.Output]
	end
	
	setmetatable(styleOverrides, { __index = function(_, key)
		if key == "InputOffsets" then return Defaults.InputOffsets[nodeAmount.Input]
		elseif key == "OutputOffsets" then return Defaults.OutputOffsets[nodeAmount.Output]
		else return Defaults[key] end
	end})	
	
	return styleOverrides
end

-- Register ID will be ModuleScript name
Models.RegisterStyle("Classic", 1, script.Classic)
Models.RegisterStyle("Prism", 2, script.Prism)

-- -----------------------------------------------------------------------------------------------------

local pendingTriggers = {} -- [Model]: { [Source]: { Source: string, Payload: any } }
setmetatable(pendingTriggers, { __mode = "k" })

function Models.RegisterTrigger(model: TGateModel, action: { Source: string, [string]: any })
	if pendingTriggers[model] == nil then pendingTriggers[model] = {} end
	pendingTriggers[model][action.Source] = action
end

function Models.ExecuteAllTriggers()
	for model, entries in pairs(pendingTriggers) do
		local handler = GetHandler(model.Style, model.Type)
		
		for source, action in pairs(entries) do
			handler.Trigger(model, action)
		end
		pendingTriggers[model] = nil
	end
end

-- -----------------------------------------------------------------------------------------------------

function Models.Instantiate(typeName: TModelType, nodes: { Inputs: { string }, Outputs: { string } }, styleName: TStyleType, visuals: TVisuals)
	local handler = GetHandler(styleName, typeName)
	
	local model = handler.Instantiate(nodes)
	handler.UpdateVisuals(model, visuals)
	
	return model
end

function Models.Destroy(model: TGateModel)
	local handler = GetHandler(model.Style, model.Type)
	
	handler.Destroy(model)
end

function Models.Trigger(model: TGateModel, payload)
	local handler = GetHandler(model.Style, model.Type)
	
	handler.Trigger(model, payload)
end

-- ----------------------------- ------------ END OF MODULE -------------- -----------------------------

return Models
