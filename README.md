### Signal

A pure Luau signal implementation, based on lemon-signal & robloxs signal-lua. With thread reuse as an option that can be used with the constructors.

#### example
```lua
local signal = require("@kalrnlo/Signal")

local regular_signal, fire = signal.create()

regular_signal:subscribe(function(...)
    print("signal was fired! wahoo!!", ...)
end)

fire("foo", "bar")

local value_signal, set = signal.value(10)

value_signal:once(function(val)
    print("i only print the next time this updates!", val)
end)

set(20)
set(30)
```

### api
#### constructors

```lua
create(reuse_threads, pre_allocate_threads)
```
- reuse_threads: boolean indicating whether or not the signal created should partake in thread reuse
- pre_allocate_threads: a number of threads to preallocate, by defualt 2

```lua
value<value>(value, reuse_threads, pre_allocate_threads)
```
- value: the starting value for the value signal,
value signals are diffrent in that they store a singular value, and the fire function is replaced with a set function to set the value.
- reuse_threads: boolean indicating whether or not the signal created should partake in thread reuse
- pre_allocate_threads: a number of threads to preallocate, by defualt 2

#### methods

```lua
signal:subscribe(callback)
```
- callback: a function that runs whenever the signal fires, with paramters that are the signals values

```lua
signal:wait()
```
Yields the current thread, and resumes the current thread with the values when the signal is fired next.

```lua
signal:once(callback)
```
Same as ```signal:subscribe()```, except for the fact it disconnects the callback after the next time the signal is fired
