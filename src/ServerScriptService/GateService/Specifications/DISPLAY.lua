local Updates = require(script.Parent.Parent.Updates)
return {
  Nodes = { Outputs = { }, Inputs = { "Input" } },
  DefaultVisuals = {
    PrefabName = "Display",
    MainColor = Color3.fromRGB(91, 93, 105)
  },

  Setup = function(gate)
    gate.Label = gate.Model.Decoration.Screen.SurfaceGui.TextLabel
  end,

  Process = function(self)
    local value: string = self:ReadInput("Input").AsString()
    Updates.RegisterVisualChange(self.Label, { Text = if value == "false" then "" else value })
  end
}
