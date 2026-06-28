return {
  Nodes = { Outputs = { "Output" }, Inputs = { "Down", "Reset", "Up", "Delta", "ResetTo" } },
  DefaultVisuals = {
    MainMaterial = Enum.Material.DiamondPlate,
    MainColor = Color3.fromRGB(85, 45, 0)
  },
  AttributeData = {
    ["Min"] = { Default = 0, Predicates = { } },
    ["Max"] = { Default = 100, Predicates = { } },
    ["Increment"] = { Default = 1, Predicates = { } },
    ["ResetTo"] = { Default = 0, Predicates = { } },
  },

  Setup = function(self)
    self.Nodes.Signals["Output"] = 0
    self.LastState = { Down = false, Up = false }
  end,

  Process = function(self)
    local Down, Reset, Up = self:ReadInput("Down").AsBoolean(), self:ReadInput("Reset").AsBoolean(), self:ReadInput("Up").AsBoolean()

    local hasIncrementConnection, Increment = self:ReadAttributeFromNode("Increment", "Delta")
    Increment = if hasIncrementConnection then Increment.AsNumber() else Increment
    local hasResetConnection, ResetTo = self:ReadAttributeFromNode("ResetTo", "ResetTo")
    ResetTo = if hasResetConnection then ResetTo.AsNumber() else ResetTo

    local currentCount = self.Nodes.Signals["Output"]
    local nextCount = currentCount

    if Reset then
  	  self.Nodes.Signals["Output"] = ResetTo
  	  return
  	else
  		if Up and not self.LastState.Up then
  			nextCount += Increment
  		end

  		if Down and not self.LastState.Down then
  			nextCount -= Increment
  		end
  	end

    local min = self.Attributes.Min
    local max = self.Attributes.Max
    if min > max then min, max = max, min end

  	nextCount = math.clamp(nextCount, min, max)

  	self.LastState = { Up = Up, Down = Down }
    self.Nodes.Signals["Output"] = nextCount
  end
}
