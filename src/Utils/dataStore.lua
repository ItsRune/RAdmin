local DataStoreService = game:GetService("DataStoreService")

local dataStore = {}
local Class = {}
Class.__index = Class

--// Public Functions \--
function dataStore.new(dataStoreName: string, isOrdered: boolean)
	local self = setmetatable({}, Class)
	local method = isOrdered and "GetOrderedDataStore" or "GetDataStore"

	self._dataStore = DataStoreService[method](DataStoreService, dataStoreName)
	self.Cache = {}

	return self
end

--// Private Functions \--
function Class:Get<T>(Player: Player, defaultData: T, force: boolean?): T
	local existingData = self.Cache[Player.UserId]
	if not force and existingData ~= nil then
		return existingData
	end

	local isOk, response = pcall(self._dataStore.GetAsync, self._dataStore, tostring(Player.UserId))
	if not isOk then
		task.wait(5)
		return self:Get(Player, defaultData, force)
	end

	response = response or defaultData
	self.Cache[Player.UserId] = response

	return response
end

function Class:_internalSave<T>(Mode: "Set" | "Update", Player: Player, Data: T?): boolean
	local existingData = self.Cache[Player.UserId]
	if not existingData and not Data then
		return false
	end

	local saveMethod = (Mode == "Set") and Data or function()
		return Data
	end

	return pcall(self._dataStore[Mode .. "Async"], self._dataStore, tostring(Player.UserId), saveMethod)
end

function Class:Set<T>(Player: Player, Data: T?): boolean
	return self:_internalSave("Set", Player, Data)
end

function Class:Update<T>(Player: Player, Data: T?): boolean
	return self:_internalSave("Update", Player, Data)
end

function Class:userLeft(Player: Player): ()
	self.Cache[Player.UserId] = nil
end

function Class:Destroy()
	table.clear(self)
	setmetatable(self, nil)
	self = nil
end

--// Return \--
return dataStore
