--!optimize 2
--!strict
--!native

-- Signal
-- yet another signal module although without ordering,
-- infact this signal is so anti-ordering that it uses swap removal
-- based on roblox's signal-lua and LemonSignal.
-- @Kalrnlo
-- 25/02/2024

type Sender<T...> = typeof(setmetatable({} :: {Signal<T...>}, {} :: SenderPrototype))

type Connection<T...> = typeof(setmetatable({} :: {
	["1"]: Callback<T...>,
	["2"]: Signal<T...>,
	["3"]: boolean?,
}, {} :: ConnectionPrototype))

type ConnectionPrototype<T...> = {
	__call: (self: Connection<T...>) -> ()
}

type SenderPrototype<T...> = {
	__call: (self: Sender<T...>, ...T) -> ()
}

type Connections<T...> = {Connection<T...> | thread}

type Callback<T...> = (...T) -> ()

export type ReadableSignal<Value> = Signal<Value> & {Value: Value}

export type Signal<T...> = {
	Subscribe: (self: Signal<T...>, Callback: Callback<T...>) -> () -> (),
	Once: (self: Signal<T...>, Callback: Callback<T...>) -> () -> (),
	Wait: (self: Signal<T...>) -> T...,
	Connections: {Connection<T...> | thread | {Callback<T...>}},
}

type ConnectionPrototype<T...> = {
	__call: (self: Connection<T...>) -> ()
}

type SenderPrototype<T...> = {
	__call: (self: Sender<T...>, ...T) -> ()
}

local function Resume<T...>(Thread: thread, ...: T...)
	local Success, Message = coroutine.resume(Thread, ...)

	if Sucess == false then
		coroutine.wrap(error)(
			debug.traceback(`[Signal] Could not resume thread, Message: {Message}`, 3), 3
		)
	end
end

local TaskSpawn = if task then task.spawn else Resume
local FreeThreads = {} :: {thread}
local Empty = function() end

local function RunCallback(Callback, Thread, ...)
	Callback(...)
	table.insert(FreeThreads, thread)
end

local function Yielder()
	while true do
		RunCallback(coroutine.yield())
	end
end

--------------------------------------------------------------------------------
-- Connection
--------------------------------------------------------------------------------

local function Connection_Call<T...>(self: Connection<T...>)
	self[1] = Empty
	local Signal = self[2] :: Signal<T...>
	local Index = table.find(Signal.Connections, self)

	if Index then
		local Length = #Signal.Connections

		if Length > 1 then
			Signal.Connections[Index] = Signal.Connections[Length]
			Signal.Connections[Length] = nil
		else
			Signal.Connections[Index] = nil
		end
	end
end

local ConnectionPrototype = {
	__call = Connection_Call,
}
ConnectionPrototype.__index = ConnectionPrototype

--------------------------------------------------------------------------------
-- Sender
--------------------------------------------------------------------------------

local function RunConnections<T...>(Connections: {Connection<T...> | thread}, ...: T)
	for Index, ConnectionOrThread in Connections do
		if typeof(ConnectionOrThread) == "table" then 
			local Callback: Callback<T...> = ConnectionOrThread[1] :: any

			if #FreeThreads > 0 then
				local Thread = FreeThreads[#FreeThreads]
				FreeThreads[#FreeThreads] = nil
				TaskSpawn(Thread, Callback, Thread, ...)
			else
				local Thread = coroutine.create(Yielder)
				coroutine.resume(Thread)
				TaskSpawn(Thread, Callback, Thread, ...)
			end

			if #ConnectionOrThread == 3 then
				if #Connections > 1 then
					Connections[Index] = Connections[#Connections]
					Connections[#Connections] = nil
				else
					Connections[Index] = nil
				end
			end
		else
			TaskSpawn(ConnectionOrThread, ...)

			if #Connections > 1 then
				Connections[Index] = Connections[#Connections]
				Connections[#Connections] = nil
			else
				Connections[Index] = nil
				return
			end
		end
	end
end

local function ReadableSender_Call<T>(self: Sender<T>, Value: T)
	local Signal = self[1]
	Signal.Value = Value
	RunConnections(Signal.Connections, Value)
end

local function Sender_Call<T...>(self: Sender<T...>, ...: T)
	RunConnections(self[1].Connections, ...)
end

local ReadableSenderPrototype = {
	__call = ReadableSender_Call,
}
ReadableSenderPrototype.__index = ReadableSenderPrototype

local SenderPrototype = {
	__call = Sender_Call,
}
SenderPrototype.__index = SenderPrototype

--------------------------------------------------------------------------------
-- Signal
--------------------------------------------------------------------------------

local function Signal_Subscribe<T...>(self: Signal<T...>, Callback: Callback<T...>)
	local Refrences = table.create(2)
	Refrences[1] = Callback
	Refrences[2] = self

	local Connection = setmetatable(Refrences, ConnectionPrototype)
	self.Connections[#self.Connections + 1] = Connection
	return Connection
end

local function Signal_Once<T...>(self: Signal<T...>, Callback: Callback<T...>)
	local Refrences = table.create(3)
	Refrences[1] = Callback
	Refrences[2] = self
	Refrences[3] = true

	local Connection = setmetatable(Refrences, ConnectionPrototype)
	self.Connections[#self.Connections + 1] = Connection
	return Connection
end

local function Signal_Wait<T...>(self: Signal<T...>)
	self.Connections[#self.Connections + 1] = coroutine.running()
	return coroutine.yield()
end

local SignalPrototype = {
	Subscribe = Signal_Subscribe,
	Once = Signal_Once,
	Wait = Signal_Wait,
}
SignalPrototype.__index = SignalPrototype

local function CreateSignal<T...>(): (Signal<T...>, (...T) -> ())
	local self = setmetatable({Connections = {}}, SignalPrototype)
	return self, setmetatable(table.create(1, self), SenderPrototype)
end

local function CreateReadableSignal<Value>(Value: Value): (ReadableSignal<Value>, (NewValue: Value) -> ())
	local self = setmetatable({Connections = {}, Value = Value}, SignalPrototype)
	return self, setmetatable(table.create(1, self), ReadableSenderPrototype)
end

local Exports = {
	readable = CreateReadableSignal,
	create = CreateSignal,
}

return Exports