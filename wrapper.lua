_exports = exports
local metaExports = getmetatable(exports)

local utilityWrapper = exports["utility_wrapper"]
Config = utilityWrapper:getConfig()

function getObject(from)
    local to = Config.Framework

    if from == to then -- if the resource requires the same framework load it as usual
        print("loading normal framework ("..from..")")
        local method = utilityWrapper:getMethodName(from)
        return _exports[Config.FrameworkResourceName][method]()

    else -- else get the wrapper file and load it
        print("loading wrapper from "..from.." to "..to)

        local wrapper = utilityWrapper:getWrapperFile(from, to) 
        return load(wrapper)()
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