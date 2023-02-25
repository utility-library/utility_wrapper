_exports = exports
local metaExports = getmetatable(exports)
local eventHooks = {}

local utilityWrapper = exports["utility_wrapper"]
Config = utilityWrapper:getConfig()

function getObject(from)
    local to = Config.Framework

    if from == to then -- if the resource requires the same framework load it as usual
        print("loading framework ("..from..")")
        local method = utilityWrapper:getMethodName(from)

        -- using the old exports variable to call the original framework export 
        return _exports[Config.FrameworkResourceName][method]()

    else -- else get the wrapper
        print("loading wrapper from "..from.." to "..to)
        -- the wrapper is pre-loaded for ease of fixing bugs (stack traceback from the load function was quite useless)
        local wrapper = utilityWrapper:getWrapper(from, to)
        local loaded = wrapper()
        
        eventHooks = loaded.events
        return loaded.object
    end
end

-- hook the esx and qbcore exports
exports = setmetatable({}, {
    __index = function(t, k)
        local resource = k

        return setmetatable({}, {
            __index = function(t, method)
                for k,v in pairs(Config.MethodNames) do
                    if method == v then
                        return function()
                            return getObject(k)
                        end
                    end
                end

                return metaExports.__index(t, k)[method]
            end,

            __newindex = function(t, k, v)
				error('cannot set values on an export resource', 2)
			end
        })
    end,
    __newindex = metaExports.__newindex,
    __call = metaExports.__call,
})


-- Event hooks
local HookEvent = function(func, cb, eventHook)
    if type(eventHook) == "string" then
        func(eventHook, cb)
    else
        if eventHook.faker then
            eventHook.faker(cb)
        else
            func(eventHook.name, function(...)
                eventHook.hook(cb, ...)
            end)
        end
    end
end

local _RegisterNetEvent = RegisterNetEvent
RegisterNetEvent = function(eventName, cb)
    if cb then
        if eventHooks[eventName] then
            HookEvent(_RegisterNetEvent, cb, eventHooks[eventName])
        else
            _RegisterNetEvent(eventName, cb)
        end
    else
        _RegisterNetEvent(eventName)
    end
end

local _AddEventHandler = AddEventHandler
AddEventHandler = function(eventName, cb)
    if eventHooks[eventName] then
        HookEvent(_AddEventHandler, cb, eventHooks[eventName])
    else
        _AddEventHandler(eventName, cb)
    end
end