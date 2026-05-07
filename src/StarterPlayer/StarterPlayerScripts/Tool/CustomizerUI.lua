--!strict
local StarterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

type TNodeKind = "Input" | "Output"
type TGateId = string | number

type TVisualContext = {
	SpecificationName: string,
	HasDisplayName: boolean,
	InputNodes: { string },
	OutputNodes: { string },
	Visuals: {
		DisplayName: string,
		PrefabName: string,
		MainColor: Color3,
		InputOffsets: { Vector2 },
		OutputOffsets: { Vector2 },
	},
}

type TPreviewNode = {
	Name: string,
	Kind: TNodeKind,
	Index: number,
	Part: BasePart,
	Handle: Frame,
}

type TPreviewState = {
	Viewport: ViewportFrame,
	Overlay: Frame,
	WorldModel: WorldModel,
	Camera: Camera,
	Model: Model,
	BasePart: BasePart,
	MainPart: BasePart,
	DisplayLabel: TextLabel?,
	DisplayBadge: TextLabel?,
	Nodes: { TPreviewNode },
	Rotation: number,
}

type TDragState = {
	Mode: "Idle" | "Armed" | "Dragging",
	Node: TPreviewNode?,
	StartMouse: Vector2?,
}

local GateVisualRules = require(ReplicatedStorage.Services.GateVisualRules)
local ApplyVisualsEvent = ReplicatedStorage.Client.Events:WaitForChild("ApplyVisuals") :: RemoteFunction
local MessageService = require(StarterPlayerScripts.Services.MessageService)

local CustomizerUI = {}

local activeGui: ScreenGui?
local currentGateId: TGateId?
local visualDraft: any
local previewState: TPreviewState?
local previewConnection: RBXScriptConnection?
local dragBeganConnection: RBXScriptConnection?
local dragMovedConnection: RBXScriptConnection?
local dragEndedConnection: RBXScriptConnection?
local dragState: TDragState = { Mode = "Idle", Node = nil, StartMouse = nil }
local statusLabel: TextLabel?
local applyButton: TextButton?
local colorSwatch: Frame?
local applyBusy = false
local DRAG_START_DISTANCE = 6
local NODE_HANDLE_PICK_RADIUS = 34

local COLORS = {
	Bg = Color3.fromRGB(22, 24, 30),
	Panel = Color3.fromRGB(31, 35, 44),
	PanelAlt = Color3.fromRGB(39, 45, 56),
	Input = Color3.fromRGB(18, 22, 29),
	Text = Color3.fromRGB(237, 241, 248),
	Muted = Color3.fromRGB(164, 174, 191),
	Accent = Color3.fromRGB(99, 195, 255),
	AccentDark = Color3.fromRGB(33, 90, 122),
	Error = Color3.fromRGB(255, 112, 112),
	Disabled = Color3.fromRGB(86, 94, 108),
	InputNode = Color3.fromRGB(69, 133, 255),
	OutputNode = Color3.fromRGB(255, 91, 76),
}

local ROTATION_FOR_EDGE = {
	front = CFrame.Angles(0, 0, 0),
	back = CFrame.Angles(0, math.rad(180), 0),
	left = CFrame.Angles(0, math.rad(90), 0),
	right = CFrame.Angles(0, math.rad(270), 0),
}

local function create<T>(className: string, props: { [string]: any }, children: { Instance }?): T
	local instance = Instance.new(className)
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	return instance :: any
end

local function deepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = deepClone(nestedValue)
	end

	return clone
end

local function setStatus(text: string, isError: boolean?)
	if not statusLabel then
		return
	end

	statusLabel.Text = text
	statusLabel.TextColor3 = if isError then COLORS.Error else COLORS.Muted
end

local function setApplyBusy(isBusy: boolean)
	applyBusy = isBusy
	if not applyButton then
		return
	end

	applyButton.AutoButtonColor = not isBusy
	applyButton.BackgroundColor3 = if isBusy then COLORS.AccentDark else COLORS.Accent
	applyButton.TextColor3 = if isBusy then COLORS.Muted else Color3.fromRGB(11, 19, 26)
	applyButton.Text = if isBusy then "Applying..." else "Apply"
end

local function getAsPart(object: BasePart | Model): BasePart
	if object:IsA("BasePart") then
		return object
	end

	assert(object.PrimaryPart, "Model did not have a PrimaryPart set")
	return object.PrimaryPart
