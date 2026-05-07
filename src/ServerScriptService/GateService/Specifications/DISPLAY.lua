local Updates = require(script.Parent.Parent.Updates)
return {
  Nodes = { Outputs = { }, Inputs = { "Input" } },
  DefaultVisuals = {
    PrefabName = "Display",
    MainColor = Color3.fromRGB(91, 93, 105)
  },
  AttributeData = {
    ["Text"] = { Default = "", Predicates = { } }
  },

  Setup = function(gate)
    gate.Label = gate.Model.Decoration.Screen.SurfaceGui.TextLabel
  end,

  Process = function(self)
    local hasConnection, value = self:ReadAttribute("Text", "Input")
    value = if hasConnection then value.AsString() else value
    Updates.RegisterVisualChange(self.Label, { Text = if value == "false" then "" else value })
  end
}
