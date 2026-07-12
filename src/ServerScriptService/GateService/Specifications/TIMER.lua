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
	
	Setup = function(self, state)
		if state.Internal then
			self.InternalState = {
				Phase = if state.Internal.Phase ~= nil then state.Internal.Phase else "IDLE",
				LastInput = if state.Internal.LastInput ~= nil then state.Internal.LastInput else false
			}
			
			if self.InternalState.Phase == "WAITING_DELAY" then
				Updates.ScheduleWakeup(self.ID, self.Attributes.Delay, { Source = "DelayExpired" }, "DelayTimer")
			elseif self.InternalState.Phase == "PULSING" then
				Updates.ScheduleWakeup(self.ID, self.Attributes.Duration, { Source = "DurationExpired" }, "DurationTimer")
			end
			
		else
			self.InternalState = {
				Phase = "IDLE",
				LastInput = false
			}
		end
	end,
	
	Process = function(self, payload)
		local inputSignal = self:ReadInput("Input")
		local inputBool = inputSignal.AsBoolean()
		local state = self.InternalState
		-- Wakeups update the phase before we process any new input edge.
		if payload and payload.Source == "DelayExpired" then
			self.Nodes.Signals["Output"] = true
			state.Phase = "PULSING"
			if not Updates.IsWakeupScheduled(self.ID, "DurationTimer") then
				Updates.ScheduleWakeup(self.ID, self.Attributes.Duration, { Source = "DurationExpired" }, "DurationTimer")
			end
		elseif payload and payload.Source == "DurationExpired" then
			self.Nodes.Signals["Output"] = false
			state.Phase = inputBool and "COOLDOWN" or "IDLE"
		end
		-- Rising edge only: a steady-high input must not re-arm after the pulse ends.
		if inputBool and not state.LastInput then
			if state.Phase == "IDLE" then
				if self.Attributes.Delay == 0 then
					self.Nodes.Signals["Output"] = inputSignal.Raw
					state.Phase = "PULSING"
					if not Updates.IsWakeupScheduled(self.ID, "DurationTimer") then
						Updates.ScheduleWakeup(self.ID, self.Attributes.Duration, { Source = "DurationExpired" }, "DurationTimer")
					end
				else
					state.Phase = "WAITING_DELAY"
					if not Updates.IsWakeupScheduled(self.ID, "DelayTimer") then
						Updates.ScheduleWakeup(self.ID, self.Attributes.Delay, { Source = "DelayExpired" }, "DelayTimer")
					end
				end
			end
		-- Cancel the delayed turn-on if the input drops before the delay expires.
		elseif not inputBool and (state.Phase == "WAITING_DELAY" or state.Phase == "COOLDOWN") then
			if Updates.IsWakeupScheduled(self.ID, "DelayTimer") then
				Updates.CancelWakeup(self.ID, "DelayTimer")
			end
			self.Nodes.Signals["Output"] = false
			state.Phase = "IDLE"
		end
		state.LastInput = inputBool
	end
}