end

local function findGateModelById(id: TGateId): Model?
	local gatesFolder = Workspace:FindFirstChild("Gates")
	if not gatesFolder then
		return nil
	end

	for _, instance in ipairs(gatesFolder:GetDescendants()) do
		if instance:IsA("Model") and instance:GetAttribute("GateId") == id then
			return instance
		end
	end

	return nil
end

local function edgeFromOffset(offset: Vector2): "front" | "back" | "left" | "right"
	local function almostEqual(a: number, b: number): boolean
		return math.abs(a - b) < 1e-9
	end

	if almostEqual(offset.Y, -0.5) then
		return "front"
	elseif almostEqual(offset.Y, 0.5) then
		return "back"
	elseif almostEqual(offset.X, -0.5) then
		return "left"
	end

	return "right"
end

local function getNodeOffsets(kind: TNodeKind): { Vector2 }
	if kind == "Input" then
		return visualDraft.InputOffsets
	end
	return visualDraft.OutputOffsets
end

local function setNodeOffset(kind: TNodeKind, index: number, offset: Vector2)
	if kind == "Input" then
		visualDraft.InputOffsets[index] = offset
	else
		visualDraft.OutputOffsets[index] = offset
	end
end

local function updateDisplayNamePreview()
	if previewState ~= nil then
		if previewState.DisplayLabel ~= nil then
			previewState.DisplayLabel.Text = visualDraft.DisplayName
		end

		if previewState.DisplayBadge ~= nil then
			local text = visualDraft.DisplayName
			previewState.DisplayBadge.Text = if text ~= "" then text else " "
			previewState.DisplayBadge.Visible = text ~= ""
		end
	end
end

local function updateMainColorPreview()
	if previewState ~= nil then
		previewState.MainPart.Color = visualDraft.MainColor
	end

	if colorSwatch ~= nil then
		colorSwatch.BackgroundColor3 = visualDraft.MainColor
	end
end

local function positionPreviewNode(node: TPreviewNode)
	if previewState == nil then
		return
	end

	local offset = getNodeOffsets(node.Kind)[node.Index]
	local edge = edgeFromOffset(offset)
	local transformedOffset = CFrame.new(Vector3.new(offset.X * previewState.BasePart.Size.X, 0, offset.Y * previewState.BasePart.Size.Z))
	local nodeDepthOffset = CFrame.new(
		0,
		(node.Part.Size.Y + previewState.BasePart.Size.Y) / 2,
		node.Part.Size.Z / 2
	)

	node.Part.CFrame = previewState.BasePart.CFrame * transformedOffset * ROTATION_FOR_EDGE[edge] * nodeDepthOffset
end

local function updatePreviewNodes()
	if previewState == nil then
		return
	end

	for _, node in ipairs(previewState.Nodes) do
		positionPreviewNode(node)
	end
end

local function refreshCamera()
	if previewState == nil then
		return
	end

	local _, size = previewState.Model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z, 4)
	local target = Vector3.new(0, size.Y * 0.1, 0)
	previewState.Camera.CFrame = CFrame.lookAt(
		Vector3.new(radius * 0.95, radius * 0.85, radius * 1.15),
		target
	)
end

local function updateHandlePositions()
	if previewState == nil then
		return
	end

	for _, node in ipairs(previewState.Nodes) do
		local position, isVisible = previewState.Camera:WorldToViewportPoint(node.Part.Position)
		node.Handle.Visible = isVisible
		if isVisible then
			node.Handle.Position = UDim2.fromOffset(position.X - (node.Handle.AbsoluteSize.X / 2), position.Y - (node.Handle.AbsoluteSize.Y / 2))
		end
	end
end

local function getViewportMousePosition(viewport: ViewportFrame): Vector2
	local mousePosition = UserInputService:GetMouseLocation()
	local topLeftInset = select(1, GuiService:GetGuiInset())
	local adjusted = mousePosition - topLeftInset
	return adjusted - viewport.AbsolutePosition
end

