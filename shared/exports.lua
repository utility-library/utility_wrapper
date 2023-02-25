Wrappers = {}

exports("getConfig", function()
    return Config
end)

exports("getWrapper", function(from, to)
    return Wrappers[from][to]
end)

exports("getMethodName", function(framework)
    return Config.MethodNames[framework]
end)

-- We use Config.MethodNames as if it were a list of supported frameworks to create all the support tables (getWrapper "from" parameter) for the various wrappers 
for k,v in pairs(Config.MethodNames) do
    Wrappers[k] = {}
end