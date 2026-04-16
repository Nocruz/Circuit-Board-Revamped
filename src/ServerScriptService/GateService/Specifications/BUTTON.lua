local Updates = require(script.Parent.Parent.Updates)

return {
  Nodes = { Outputs = { "Output" }, Inputs = { } },
  DefaultVisuals = {
    PrefabName = "Activator",
    MainColor = Color3.fromRGB(196, 40, 28)
  },
  AttributeData = {
    ["IsClickable"] = { Default = true, Predicates = { } },
    ["Duration"] = { Default = 1, Predicates = { function(value) return value >= 0 end, } },
  },

  Setup = function(self)
    self.State = { IsOn = false, LastInput = false }
    self.Main = self.Model.Decoration.Main

    self.ClickDetector = Instance.new("ClickDetector")
    self.ClickDetector.Parent = self.Model
  end,

  Process = function(self, payload)
    if payload and payload.Source == "Interaction" and self.Attributes.IsClickable and not self.State.IsOn then
      print("Button pressed: true")
      self.State.IsOn = true
      Updates.ScheduleWakeup(self.Id, self.Attributes.Duration, { Source = "TimerExpired"}, "Timer" )

    elseif payload and payload.Source == "TimerExpired" then
      print("Button awoke: false")
      self.State.IsOn = false
    end

    self.Main.Position = self.Model.Base:GetPivot().Position + if self.State.IsOn then Vector3.new(0, 0.7, 0) else Vector3.new(0, 0.85, 0)
    self.Nodes.Signals["Output"] = self.State.IsOn
  end
}
