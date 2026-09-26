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

local Toggle = {}

local Theme = require("../Theme")
local Tip = require("../Tip")

local asset = script.Parent.Parent.Assets.Toggle

local function DoToggle(self: Toggle)
    self.state = not self.state
    self._callback(self.state)

    local theme = Theme.get()
    local button = self.instance.Button
    button.BackgroundColor3 = self.state and theme.ToggleBackgroundColor or theme.UnselectedColor
    button.ImageTransparency = self.state and 0 or 1
end

local function AddTip(self: Toggle, tip: Tip.Tip)
    local tipFrame = tip.instance
    local toggleFrame = self.instance
    tipFrame.Position = UDim2.new(0, toggleFrame.TextLabel.TextBounds.X + 5, 0.5, 0)
    tipFrame.Parent = toggleFrame.TextLabel

    self._tip = tip
end

local function UpdateTheme(self: Toggle)
    local toggleFrame = self.instance
    Theme.updateFrame(toggleFrame)        
    Theme.updateText(toggleFrame.TextLabel, false)

    local theme = Theme.get()
    local button = toggleFrame.Button
    button.BorderColor3 = theme.BorderColor
    button.BackgroundColor3 = self.state and theme.ToggleBackgroundColor or theme.UnselectedColor
    button.ImageTransparency = self.state and 0 or 1
    button.Image = theme.ToggleImage

    if self._tip then 
        self._tip:UpdateTheme() 
    end
end

local function Destroy(self: Toggle)
    if self._tip then self._tip:Destroy() end
    self.instance:Destroy()

    table.clear(self )
end

export type Toggle = {
    _tip: Tip.Tip?,
    _callback: any,

    state: boolean,
    instance: typeof(asset),

    Toggle: typeof(DoToggle),
    AddTip: typeof(AddTip),
    UpdateTheme: typeof(UpdateTheme),
    Destroy: typeof(Destroy),
}

function Toggle.new(parent: GuiObject, text: string, callback: any, defaultState: boolean?): Toggle
    local instance = asset:Clone()
    instance.TextLabel.Text = text

    local self: Toggle; self = {
        _callback = callback,

        state = false,
        instance = instance,

        Toggle = DoToggle,
        AddTip = AddTip,
        UpdateTheme = UpdateTheme,
        Destroy = Destroy,
    } 

    instance.Button.MouseButton1Down:Connect(function()
        self:Toggle()
    end)

    self:UpdateTheme()
    if defaultState then
        self:Toggle()
    end

    instance.Parent = parent
    
    return self
end

return Toggle