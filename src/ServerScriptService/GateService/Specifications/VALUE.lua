return {
  Nodes = { Outputs = { "Output" }, Inputs = { } },
  DefaultVisuals = { MainColor = Color3.fromRGB(68, 190, 54) },
  AttributeData = { ["Value"] = { Default = "", Predicates = {}, AllowedValues = nil } },
  
  Process = function(self)
    self.Nodes.Signals["Output"] = self.Attributes.Value
  end
}
