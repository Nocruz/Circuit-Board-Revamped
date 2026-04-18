return {
  Nodes = { Outputs = { "Output" }, Inputs = { "Start", "Input", "End" } },
  DefaultVisuals = {
    MainMaterial = Enum.Material.Marble,
    MainColor = Color3.fromRGB(158, 149, 45),
    InputOffsets = { Vector2.new(-0.50, 0.00), Vector2.new(0.00, 0.50), Vector2.new(0.50, 0.00) }
  },
  AttributeData = {
    ["Start"] = { Default = 0, Predicates = { } },
    ["End"] = { Default = 10, Predicates = { } },
  },
  
  Process = function(self)
    local hasConnection, stringStart = self:ReadAttribute("Start", "Start")
    stringStart = if hasConnection then stringStart.AsNumber() else stringStart
    local hasConnection, stringEnd = self:ReadAttribute("End", "End")
    stringEnd = if hasConnection then stringEnd.AsNumber() else stringEnd

    if stringStart > stringEnd then stringStart, stringEnd = stringEnd, stringStart end

    self.Nodes.Signals["Output"] = string.sub(self:ReadInput("Input").AsString(), stringStart, stringEnd)
  end
}
