local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Updates = require(ServerScriptService.GateService.Updates)

local function checkForPlayers(plate: Part): number
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	
	local chars = {}
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		if p.Character then table.insert(chars, p.Character) end
	end
	params.FilterDescendantsInstances = chars
	
	if not plate or not plate.Parent then return 0 end
	
	local total = 0
	local seen = {}
	for _, part in ipairs(workspace:GetPartsInPart(plate, params)) do
		local char = part.Parent
		local p = char and Players:GetPlayerFromCharacter(char)
		if p and not seen[p.UserId] then
			seen[p.UserId] = true
			total += 1
		end
	end
	return total
end

return {
	Nodes = { Outputs = { "Output" }, Inputs = { } },
	DefaultVisuals = {
		PrefabName = "Plate",
		MainColor = Color3.fromRGB(40, 140, 250)
	},
	
	AttributeData = {
		["IsPressable"] = { Default = true, Predicates = { } },
	},
	
	Setup = function(self)
		self.PRESSURE = {}
		self.PRESSURE.Weld = self.Model.Main.Weld
		self.PRESSURE.Hitbox = self.Model.Hitbox :: Part
		self.PRESSURE.IsActiveLoop = false
		
		if self.OwnerID == 0 then return end
		
		self.PRESSURE.IsActiveLoop = true
		task.spawn(function()
			local currentlyPropagatedTrue = false
			
			while self.PRESSURE.IsActiveLoop do
				task.wait(0.1)
				if not self.PRESSURE.Hitbox or not self.PRESSURE.Hitbox.Parent then break end
				
				local playersOnPlate = checkForPlayers(self.PRESSURE.Hitbox)
				if playersOnPlate > 0 then
					if not currentlyPropagatedTrue then
						currentlyPropagatedTrue = true
						Updates.Propagate(self.ID, { Boolean = true })
					end
				else
					if currentlyPropagatedTrue then
						currentlyPropagatedTrue = false
						Updates.Propagate(self.ID, { Boolean = false })
					end
				end
			end
		end)
		
		self.Nodes.Signals["Output"] = checkForPlayers(self.PRESSURE.Hitbox) > 0
		
		local offset = if self.Nodes.Signals["Output"] then 0.5 else 0.75
		self.PRESSURE.Weld.C1 = CFrame.new(0, offset, 0)
		
		if self.Nodes.Signals["Output"] then self:QueueSound("Activate Activator") end
	end,
	
	Process = function(self, payload)
		if not payload then return end
		
		if payload.Boolean then
			if not self.Attributes.IsPressable then return end
			self:QueueSound("Activate Activator")
			self.Nodes.Signals["Output"] = true
		else
			self:QueueSound("Deactivate Activator")
			self.Nodes.Signals["Output"] = false
		end
		
		local offset = if self.Nodes.Signals["Output"] then 0.5 else 0.75
		self.PRESSURE.Weld.C1 = CFrame.new(0, offset, 0)
	end,
	
	Destroy = function(self)
		Updates.CancelAllWakeups(self.ID)
		self.PRESSURE.IsActiveLoop = false
	end
}
