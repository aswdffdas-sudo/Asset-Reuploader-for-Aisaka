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

local task = task or {
    spawn = function(fn, ...)
        local args = table.pack(...)
        coroutine.wrap(function()
            fn(table.unpack(args, 1, args.n))
        end)()
    end,
    wait = wait,
    delay = function(t, fn, ...)
        local args = table.pack(...)
        delay(t, function()
            fn(table.unpack(args, 1, args.n))
        end)
    end,
    defer = function(fn, ...)
        local args = table.pack(...)
        coroutine.wrap(function()
            fn(table.unpack(args, 1, args.n))
        end)()
    end,
}

local App = {}

local PLUGIN_ID = "rbxassetid://89096096219225"

local UiLibrary = require("./UiLibrary")

local currentVersion = script.Parent.Parent.Version.Value
local tabOrder = {
    "Animation",
    "Sound",
    "Mesh",
    "Gamepass",
    "Replace",
    "Filter",
    "Themes",
    "Settings"
}

local function getLatestVersion(): string
    local success, objects = pcall(game.GetObjects, game, PLUGIN_ID)
	if not success then return currentVersion end
	
	local latestPlugin = (objects :: any)[1]
	local latestVersion = latestPlugin.Version.Value
	latestPlugin:Destroy()

    return latestVersion
end

function App.init(ui: UiLibrary.Ui, plugin: Plugin)
    for _, tabName in pairs(tabOrder) do
        local tab = script.Tabs:FindFirstChild(tabName)
        assert(tab, "tab not found")
        task.spawn(require(tab), ui, plugin)
    end

    if currentVersion ~= getLatestVersion() then
        ui:Notify("Notification", "Plugin is out of date.")
    end
end

return App