local function updateDraggedNode()
	if dragState.Mode ~= "Dragging" or dragState.Node == nil or previewState == nil then
		return
	end

	local mousePosition = getViewportMousePosition(previewState.Viewport)
	local ray = previewState.Camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
	local directionY = ray.Direction.Y
	if math.abs(directionY) < 1e-5 then
		return
	end

	local planeY = previewState.BasePart.Position.Y
	local distance = (planeY - ray.Origin.Y) / directionY
	if distance <= 0 then
		return
	end

	local worldPoint = ray.Origin + (ray.Direction * distance)
	local localPoint = previewState.BasePart.CFrame:PointToObjectSpace(worldPoint)
	local rawOffset = Vector2.new(localPoint.X / previewState.BasePart.Size.X, localPoint.Z / previewState.BasePart.Size.Z)
	local node = dragState.Node
	local snapped = GateVisualRules.SnapToEdge(node.Kind, rawOffset)

	setNodeOffset(node.Kind, node.Index, snapped)
	positionPreviewNode(node)
	updateHandlePositions()
end

local function resetDragState()
	dragState.Mode = "Idle"
	dragState.Node = nil
	dragState.StartMouse = nil
end

local function destroyPreview()
	if previewConnection then
		previewConnection:Disconnect()
		previewConnection = nil
	end
	if dragBeganConnection then
		dragBeganConnection:Disconnect()
		dragBeganConnection = nil
	end
	if dragMovedConnection then
		dragMovedConnection:Disconnect()
		dragMovedConnection = nil
	end
	if dragEndedConnection then
		dragEndedConnection:Disconnect()
		dragEndedConnection = nil
	end

	resetDragState()
	previewState = nil
end

local function getClosestVisibleNode(mousePosition: Vector2): TPreviewNode?
	if previewState == nil then
		return nil
	end

	local closestNode: TPreviewNode? = nil
	local closestDistance = NODE_HANDLE_PICK_RADIUS
	for _, node in ipairs(previewState.Nodes) do
		if not node.Handle.Visible then
			continue
		end

		local handleCenter = node.Handle.AbsolutePosition + (node.Handle.AbsoluteSize / 2)
		local distance = (handleCenter - mousePosition).Magnitude
		if distance <= closestDistance then
			closestDistance = distance
			closestNode = node
		end
	end

	return closestNode
end

