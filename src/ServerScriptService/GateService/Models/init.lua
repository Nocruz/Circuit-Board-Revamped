--[[ MODELS
		Controller that exposes a way of instantiating models.
]]

-- References and Services
local ServerStorage = game:GetService("ServerStorage")

local GATE_PREFABS: Folder = ServerStorage.Models.Prefabs
local NODE_PREFAB: BasePart = ServerStorage.Models.Node

-- Constants
local NODE_ROTATIONS = {
	front = CFrame.Angles(0, 0, 0),
	back  = CFrame.Angles(0, math.rad(180), 0),
	left  = CFrame.Angles(0, math.rad(90), 0),
	right = CFrame.Angles(0, math.rad(270), 0)
}
local NODE_OFFSET = function(base: BasePart)
	return CFrame.new(0, base.Size.Y + NODE_PREFAB.Size.Y / 2, NODE_PREFAB.Size.Z / 2)
end

-- ----------------------------- ----------- MODULE DEFINITION ----------- -----------------------------

local Models = { }

-- ----------------------------- ----------- HELPER FUNCTIONS ------------ -----------------------------

local function CloneGateModel(prefab: any): Model & { Main: BasePart , Nodes: Folder & { Inputs: Folder, Outputs: Folder }, Base: BasePart } return prefab:Clone() end

local function SnapToEdge(coordinate: Vector2): (Vector2, string)
	if math.abs(coordinate.X) > math.abs(coordinate.Y) then
		if coordinate.X < 0 then return Vector2.new(-0.5, coordinate.Y), "left"
		else return Vector2.new( 0.5, coordinate.Y), "right" end
	else
		if coordinate.Y < 0 then return Vector2.new(coordinate.X, -0.5), "front"
		else return Vector2.new(coordinate.X,  0.5), "back" end
	end
end

-- ----------------------------- ---------------- VISUALS ---------------- -----------------------------

type Visuals = {
	MainMaterial: Enum.Material,
	DisplayName:  string?,
	PrefabName:   string,
	MainColor:    Color3,
	
	OutputOffsets: { Vector2 },
	InputOffsets:  { Vector2 }
}

local visualDefaultConfigurations = {
	MainColor = Color3.new(1, 0.2, 0.7),
	MainMaterial = Enum.Material.Concrete,
	PrefabName = "Basic",
	DisplayName = "",
}

local visualDefaultInputOffsets = {
	[0] = {},
	[1] = { Vector2.new(0.00, 0.50) },
	[2] = { Vector2.new(-0.20, 0.50), Vector2.new(0.20, 0.50) },
	[3] = { Vector2.new(-0.27, 0.50), Vector2.new(0.00, 0.50), Vector2.new(0.27, 0.50) },
	[4] = { Vector2.new(-0.27, 0.50), Vector2.new(0.00, 0.50), Vector2.new(0.27, 0.50), Vector2.new(0.50, 0.00) },
	[5] = { Vector2.new(-0.27, 0.50), Vector2.new(0.00, 0.50), Vector2.new(0.27, 0.50), Vector2.new(0.50, 0.25), Vector2.new(0.50, -0.15) },
}

local visualDefaultOutputOffsets = {
	[0] = {},
	[1] = { Vector2.new(0.00, -0.50) },
	[2] = { Vector2.new(-0.20, -0.50), Vector2.new(0.20, -0.50) },
	[3] = { Vector2.new(-0.27, -0.50), Vector2.new(0.00, -0.50), Vector2.new(0.27, -0.50) },
	[4] = { Vector2.new(-0.50, -0.35), Vector2.new(-0.20, -0.50), Vector2.new(0.20, -0.50), Vector2.new(0.50, -0.35) },
	[5] = { Vector2.new(-0.50, -0.35), Vector2.new(-0.27, -0.50), Vector2.new(0.00, -0.50), Vector2.new(0.27, -0.50), Vector2.new(0.50, -0.35) },
}

-- Builds a specific table with a custom __index function in metatable
-- that points to the correct node offset.
function Models.GetSpecificationVisualsTable(table, name, inputCount, outputCount)
	local data = {} do
		data.MainMaterial = table.MainMaterial or visualDefaultConfigurations.MainMaterial
		data.DisplayName = table.DisplayName or name
		data.PrefabName = table.PrefabName or visualDefaultConfigurations.PrefabName
		data.MainColor = table.MainColor or visualDefaultConfigurations.MainColor
	end
	
	return setmetatable(data, { __index = function(table, key)
		if (key == "InputOffsets") then return visualDefaultInputOffsets[inputCount] end
		if (key == "OutputOffsets") then return visualDefaultOutputOffsets[outputCount] end
		return nil
	end })
