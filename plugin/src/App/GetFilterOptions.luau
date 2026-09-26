--!strict
local _old_require = require
local function require(target)
    if typeof(target) == "string" then
        local moduleName = string.match(target, "([^/]+)$") or target
        local found = script:FindFirstChild(moduleName, true)
        if not found and script.Parent then
            found = script.Parent:FindFirstChild(moduleName, true)
        end
        if not found then
            local root = script:FindFirstAncestor("Plugin") or script
            if root.Name ~= "Plugin" and root:FindFirstChild("Plugin") then
                root = root:FindFirstChild("Plugin")
            end
            found = root:FindFirstChild(moduleName, true)
        end
        if not found then
            local folder = script:FindFirstAncestor("AssetReuploader")
            if folder then
                found = folder:FindFirstChild(moduleName, true)
            end
        end
        if found and found:IsA("ModuleScript") then
            return _old_require(found)
        end
        error("Could not find ModuleScript for: " .. tostring(target))
    end
    return _old_require(target)
end

local _unpack = unpack
local task = task or {
    spawn = function(fn, ...)
        coroutine.wrap(fn)(...)
    end,
    wait = wait,
    delay = function(t, fn, ...)
        local args = {...}
        delay(t, function()
            fn(_unpack(args))
        end)
    end,
    defer = function(fn, ...)
        coroutine.wrap(fn)(...)
    end,
}

local AssetIdFilter = require("./AssetIdFilter")

local pluginSettings: { [string]: { string } } = {
    StrVals = { "StringValue" },
    Scripts = { "LuaSourceContainer" },
    NumVals = { "NumberValue", "IntValue" }
}

return function(plugin: Plugin, filteredInstances: { Instance }): AssetIdFilter.FilterOptions
    local instanceArray: { string } = {}
    for settingName, classNames in pairs(pluginSettings) do
        if not plugin:GetSetting(settingName) then continue end

        for _, className in pairs(classNames) do
            table.insert(instanceArray, className)
        end
    end

    return {
        WhitelistedInstances = instanceArray,
        Instances = filteredInstances
    }
end
