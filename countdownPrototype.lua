--[[
Authors:    Ziffix, Chavez
Version:    1.2.4 (semi-stable, needs another test)
Date:       23/2/20
]]



local httpService = game:GetService("HttpService")

local countdown = {}
local countdownPrototype = {}
local countdownPrivate = {}



--[[
@param    condition   any       | The result of the condition
@param    message     string    | The error message to be raised
@param    level = 1   number?   | The level at which to raise the error
@return               void
Implements assert with error's level argument.
]]
local function _assertLevel(condition: any, message: string, level: number?)
	assert(condition, "Argument #1 missing or nil.")
	assert(message, "Argument #2 missing or nil.")

	level = (level or 0) + 1

	if condition then
		return condition
	end

	error(message, level)
end


--[[
@param    countdown    Countdown   | The countdown object
@return                void
Handles core countdown process.
]]
local function _countdownStart(countdown: Countdown)
	_assertLevel(countdown, "Argument #1 missing or nil.", 1)

	local private = countdownPrivate[countdown]

	local secondsElapsed = 0
	local secondsLeft = private.duration

	while secondsLeft > 0 do  
		while secondsElapsed < 1 do
			secondsElapsed += task.wait()

			if private.active then
				continue
			end

			coroutine.yield()
		end

		secondsElapsed = 0
		secondsLeft -= 1

		-- Countdown object was destroyed
		if private.tick == nil then
			return
		end

		private.tick:Fire(secondsLeft)
		private.secondsLeft = secondsLeft

		for _ in private.taskRemovalQueue do
			table.remove(private.tasks, table.remove(private.taskRemovalQueue, 1))
		end

		for _, taskInfo in private.tasks do
			if secondsLeft % taskInfo.interval ~= 0 then
				continue
			end
			
			if secondsLeft ~= 0 then
				task.spawn(taskInfo.callback, secondsLeft, table.unpack(taskInfo.args))
			end
		end
	end

	-- Countdown object was destroyed
	if private.finished == nil then
		return
	end

	private.finished:Fire()
end


--[[
@param    duration    number      | The duration of the countdown
@return               countdown   | The generated Countdown object
Generates a countdown object.
]]
function countdown.new(duration: number): Countdown
	_assertLevel(duration, "Argument #1 missing or nil.", 1)
	_assertLevel(duration % 1 == 0, "Expected integer, got decimal.", 1)

	local self = {}
	local private = {}

	private.duration = duration
	private.secondsLeft = duration

	private.active = false
	private.thread = nil

	private.tasks = {}
	private.taskRemovalQueue = {}

	private.tick = Instance.new("BindableEvent")
	private.finished = Instance.new("BindableEvent")

	self.tick = private.tick.Event
	self.finished = private.finished.Event

	countdownPrivate[self] = private

	return setmetatable(self, countdownPrototype)
end


--[[
@return   void
Begins synchronous countdown process.
]]
function countdownPrototype:start()
	local private = _assertLevel(countdownPrivate[self], "Cooldown object is destroyed", 1)

	private.active = true
	private.thread = task.spawn(_countdownStart, self)
end


--[[
@return   void
Pauses the countdown process.
]]
function countdownPrototype:pause()
	local private = _assertLevel(countdownPrivate[self], "Cooldown object is destroyed", 1)

	if private.active == false then
		warn("Countdown process is already paused.")

		return
	end

	private.active = false
end


--[[
@return   void
Resumes the countdown process.
]]
function countdownPrototype:resume()
	local private = _assertLevel(countdownPrivate[self], "Cooldown object is destroyed", 1)

	if private.active then
		warn("Countdown process is already active.")

		return
	end

	private.active = true

	coroutine.resume(private.thread)
end


--[[
@param    interval    number      | The interval at which the callback executes
@param    callback    function    | The function to be ran at the given interval
@return               string      | The GUID representing the task
Compiles interval and callback data into task repository.
]]
function countdownPrototype:addTask(interval: number, callback: (number?, ...any) -> (), ...): string
	_assertLevel(interval, "Argument #1 missing or nil.", 1)
	_assertLevel(callback, "Argument #2 missing or nil.", 1)
	_assertLevel(interval % 1 == 0, "Expected integer, got decimal.", 1)

	local private = _assertLevel(countdownPrivate[self], "Cooldown object is destroyed", 1)

	local taskInfo = {
		
		args = {...},
		interval = interval,
		callback = callback,
		id = httpService:generateGUID()

	}

	table.insert(private.tasks, taskInfo)

	return taskInfo.id
end


--[[
@param	taskId	number	| the id assigned to a specifc task
find the specific task related to the given task id and pauses that task.
]]
function countdownPrototype:pauseTask(taskId: number)
	_assertLevel(taskId, "Argument #1 missing or nil", 1)
	
	local private = _assertLevel(countdownPrivate[self], "Cooldown object is destroyed", 1)
	
	for i = 1, #private.tasks do
		local scannedTask = private.tasks[i]
		
		if scannedTask.id ~= taskId then
			continue 
		end
		
		private.tasks[i].paused = true

		return
	end
	
	error("Could not find a task by the given ID.", 2)
end


--[[
@param    taskId    string    | The ID generated by countdown:addTask()
@return             void
Queues the associated task to be removed from the task repository.
]]
function countdownPrototype:removeTask(taskId: string)
	_assertLevel(taskId, "Argument #1 missing or nil.", 1)

	local private = _assertLevel(countdownPrivate[self], "Cooldown object is destroyed", 1)

	for index, taskInfo in private.tasks do
		if taskInfo.id ~= taskId then
			continue
		end

		table.insert(private.taskRemovalQueue, index)

		return
	end

	error("Could not find a task by the given ID.", 2)
end


--[[
@return   number    | The duration of the countdown
Returns the duration of the countdown.
]]
function countdownPrototype:getDuration(): number
	local private = _assertLevel(countdownPrivate[self], "Cooldown object is destroyed", 1)

	return private.duration
end


--[[
@return   number    | The seconds remaining in the countdown
Returns the seconds remaining in the countdown.
]]
function countdownPrototype:getSecondsLeft(): number
	local private = _assertLevel(countdownPrivate[self], "Cooldown object is destroyed", 1)

	return private.secondsLeft
end


--[[
@return   boolean    | The active state of the countdown process
Returns a boolean detailing whether or not the countdown process is active.
]]
function countdownPrototype:isPaused(): boolean
	local private = _assertLevel(countdownPrivate[self], "Cooldown object is destroyed", 1)

	return private.active
end


--[[
@return   void
Cleans up object data.
]]
function countdownPrototype:destroy()
	local private = _assertLevel(countdownPrivate[self], "Cooldown object is destroyed", 1)
	
	if coroutine.status(private.thread) == "suspended" then
		coroutine.close(private.thread)
	end

	private.tick:Destroy()
	private.finished:Destroy()

	table.clear(private.tasks)

	countdownPrivate[self] = nil
end



countdownPrototype.__index = countdownPrototype
countdownPrototype.__metatable = "This metatable is locked."

export type Countdown = typeof(countdown.new(0))

return countdown