end

-- ----------------------------- ------------- INSTANTIATION ------------- -----------------------------

function Models.new(nodes: { Outputs: { string }, Inputs: { string } }, visuals): Model
	local prefab = GATE_PREFABS:FindFirstChild(visuals.PrefabName)
	assert(prefab and prefab:IsA("Model"), "ERROR: Couldn't find a valid prefab of name \"" .. visuals.PrefabName or "<NIL VALUE>" .. "\".")
	
	local gateModel = CloneGateModel(prefab) do
		-- Basic decorations, such as color and material
		gateModel.Main.Color = visuals.MainColor
		gateModel.Main.Material = visuals.MainMaterial
		
		local nameDisplay = gateModel:FindFirstChild("DisplayNameGui", true)
		if nameDisplay then nameDisplay:FindFirstChildWhichIsA("TextLabel").Text = visuals.DisplayName end
	end
	
	-- Instantiate all nodes.
	for index, name in ipairs(nodes.Inputs) do
		local node = NODE_PREFAB:Clone() do
			node.Name = name
			node.Material = Enum.Material.Plastic
			node.Color = Color3.new(0.5, 0.5, 0.5)
			node:SetAttribute("NodeType", "Input")
			node:SetAttribute("NodeIndex", index)
			
			node.NodeName.TextLabel.Text = name
			node.NodeName.TextLabel.TextColor3 = Color3.new(0.1, 0.4, 0.8)
			node.Parent = gateModel.Nodes.Inputs
		end
	end
	
	for index, name in ipairs(nodes.Outputs) do
		local node = NODE_PREFAB:Clone() do
			node.Name = name
			node.Material = Enum.Material.SmoothPlastic
			node.Color = Color3.new(1, 1, 1)
			node:SetAttribute("NodeType", "Output")
			node:SetAttribute("NodeIndex", index)
			
			node.NodeName.TextLabel.Text = name
			node.NodeName.TextLabel.TextColor3 = Color3.new(0.8, 0.1, 0.15)
			node.Parent = gateModel.Nodes.Outputs
		end
	end
	
	-- Set nodes CFrame
	local activeEdge = { front = false, back = false, left = false, right = false }
	for _, node in ipairs(gateModel.Nodes.Inputs:GetChildren()) do
		local index = node:GetAttribute("NodeIndex")
		
		local offset, edge = SnapToEdge(visuals.InputOffsets[index])
		activeEdge[edge] = true
		
		local transform = CFrame.new(offset.X * gateModel.Base.Size.X, 0, offset.Y * gateModel.Base.Size.Z)
		node.CFrame = gateModel:GetPivot() * transform * NODE_ROTATIONS[edge] * NODE_OFFSET(gateModel.Base)
	end
	
	for _, node in ipairs(gateModel.Nodes.Outputs:GetChildren()) do
		local index = node:GetAttribute("NodeIndex")
		
		local offset, edge = SnapToEdge(visuals.OutputOffsets[index])
		activeEdge[edge] = true
		
		local transform = CFrame.new(offset.X * gateModel.Base.Size.X, 0, offset.Y * gateModel.Base.Size.Z)
		node.CFrame = gateModel:GetPivot() * transform * NODE_ROTATIONS[edge] * NODE_OFFSET(gateModel.Base)
	end
	
	-- Resize Main
	local shrinkVector = Vector2.new(math.max(0, NODE_PREFAB.Size.Z - (gateModel.Base.Size.X - gateModel.Main.Size.X) / 2), math.max(0, NODE_PREFAB.Size.Z - (gateModel.Base.Size.Z - gateModel.Main.Size.Z) / 2))
	local shrinkL = if activeEdge.left then shrinkVector.X else 0
	local shrinkR = if activeEdge.right then shrinkVector.X else 0
	local shrinkF = if activeEdge.front then shrinkVector.Y else 0
	local shrinkB = if activeEdge.back then shrinkVector.Y else 0
	
	gateModel.Main.Size = Vector3.new(math.max(0, gateModel.Main.Size.X - (shrinkL + shrinkR)), gateModel.Main.Size.Y, math.max(0, gateModel.Main.Size.Z - (shrinkF + shrinkB)))
	
	-- Offset Main
	local offsetX = (shrinkL - shrinkR) / 2
	local offsetZ = (shrinkF - shrinkB) / 2
	
	gateModel.Main.CFrame = gateModel:GetPivot() * CFrame.new(offsetX, gateModel.Base.Size.Y + gateModel.Main.Size.Y / 2, offsetZ)
	
	-- Return the model
	return gateModel
end

-- ----------------------------- ------------- END OF MODULE ------------- -----------------------------

return Models
