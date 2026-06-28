local ServerScriptService = game:GetService("ServerScriptService")

local Updates = require(ServerScriptService.GateService.Updates)

return {
  Nodes = { Outputs = { "Output" }, Inputs = { } },
  DefaultVisuals = {
    PrefabName = "Button",
    MainColor = Color3.fromRGB(196, 40, 28)
  },
  
  AttributeData = {
    ["IsClickable"] = { Default = true, Predicates = { } },
    ["Duration"] = { Default = 1, Predicates = { function(value) return value >= 0 end, } },
  },

  Setup = function(self)
    self.State = { IsOn = false, LastInput = false }
    self.Main = self.Model.Main

    self.ClickDetector = Instance.new("ClickDetector")
    self.ClickDetector.Parent = self.Model
    self.ClickDetectorConnection = self.ClickDetector.MouseClick:Connect(function(player) Updates.Propagate(self.ID, { Source = "Interaction", Player = player} ) end)
  end,

  Process = function(self, payload)
    if payload and payload.Source == "Interaction" and self.Attributes.IsClickable and not self.State.IsOn then
      self.State.IsOn = true
      Updates.ScheduleWakeup(self.ID, self.Attributes.Duration, { Source = "TimerExpired"}, "Timer" )

    elseif payload and payload.Source == "TimerExpired" then
      self.State.IsOn = false
    end

    self.Main.Position = self.Model.Base:GetPivot().Position + if self.State.IsOn then Vector3.new(0, 0.7, 0) else Vector3.new(0, 0.85, 0)
    self.Nodes.Signals["Output"] = self.State.IsOn
  end,

  Destroy = function(self)
    if self.ClickDetectorConnection then
      self.ClickDetectorConnection:Disconnect()
      self.ClickDetectorConnection = nil
    end
  end
}
