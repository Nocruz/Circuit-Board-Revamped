local Updates = require(script.Parent.Parent.Updates)

return {
	Nodes = { Outputs = { "Output" }, Inputs = { "Input" } },
	DefaultVisuals = {
		MainMaterial = Enum.Material.Sand,
		MainColor = Color3.fromRGB(60, 60, 60),
	},

	Setup = function(self)
		self.State = {
			LastInput = nil,
			PulseActive = false,
		}
	end,

	Process = function(self, payload)
		local input = self:ReadInput("Input")
		local current = input.Raw

		if payload and payload.Source == "ResetPulse" then
			self.State.PulseActive = false
			self.Nodes.Signals["Output"] = false
			return
		end

		if self.State.LastInput == nil then
			self.State.LastInput = current
			self.Nodes.Signals["Output"] = false
			return
		end

		if current ~= self.State.LastInput then
			self.State.LastInput = current
			self.State.PulseActive = true
			self.Nodes.Signals["Output"] = true
			Updates.ScheduleWakeup(self.Id, 0, { Source = "ResetPulse" }, "ResetPulse")
			return
		end

		self.Nodes.Signals["Output"] = self.State.PulseActive
	end,
}
