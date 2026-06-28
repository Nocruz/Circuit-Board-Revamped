local ServerScriptService = game:GetService("ServerScriptService")

local Updates = require(ServerScriptService.GateService.Updates)

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
    self.State = {
      Phase = "IDLE", -- "IDLE" | "WAITING_DELAY" | "PULSING" | "COOLDOWN"
      Input = false,
    }
  end,

  Process = function(self, payload)
    local inputSignal = self:ReadInput("Input")
    local inputBool = inputSignal.AsBoolean()
    local state = self.State

    -- Wakeups update the phase before we process any new input edge.
    if payload and payload.Source == "DelayExpired" then
      self.Nodes.Signals["Output"] = true
      state.Phase = "PULSING"

      if not Updates.IsWakeupScheduled(self.Id, "DurationTimer") then
        Updates.ScheduleWakeup(self.Id, self.Attributes.Duration, { Source = "DurationExpired" }, "DurationTimer")
      end

    elseif payload and payload.Source == "DurationExpired" then
      self.Nodes.Signals["Output"] = false
      state.Phase = inputBool and "COOLDOWN" or "IDLE"
    end

    -- Rising edge only: a steady-high input must not re-arm after the pulse ends.
    if inputBool and not state.Input then
      if state.Phase == "IDLE" then
        if self.Attributes.Delay == 0 then
          self.Nodes.Signals["Output"] = inputSignal.Raw
          state.Phase = "PULSING"

          if not Updates.IsWakeupScheduled(self.Id, "DurationTimer") then
            Updates.ScheduleWakeup(self.Id, self.Attributes.Duration, { Source = "DurationExpired" }, "DurationTimer")
          end
        else
          state.Phase = "WAITING_DELAY"

          if not Updates.IsWakeupScheduled(self.Id, "DelayTimer") then
            Updates.ScheduleWakeup(self.Id, self.Attributes.Delay, { Source = "DelayExpired" }, "DelayTimer")
          end
        end
      end

    -- Cancel the delayed turn-on if the input drops before the delay expires.
    elseif not inputBool and (state.Phase == "WAITING_DELAY" or state.Phase == "COOLDOWN") then
      if Updates.IsWakeupScheduled(self.Id, "DelayTimer") then
        Updates.CancelWakeup(self.Id, "DelayTimer")
      end

      self.Nodes.Signals["Output"] = false
      state.Phase = "IDLE"
    end

    state.Input = inputBool

    return self.Nodes.Signals["Output"]
  end
}
