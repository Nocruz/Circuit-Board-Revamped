local ServerScriptService = game:GetService("ServerScriptService")
local Updates = require(ServerScriptService.GateService.Updates)

return {
	Nodes = { Outputs = { "Output" }, Inputs = { "Input" } },
	DefaultVisuals = {
		MainMaterial = Enum.Material.Sand,
		MainColor = Color3.fromRGB(0, 0, 34)
	},

	AttributeData = {
		["Steps"] = { Default = 1, Predicates = { function(value) return value >= 0 end, } },
	},

	Setup = function(self, state)
		if state.Internal then
			self.InternalState = {
				Count = if state.Internal.Count ~= nil then state.Internal.Count else 0,
				Counting = if state.Internal.Counting ~= nil then state.Internal.Counting else false
			}
		else
			self.InternalState = {
				Count = 0,
				Counting = false
			}
		end

		-- Wakeups don't survive a reload, so if we were mid-count, re-arm the
		-- next step tick or the counter would freeze forever.
		if self.InternalState.Counting and not Updates.IsWakeupScheduled(self.ID, "StallTimer") then
			Updates.ScheduleWakeup(self.ID, 0, { Source = "StepTick" }, "StallTimer")
		end
	end,

	Process = function(self, payload)
		local inputSignal = self:ReadInput("Input")
		local inputBool = inputSignal.AsBoolean()

		-- Rising edge: input goes from false -> true
		if inputBool and not self.Nodes.Signals["Output"] then
			if self.Attributes.Steps == 0 then
				self.Nodes.Signals["Output"] = inputSignal.Raw
			elseif not self.InternalState.Counting then
				self.InternalState.Count = 0
				self.InternalState.Counting = true
				Updates.ScheduleWakeup(self.ID, 0, { Source = "StepTick" }, "StallTimer")
			end

		-- Input is true and was already true: output instantly
		elseif inputBool and self.Nodes.Signals["Output"] then
			self.Nodes.Signals["Output"] = true

		-- Input turned false: cancel timers, reset count, output false immediately
		elseif not inputBool then
			Updates.CancelAllWakeups(self.ID)
			self.InternalState.Count = 0
			self.InternalState.Counting = false
			self.Nodes.Signals["Output"] = false
		end

		-- Handle step wakeup
		if payload and payload.Source == "StepTick" then
			self.InternalState.Count += 1
			if self.InternalState.Count >= self.Attributes.Steps then
				self.InternalState.Counting = false
				self.Nodes.Signals["Output"] = true
			else
				Updates.ScheduleWakeup(self.ID, 0, { Source = "StepTick" }, "StallTimer")
			end
		end
	end
}
