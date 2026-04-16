return {
  Nodes = { Outputs = { "Output" }, Inputs = { "Toggle" } },
  DefaultVisuals = {
    PrefabName = "Activator",
    MainColor = Color3.fromRGB(255, 140, 10)
  },
  AttributeData = { ["IsClickable"] = { Default = true, Predicates = { } }, },

  Setup = function(self)
    self.State = { IsOn = false, LastInput = false }
    self.Main = self.Model.Decoration.Main

    self.ClickDetector = Instance.new("ClickDetector")
    self.ClickDetector.Parent = self.Model
  end,

  Process = function(self, payload)
    if payload and payload.Source == "Interaction" and self.Attributes.IsClickable then
      self.State.IsOn = not self.State.IsOn
    else
      local input = self:ReadInput("Toggle").AsBoolean()

      if input and not self.State.LastInput then
        self.State.IsOn = not self.State.IsOn
      end

      self.State.LastInput = input
    end

    self.Main.Position = self.Model.Base:GetPivot().Position + if self.State.IsOn then Vector3.new(0, 0.7, 0) else Vector3.new(0, 0.85, 0)
    self.Nodes.Signals["Output"] = self.State.IsOn
  end
}
