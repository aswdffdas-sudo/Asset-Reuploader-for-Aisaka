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

local UiLibrary = require("../../UiLibrary")

return function(ui: UiLibrary.Ui, plugin: Plugin)
    local tab = ui:CreateTab("Settings")

    local split = tab:CreateSplit()
    local portInput; portInput = split:CreateInput("Port: " .. plugin:GetSetting("Port"), function(input)
        local newPort = tonumber(input)
        if not newPort then return end

        if newPort < 1024 or newPort > 49151 then
            ui:Notify("Notification", "Port has to be between 1024-49151.")
            return
        end

        plugin:SetSetting("Port", newPort)
        portInput.instance.TextBox.PlaceholderText = "Port: " .. newPort
    end)
    split:CreateToggle("Export json when done", function(state)
        plugin:SetSetting("ExportJSON", state)
    end, plugin:GetSetting("ExportJSON"))
end
