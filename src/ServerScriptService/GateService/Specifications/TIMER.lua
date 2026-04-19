local Updates = require(script.Parent.Parent.Updates)

return {
  Nodes = { Outputs = { "Output" }, Inputs = { "Input" } },
  DefaultVisuals = {
    MainMaterial = Enum.Material.DiamondPlate,
    MainColor = Color3.fromRGB(153, 189, 189)
  },
  AttributeData = {
    ["Delay"] = { Default = 1, Predicates = { function(value) return value >= 0 end, } },
    ["Duration"] = { Default = 1, Predicates = { function(value) return value >= 0 end, } },
  },

  Setup = function(self)
    self.Nodes.Signals["Output"] = false
  end,

  Process = function(self, payload)
    local inputSignal = self:ReadInput("Input")
    local inputBool = inputSignal.AsBoolean()
    
    -- Rising edge: input goes from false -> true
    if inputBool and not self.Nodes.Signals["Output"] then
      if self.Attributes.Delay == 0 then
        self.Nodes.Signals["Output"] = inputSignal.Raw
        if not Updates.IsWakeupScheduled(self.Id, "DurationTimer") then
          Updates.ScheduleWakeup(self.Id, self.Attributes.Duration, { Source = "DurationExpired" }, "DurationExpired")
        end
      else
        if not Updates.IsWakeupScheduled(self.Id, "DelayTimer") then
          Updates.ScheduleWakeup(self.Id, self.Attributes.Delay, { Source = "DelayExpired" }, "DelayTimer")
        end
      end
    
    -- Input turned false before gate turned on: cancel timer and output false immediately
    elseif not inputBool and not self.Nodes.Signals["Output"] then
      if Updates.IsWakeupScheduled(self.Id, "DelayTimer") then
        Updates.CancelWakeup(self.Id, "DelayTimer")
      end
      self.Nodes.Signals["Output"] = false
    end
    
    -- Handle delayed wakeup
    if payload and payload.Source == "DelayExpired" then
      self.Nodes.Signals["Output"] = true
      if not Updates.IsWakeupScheduled(self.Id, "DurationTimer") then
        Updates.ScheduleWakeup(self.Id, self.Attributes.Duration, { Source = "DurationExpired" }, "DurationExpired")
      end
    elseif payload and payload.Source == "DurationExpired" then
      self.Nodes.Signals["Output"] = false
    end
  end
}
