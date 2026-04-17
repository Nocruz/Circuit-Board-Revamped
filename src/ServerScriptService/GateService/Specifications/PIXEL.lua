local Updates = require(script.Parent.Parent.Updates)
return {
  Nodes = { Outputs = { }, Inputs = { "R", "G", "B" } },
  DefaultVisuals = {
    PrefabName = "Display",
    MainColor = Color3.fromRGB(91, 93, 105)
  },

  Process = function(self)
    local color = Color3.new(self:ReadInput("R").AsNumber(), self:ReadInput("G").AsNumber(), self:ReadInput("B").AsNumber())
    Updates.RegisterVisualChange(self.Model.Decoration.Screen, { Color = color })
  end
}
