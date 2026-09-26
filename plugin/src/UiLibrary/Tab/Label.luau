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
local task = {
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

local Label = {}

local Theme = require("../Theme")

local assets = script.Parent.Parent.Assets
local buttonAsset = assets.Button
local asset = assets.List

local function ChangeText(self: Label, newText: string)
    self.instance.Text = newText
end

local function UpdateTheme(self: Label)
    Theme.updateText(self.instance, true)
end

local function Destroy(self: Label)
    self.instance:Destroy()

    table.clear(self )
end

export type Label = {
    instance: typeof(buttonAsset),
    
    ChangeText: typeof(ChangeText),
    UpdateTheme: typeof(UpdateTheme),
    Destroy: typeof(Destroy),
}

function Label.new(parent: typeof(asset), text: string): Label
    local instance = buttonAsset:Clone()
    instance.Text = text

    local self: Label = {
        instance = instance,

        ChangeText = ChangeText,
        UpdateTheme = UpdateTheme,
        Destroy = Destroy,
    }

    self:UpdateTheme()
    instance.Parent = parent

    return self
end

return Label
