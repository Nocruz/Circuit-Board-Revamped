local ServerScriptService = game:GetService("ServerScriptService")

local Updates = require(ServerScriptService.GateService.Updates)

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
    gate.Label = gate.Model.Screen.SurfaceGui.TextLabel
  end,

  Process = function(self)
    local hasInputConnection, value = self:ReadAttributeFromNode("Text", "Input")
    value = if hasInputConnection then value.AsString() else value
    Updates.RegisterVisualChange(self.Label, { Text = if value == "false" then "" else value })
  end
}