local function buildPreview(viewport: ViewportFrame, overlay: Frame, gateId: TGateId, visualContext: TVisualContext)
	local sourceModel = findGateModelById(gateId)
	if sourceModel == nil then
		setStatus("The selected gate could not be previewed.", true)
		return
	end

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local model = sourceModel:Clone()
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
		elseif descendant:IsA("ClickDetector") or descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end

	model:PivotTo(CFrame.new())
	model.Parent = worldModel

	local typedModel = model :: any
	local basePart = getAsPart(typedModel.Base)
	local mainPart = getAsPart(typedModel.Decoration.Main)
	local displayGui = model:FindFirstChild("DisplayNameGui", true)
	local displayLabel = if displayGui then displayGui:FindFirstChildWhichIsA("TextLabel") else nil
	local displayBadge = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(220, 30),
		BackgroundColor3 = Color3.fromRGB(8, 11, 16),
		BackgroundTransparency = 0.15,
		Text = "",
		TextColor3 = COLORS.Text,
		TextSize = 18,
		Font = Enum.Font.BuilderSansBold,
		Visible = false,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = overlay,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 999) }),
		create("UIStroke", { Color = COLORS.PanelAlt, Thickness = 1.5 }),
		create("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
	})

	local nodesFolder = typedModel.Nodes :: Folder
	local previewNodes: { TPreviewNode } = {}

	local function makeHandle(name: string, kind: TNodeKind): Frame
		local label = create("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 4),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Color3.fromRGB(10, 12, 17),
			BackgroundTransparency = 0.08,
			Text = name,
			TextColor3 = COLORS.Text,
			TextSize = 11,
			Font = Enum.Font.BuilderSansBold,
			BorderSizePixel = 0,
			ZIndex = 3,
		}, {
			create("UICorner", { CornerRadius = UDim.new(0, 999) }),
			create("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 3),
			}),
			create("UIStroke", { Color = Color3.fromRGB(12, 14, 18), Thickness = 1.25 }),
		})

		return create("Frame", {
			Name = name .. "Handle",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = if kind == "Input" then COLORS.InputNode else COLORS.OutputNode,
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = overlay,
		}, {
			create("UICorner", { CornerRadius = UDim.new(1, 0) }),
			create("UIStroke", { Color = Color3.fromRGB(12, 14, 18), Thickness = 2 }),
			label,
		})
	end

	for index, name in ipairs(visualContext.InputNodes) do
		local nodePart = nodesFolder:FindFirstChild(name)
		if nodePart and nodePart:IsA("BasePart") then
			table.insert(previewNodes, {
				Name = name,
				Kind = "Input" :: TNodeKind,
				Index = index,
				Part = nodePart,
				Handle = makeHandle(name, "Input"),
			})
		end
	end

	for index, name in ipairs(visualContext.OutputNodes) do
		local nodePart = nodesFolder:FindFirstChild(name)
		if nodePart and nodePart:IsA("BasePart") then
			table.insert(previewNodes, {
				Name = name,
				Kind = "Output" :: TNodeKind,
				Index = index,
				Part = nodePart,
				Handle = makeHandle(name, "Output"),
			})
		end
	end

	previewState = {
		Viewport = viewport,
		Overlay = overlay,
		WorldModel = worldModel,
		Camera = camera,
		Model = model,
		BasePart = basePart,
		MainPart = mainPart,
		DisplayLabel = displayLabel,
		DisplayBadge = displayBadge,
		Nodes = previewNodes,
		Rotation = 0,
	}

	updateMainColorPreview()
	updateDisplayNamePreview()
	updatePreviewNodes()
	refreshCamera()
	updateHandlePositions()

	dragBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or previewState == nil then
			return
		end

		local isPrimary = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		if not isPrimary then
			return
		end

		local mousePosition = getViewportMousePosition(previewState.Viewport)
		local inBounds = mousePosition.X >= 0
			and mousePosition.Y >= 0
			and mousePosition.X <= previewState.Viewport.AbsoluteSize.X
			and mousePosition.Y <= previewState.Viewport.AbsoluteSize.Y
		if not inBounds then
			return
		end

		local node = getClosestVisibleNode(mousePosition)
		if node == nil then
			resetDragState()
			return
		end

		dragState.Mode = "Armed"
		dragState.Node = node
		dragState.StartMouse = mousePosition
	end)

	dragMovedConnection = UserInputService.InputChanged:Connect(function(input, _gameProcessed)
		if previewState == nil then
			return
		end

		local isPointerMove = input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch
		if not isPointerMove then
			return
		end

		if dragState.Mode == "Armed" and dragState.StartMouse ~= nil then
			local mousePosition = getViewportMousePosition(previewState.Viewport)
			if (mousePosition - dragState.StartMouse).Magnitude >= DRAG_START_DISTANCE then
				dragState.Mode = "Dragging"
			end
		end
	end)

	dragEndedConnection = UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		local isPrimary = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
		if isPrimary then
			resetDragState()
		end
	end)

	previewConnection = RunService.RenderStepped:Connect(function(deltaTime: number)
		if previewState == nil then
			return
		end

		if dragState.Mode == "Dragging" then
			updateDraggedNode()
		else
			previewState.Rotation += deltaTime * 0.65
			previewState.Model:PivotTo(CFrame.Angles(0, previewState.Rotation, 0))
			updatePreviewNodes()
			updateHandlePositions()
		end
	end)
end

