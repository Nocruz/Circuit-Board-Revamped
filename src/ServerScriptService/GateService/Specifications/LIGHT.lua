local Updates = require(script.Parent.Parent.Updates)
return {
  Nodes = { Outputs = { }, Inputs = { "R", "G", "B" } },
  DefaultVisuals = {
    PrefabName = "Light",
    MainColor = Color3.fromRGB(91, 93, 105)
  },

  Setup = function(gate)
    gate.Top = gate.Model.Decoration.Top
    gate.Light = gate.Top.PointLight
  end,

  Process = function(self)
    local color = Color3.new(self:ReadInput("R").AsNumber(), self:ReadInput("G").AsNumber(), self:ReadInput("B").AsNumber())

    Updates.RegisterVisualChange(self.Model.Decoration.Top, { PointLight = { Color = color, Enabled = color ~= Color3.new() }, Color = color })
  end
}
