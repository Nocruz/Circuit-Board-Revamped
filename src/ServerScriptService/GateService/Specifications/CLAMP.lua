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
    local hasMinConnection, min = self:ReadAttributeFromNode("Min", "Min")
    min = if hasMinConnection then min.AsNumber() else min
    local hasMaxConnection, max = self:ReadAttributeFromNode("Max", "Max")
    max = if hasMaxConnection then max.AsNumber() else max

    if min > max then min, max = max, min end

    self.Nodes.Signals["Output"] = math.clamp(self:ReadInput("Input").AsNumber(), min, max)
  end
}