local function makeLabeledField(parent: Instance, title: string): Frame
	return create("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		Parent = parent,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Text = title,
			TextColor3 = COLORS.Muted,
			TextSize = 13,
			Font = Enum.Font.BuilderSansMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

local function addColorChannelEditor(parent: Instance, channelName: string, channelKey: "R" | "G" | "B")
	local currentColor = visualDraft.MainColor :: Color3
	local initialChannelValue = if channelKey == "R"
		then currentColor.R
		elseif channelKey == "G"
		then currentColor.G
		else currentColor.B

	local row = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		Parent = parent,
	}, {
		create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(16, 34),
			Text = channelName,
			TextColor3 = COLORS.Text,
			TextSize = 14,
			Font = Enum.Font.BuilderSansBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})

	local box = create("TextBox", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(88, 34),
		BackgroundColor3 = COLORS.Input,
		TextColor3 = COLORS.Text,
		Text = tostring(math.round(initialChannelValue * 255)),
		PlaceholderText = "0-255",
		ClearTextOnFocus = false,
		TextSize = 13,
		Font = Enum.Font.Code,
		BorderSizePixel = 0,
		Parent = row,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 8) }),
		create("UIStroke", { Color = COLORS.PanelAlt, Thickness = 1 }),
	})

	box.FocusLost:Connect(function()
		local numeric = tonumber(box.Text)
		if numeric == nil then
			local fallbackColor = visualDraft.MainColor :: Color3
			local fallbackValue = if channelKey == "R"
				then fallbackColor.R
				elseif channelKey == "G"
				then fallbackColor.G
				else fallbackColor.B
			box.Text = tostring(math.round(fallbackValue * 255))
			box.TextColor3 = COLORS.Error
			return
		end

		local clamped = math.clamp(math.round(numeric), 0, 255)
		local current = visualDraft.MainColor :: Color3
		local nextColor = Color3.fromRGB(
			if channelKey == "R" then clamped else math.round(current.R * 255),
			if channelKey == "G" then clamped else math.round(current.G * 255),
			if channelKey == "B" then clamped else math.round(current.B * 255)
		)

		visualDraft.MainColor = nextColor
		box.Text = tostring(clamped)
		box.TextColor3 = COLORS.Text
		updateMainColorPreview()
	end)
end

