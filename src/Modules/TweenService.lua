local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local runningTweens = {}
local Class = {}
Class.__index = Class

local function Constructor(Inst: Instance, tweenInfo: TweenInfo, propertyTable: table)
	local self = setmetatable({}, Class)

	self._id = HttpService:GenerateGUID(false)
	self._instance = Inst
	self._dontCare = propertyTable["ignoreCaching"] or false

	propertyTable["ignoreCaching"] = nil

	self._tween = TweenService:Create(Inst, tweenInfo, propertyTable)
	self._callback = function() end
	self._connection = self._tween.Completed:Connect(function(playBackState)
		if playBackState == Enum.PlaybackState.Completed then
			runningTweens[self._instance] = nil
		end

		return self._callback(playBackState)
	end)

	return self
end

-- Plays the tween and caches it.
function Class:Play()
	self:Pause()
	self._tween:Play()

	if not self._dontCare then
		runningTweens[self._instance] = self
	end
end

-- Pauses the tween and removes it from cache.
function Class:Pause()
	local exist = runningTweens[self._instance]

	if exist == nil or exist._id == self._id then
		self._tween:Pause()
		runningTweens[self._instance] = nil
		return
	end

	exist:Pause()
	exist:Destroy()

	--if runningTweens[self._instance] ~= nil then
	--	runningTweens[self._instance]._tween:Pause()
	--	runningTweens[self._instance] = nil
	--end
end

-- Overwrites the callback function when completed.
function Class:setCallback(Func: (playbackState: Enum.PlaybackState) -> ())
	assert(typeof(Func) == "function", "'Func' can only be a function!")
	self._callback = Func
end

-- Destroys the class.
function Class:Destroy()
	self._destroyed = true
	self._tween:Destroy()
	self._connection:Disconnect()

	setmetatable(self, nil)
	self = nil
end

-- Cancels the tween and removes from cache.
function Class:Cancel()
	self._tween:Cancel()
end

return Constructor
