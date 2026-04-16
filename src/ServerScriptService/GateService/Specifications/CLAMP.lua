return {
  Nodes = { Outputs = { "Output" }, Inputs = { "Min", "Input", "Max" } },
  DefaultVisuals = {
    MainColor = Color3.fromRGB(0, 85, 255),
    InputOffsets = { Vector2.new(-0.50, 0.00), Vector2.new(0.00, 0.50), Vector2.new(0.50, 0.00) }
  },
  AttributeData = {
    ["Min"] = { Default = 0, Predicates = { } },
    ["Max"] = { Default = 10, Predicates = { } },
  },

  Process = function(self)
    local hasConnection, min = self:ReadAttribute("Min", "Min")
    min = if hasConnection then min.AsNumber() else min
    local hasConnection, max = self:ReadAttribute("Max", "Max")
    max = if hasConnection then max.AsNumber() else max

    if min > max then min, max = max, min end

    self.Nodes.Signals["Output"] = math.clamp(self:ReadInput("Input").AsNumber(), min, max)
  end
}