function CustomizerUI.Open(gateId: TGateId, visualContext: TVisualContext)
	CustomizerUI.Close()

	currentGateId = gateId
	visualDraft = deepClone(visualContext.Visuals)

	activeGui = create("ScreenGui", {
		Name = "CustomizerGUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})

	local blocker = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.3,
		Text = "",
		AutoButtonColor = false,
		Parent = activeGui,
	})
	blocker.MouseButton1Click:Connect(CustomizerUI.Close)

	local panel = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(980, 620),
		BackgroundColor3 = COLORS.Bg,
		BorderSizePixel = 0,
		Parent = activeGui,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 14) }),
		create("UIStroke", { Color = COLORS.PanelAlt, Thickness = 2 }),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 18),
			PaddingBottom = UDim.new(0, 18),
			PaddingLeft = UDim.new(0, 18),
			PaddingRight = UDim.new(0, 18),
		}),
	})

	local closeButton = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = COLORS.PanelAlt,
		Text = "X",
		TextColor3 = COLORS.Text,
		TextSize = 14,
		Font = Enum.Font.BuilderSansBold,
		BorderSizePixel = 0,
		Parent = panel,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 10) }),
	})
	closeButton.MouseButton1Click:Connect(CustomizerUI.Close)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, -56, 0, 26),
		Text = visualContext.SpecificationName .. " Visuals",
		TextColor3 = COLORS.Text,
		TextSize = 24,
		Font = Enum.Font.BuilderSansBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, -56, 0, 22),
		Text = "Rotate, recolor, rename, and drag nodes around the gate base before applying the rebuilt model.",
		TextColor3 = COLORS.Muted,
		TextSize = 14,
		Font = Enum.Font.BuilderSans,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})

	local body = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 1, -126),
		Parent = panel,
	}, {
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 16),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local previewCard = create("Frame", {
		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(530, 410),
		Parent = body,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 14) }),
		create("UIStroke", { Color = COLORS.PanelAlt, Thickness = 1 }),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
		}),
	})

	create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Text = "Preview",
		TextColor3 = COLORS.Text,
		TextSize = 16,
		Font = Enum.Font.BuilderSansBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = previewCard,
	})

	local viewportHolder = create("Frame", {
		BackgroundColor3 = COLORS.Input,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		Parent = previewCard,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 12) }),
		create("UIStroke", { Color = COLORS.PanelAlt, Thickness = 1 }),
	})

	local viewport = create("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = viewportHolder,
	})

	local overlay = create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = viewportHolder,
	})

	local controls = create("ScrollingFrame", {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollBarThickness = 6,
		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -546, 1, 0),
		Parent = body,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 14) }),
		create("UIStroke", { Color = COLORS.PanelAlt, Thickness = 1 }),
		create("UIPadding", {
			PaddingTop = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 16),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
		}),
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})

	local nameField = makeLabeledField(controls, "Display Name")
	if visualContext.HasDisplayName then
		local nameBox = create("TextBox", {
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundColor3 = COLORS.Input,
			Text = visualDraft.DisplayName,
			TextColor3 = COLORS.Text,
			PlaceholderText = "Gate name",
			ClearTextOnFocus = false,
			TextSize = 14,
			Font = Enum.Font.BuilderSans,
			BorderSizePixel = 0,
			Parent = nameField,
		}, {
			create("UICorner", { CornerRadius = UDim.new(0, 10) }),
			create("UIStroke", { Color = COLORS.PanelAlt, Thickness = 1 }),
		})

		nameBox.FocusLost:Connect(function()
			visualDraft.DisplayName = nameBox.Text
			updateDisplayNamePreview()
		end)
	else
		create("TextLabel", {
			BackgroundColor3 = COLORS.Input,
			Size = UDim2.new(1, 0, 0, 38),
			Text = "This prefab does not expose a DisplayName label.",
			TextColor3 = COLORS.Disabled,
			TextSize = 13,
			Font = Enum.Font.BuilderSans,
			TextWrapped = true,
			BorderSizePixel = 0,
			Parent = nameField,
		}, {
			create("UICorner", { CornerRadius = UDim.new(0, 10) }),
			create("UIStroke", { Color = COLORS.PanelAlt, Thickness = 1 }),
		})
	end

	local prefabField = makeLabeledField(controls, "Prefab Type")
	create("TextButton", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = COLORS.Input,
		Text = visualDraft.PrefabName .. " (Soon)",
		TextColor3 = COLORS.Disabled,
		TextSize = 14,
		Font = Enum.Font.BuilderSans,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Active = false,
		Parent = prefabField,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		create("UIStroke", { Color = COLORS.PanelAlt, Thickness = 1 }),
	})

	local colorField = makeLabeledField(controls, "Main Color")
	colorSwatch = create("Frame", {
		BackgroundColor3 = visualDraft.MainColor,
		Size = UDim2.new(1, 0, 0, 40),
		BorderSizePixel = 0,
		Parent = colorField,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 10) }),
		create("UIStroke", { Color = COLORS.PanelAlt, Thickness = 1 }),
	})

	addColorChannelEditor(colorField, "R", "R")
	addColorChannelEditor(colorField, "G", "G")
	addColorChannelEditor(colorField, "B", "B")

	statusLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 1),
		Size = UDim2.new(1, -180, 0, 40),
		AnchorPoint = Vector2.new(0, 1),
		Text = "Adjust the preview, then apply to rebuild the selected gate.",
		TextColor3 = COLORS.Muted,
		TextSize = 14,
		Font = Enum.Font.BuilderSans,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = panel,
	})
	statusLabel.Position = UDim2.new(0, 0, 1, -40)

	applyButton = create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(160, 42),
		BackgroundColor3 = COLORS.Accent,
		Text = "Apply",
		TextColor3 = Color3.fromRGB(11, 19, 26),
		TextSize = 16,
		Font = Enum.Font.BuilderSansBold,
		BorderSizePixel = 0,
		Parent = panel,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 12) }),
		create("UIStroke", { Color = Color3.fromRGB(18, 53, 74), Thickness = 1 }),
	})

	buildPreview(viewport, overlay, gateId, visualContext)
	updateMainColorPreview()

	applyButton.MouseButton1Click:Connect(function()
		if applyBusy or currentGateId == nil then
			return
		end

		setApplyBusy(true)
		setStatus("Applying visuals...", false)

		task.spawn(function()
			local visualsSuccess, visualsMessage, resolvedVisuals = ApplyVisualsEvent:InvokeServer(currentGateId, deepClone(visualDraft))
			if not visualsSuccess then
				setApplyBusy(false)
				setStatus(visualsMessage or "Failed to apply visuals.", true)
				return
			end

			if type(resolvedVisuals) == "table" then
				visualDraft = deepClone(resolvedVisuals)
				updateDisplayNamePreview()
				updateMainColorPreview()
				updatePreviewNodes()
				updateHandlePositions()
			end

			setApplyBusy(false)
			setStatus("Applied. The gate model was rebuilt in place.", false)
		end)
	end)
end

function CustomizerUI.Close()
	destroyPreview()

	if activeGui then
		activeGui:Destroy()
	end

	activeGui = nil
	currentGateId = nil
	statusLabel = nil
	applyButton = nil
	colorSwatch = nil
	visualDraft = nil
	setApplyBusy(false)
end

return CustomizerUI
