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
	
	Setup = function(self, state)
		if state.Internal then
			self.InternalState = { IsActivated = if state.Internal.IsActivated ~= nil then state.Internal.IsActivated else false }
			if state.Internal.IsActivated then Updates.ScheduleWakeup(self.ID, self.Attributes.Duration, { Source = "TimerExpired"}, "Timer" ) end
		else
			self.InternalState = { IsActivated = false }
		end
		
		self.BUTTON = {}
		self.BUTTON.Main = self.Model.Main
		self.BUTTON.ClickDetector = if self.OwnerID ~= 0
			then (function() local c = Instance.new("ClickDetector"); c.Parent = self.Model; return c end)()
			else nil
		self.BUTTON.ClickDetectorConnection = if self.OwnerID ~= 0
			then self.BUTTON.ClickDetector.MouseClick:Connect(function(player) Updates.Propagate(self.ID, { Source = "Interaction", Player = player }) end)
			else nil
		-- TODO: Store how long until the timer finishes. Better Load handling with this.
		
		self.BUTTON.Main.Position = self.Model.Base:GetPivot().Position + if self.InternalState.IsActivated then Vector3.new(0, 0.7, 0) else Vector3.new(0, 0.85, 0)
		self.Nodes.Signals["Output"] = self.InternalState.IsActivated
	end,
	
	Process = function(self, payload)
		if not payload then return end
		
		if payload.Source == "Interaction" then
			if not self.Attributes.IsClickable or self.InternalState.IsActivated then return end
			
			self.InternalState.IsActivated = true
			Updates.ScheduleWakeup(self.ID, self.Attributes.Duration, { Source = "TimerExpired"}, "Timer" )
		end
		
		if payload.Source == "TimerExpired" then
			self.InternalState.IsActivated = false
		end
		
		self.BUTTON.Main.Position = self.Model.Base:GetPivot().Position + if self.InternalState.IsActivated then Vector3.new(0, 0.7, 0) else Vector3.new(0, 0.85, 0)
		self.Nodes.Signals["Output"] = self.InternalState.IsActivated
	end,
	
	Destroy = function(self)
		Updates.CancelAllWakeups(self.ID)
		if self.BUTTON.ClickDetectorConnection then
			self.BUTTON.ClickDetectorConnection:Disconnect()
			self.BUTTON.ClickDetectorConnection = nil
		end
	end
}
