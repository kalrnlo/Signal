--!optimize 2
--!strict
--!native

-- Signal
-- yet another signal module, based on roblox's signal-lua
-- and LemonSignal
-- @Kalrnlo
-- 25/02/2024

type Callback<T...> = (...T) -> ()

export type Signal<T...> = {
	Connect: (self: Signal<T...>, Callback: Callback<T...>) -> () -> (),
	Once: (self: Signal<T...>, Callback: Callback<T...>) -> () -> (),
	Clear: (self: Signal<T...>) -> (),
	Wait: (self: Signal<T...>) -> T...,

	Connections: {Connection<T...> | thread}
}

export type FrozenSignal<T...> = {
	Connect: (self: Signal<T...>, Callback: Callback<T...>) -> () -> (),
	Once: (self: Signal<T...>, Callback: Callback<T...>) -> () -> (),
	Wait: (self: Signal<T...>) -> T...,
}

type Sender<T...> = typeof(setmetatable({} :: {Signal<T...>}, {} :: SenderPrototype))

type Connection<T...> = typeof(setmetatable({} :: {
	["1"]: Callback<T...>,
	["2"]: Signal<T...>,
}, {} :: ConnectionPrototype))

type ConnectionPrototype<T...> = {
	__call: (self: Connection<T...>) -> ()
}

type SenderPrototype<T...> = {
	__call: (self: Sender<T...>, ...T) -> ()
}

local function Resume<T...>(Thread: thread, ...: T...)
	local Success, Message = coroutine.resume(Thread, ...)

	if Sucess == false then
		print(`[Signal] Could not resume thread, {Message}\nTrace: {debug.traceback()}`)
	end
end

local TaskSpawn = if task then task.spawn else Resume
local FreeThreads = {} :: {thread}

local function RunCallback(Callback, Thread, ...)
	Callback(...)
	table.insert(FreeThreads, thread)
end

local function Yielder()
	while true do
		RunCallback(coroutine.yield())
	end
end

local function Connection_Call<T...>(self: Connection<T...>)
	self[1] = function() end
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

local function Sender_Call<T...>(self: Sender<T...>, ...: T)
	for _, ConnectionOrThread in self[1].Connections do
		if typeof(ConnectionOrThread) == "table" then 
			local Value: Callback<T...> = ConnectionOrThread[1] :: any

			if #FreeThreads > 0 then
				local Thread = FreeThreads[#FreeThreads]
				FreeThreads[#FreeThreads] = nil
				TaskSpawn(Thread, Value, Thread, ...)
			else
				local Thread = coroutine.create(Yielder)
				coroutine.resume(Thread)
				TaskSpawn(Thread, Value, Thread, ...)
			end
		else
			TaskSpawn(ConnectionOrThread, ...)
		end
	end
end

local SenderPrototype = {
	__call = Sender_Call,
}
SenderPrototype.__index = SenderPrototype

local function Signal_Connect<T...>(self: Signal<T...>, Callback: Callback<T...>)
	local Refrences = table.create(2)
	Refrences[1] = Callback
	Refrences[2] = self

	local Connection = setmetatable(Refrences, ConnectionPrototype)
	self.Connections[#self.Connections + 1] = Connection
	return Connection
end

local function Signal_Once<T...>(self: Signal<T...>, Callback: Callback<T...>)
	local Disconnect
	Disconnect = Signal_Connect(self, function(...: T)
		Callback(...)
		Disconnect()
	end)
	return Disconnect
end

local function Signal_Clear<T...>(self: Signal<T...>)
	table.clear(self.Connections)
end

local function Signal_Wait<T...>(self: Signal<T...>)
	self.Connections[#self.Connections + 1] = coroutine.running()
	return coroutine.yield()
end

local FrozenSignalPrototype = {
	Connect = Signal_Connect,
	Once = Signal_Once,
	Wait = Signal_Wait,
}
FrozenSignalPrototype.__index = FrozenSignalPrototype

local SignalPrototype = {
	Connect = Signal_Connect,
	Clear = Signal_Clear,
	Once = Signal_Once,
	Wait = Signal_Wait,
}
SignalPrototype.__index = SignalPrototype

local function CreateFrozenSignal<T...>(): (FrozenSignal<T...>, (...T) -> ())
	local self = setmetatable({Connections = {}}, FrozenSignalPrototype)
	return self, setmetatable(table.create(1, self), SenderPrototype)
end

local function CreateSignal<T...>(): (Signal<T...>, (...T) -> ())
	local self = setmetatable({Connections = {}}, SignalPrototype)
	return self, setmetatable(table.create(1, self), SenderPrototype)
end

local Exports = table.freeze({
	frozen = CreateFrozenSignal,
	new = CreateSignal,
})

return Exports