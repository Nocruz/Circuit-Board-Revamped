--[[ CLIPBOARD REGISTRY
		Not a service per se, but a local registry of the saves.
		Used to improve UX and fasten the UI startup.
]]

-- Requires and Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local getSavesDataQuery: RemoteFunction = ReplicatedStorage:WaitForChild("Client"):WaitForChild("Queries"):WaitForChild("GetSavesData")

local SavesRegistry = {}
SavesRegistry.IsLoaded = false
SavesRegistry.Data = {}

SavesRegistry._isLoading = false
SavesRegistry._loadedEvent = Instance.new("BindableEvent")

-- Fetches data from the server. If already fetched, returns instantly.
-- If currently fetching, yields until the ongoing fetch is complete.
function SavesRegistry:LoadAsync()
	if self.IsLoaded then 
		return true, self.Data 
	end
	
	if self._isLoading then
		self._loadedEvent.Event:Wait()
		return self.IsLoaded, self.Data
	end
	
	self._isLoading = true
	
	local success, result = getSavesDataQuery:InvokeServer()
	if success then
		self.Data = result
		self.IsLoaded = true
	end
	
	self._isLoading = false
	self._loadedEvent:Fire()
	
	return success, result
end

function SavesRegistry:GetAllSaves()
	return self.Data
end

function SavesRegistry:GetSave(name: string)
	return self.Data[name]
end

function SavesRegistry:AddSave(name: string, saveData: any)
	self.Data[name] = saveData
end

function SavesRegistry:RemoveSave(name: string)
	self.Data[name] = nil
end

return SavesRegistry
