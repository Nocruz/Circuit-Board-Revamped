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

    self.Top.Color = color
    self.Light.Color = color
    self.Light.Enabled = color ~= Color3.new()
  end
}
