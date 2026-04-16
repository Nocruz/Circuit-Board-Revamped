return {
  Nodes = { Outputs = { }, Inputs = { "R", "G", "B" } },
  DefaultVisuals = {
    PrefabName = "Display",
    MainColor = Color3.fromRGB(91, 93, 105)
  },

  Setup = function(gate)
    gate.Screen = gate.Model.Decoration.Screen
  end,

  Process = function(self)
    local color = Color3.new(self:ReadInput("R").AsNumber(), self:ReadInput("G").AsNumber(), self:ReadInput("B").AsNumber())
    self.Screen.Color = color
  end
}
