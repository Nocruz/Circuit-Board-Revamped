return {
  Nodes = { Outputs = { "Output" }, Inputs = { "Min", "Generate", "Max" } },
  DefaultVisuals = {
    MainMaterial = Enum.Material.DiamondPlate,
    MainColor = Color3.fromRGB(123, 0, 123),
    InputOffsets = { Vector2.new(-0.50, 0.00), Vector2.new(0.00, 0.50), Vector2.new(0.50, 0.00) }
  },
  AttributeData = {
    ["Min"] = { Default = 0, Predicates = { } },
    ["Max"] = { Default = 10, Predicates = { } },
  },

  Setup = function(self)
    self.LastInput = nil
  end,

  Process = function(self)
    local input = self:ReadInput("Generate").AsBoolean()

    if input and not self.LastInput then
      local hasMinConnection, min = self:ReadAttributeFromNode("Min", "Min")
      min = if hasMinConnection then min.AsNumber() else min
      local hasMaxConnection, max = self:ReadAttributeFromNode("Max", "Max")
      max = if hasMaxConnection then max.AsNumber() else max

      if min > max then min, max = max, min end

      self.Nodes.Signals["Output"] = math.random(min, max)
    elseif not input then
      self.Nodes.Signals["Output"] = 0
    end

    self.LastInput = input
  end
}
