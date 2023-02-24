exports("getConfig", function()
    return Config
end)

local wrappersCache = {}
exports("getWrapperFile", function(from, to)
    if not wrappersCache[from] then
        wrappersCache[from] = {}
    end
    
    if not wrappersCache[from][to] then
        wrappersCache[from][to] = LoadResourceFile(GetCurrentResourceName(), "wrappers/"..from.."/"..to..".lua")
    end

    return wrappersCache[from][to]
end)


exports("getMethodName", function(framework)
    return Config.MethodNames[framework]
end)