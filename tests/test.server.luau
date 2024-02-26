local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Signal)
local ValueSig, set = Signal.value("lol")
local Sig, Fire = Signal.create()

assert(ValueSig.Value == "lol", "Value is not 'lol'")
ValueSig:Subscribe(function(Value)
    print("value sig value is now:", Value)
end)
Sig:Subscribe(print)
Sig:Once(print)

coroutine.wrap(function()
    Sig:Wait()
    print("signal fired!")
end)()

Fire("lmao")
Fire("lol")

coroutine.wrap(function()
    ValueSig:Wait()
    print("value signal fired!")
end)()

set("hahaha")
set("lol")