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

local ListElement = {}

local Theme = require("../../Theme")

local assets = script.Parent.Parent.Parent.Assets
local asset = assets.ListElement
local listAsset = assets.List

local function OnClicked(self: ListElement, callback: any): ListElement
    local element = self.instance
    self._clickedConnection = element.MouseButton1Down:Connect(function()
        callback()
    end)

    local theme = Theme.get()
    element.BackgroundColor3 = theme.UnselectedColor

    return self
end

local function newDestroyButton(): ImageButton
    local button = Instance.new("ImageButton")
    button.AutoButtonColor = false
    button.AnchorPoint = Vector2.new(1, 0.5)
    button.BorderSizePixel = 1
    button.Position = UDim2.new(1, -2, 0.5, 0)
    button.Size = UDim2.fromOffset(12, 12)
    button.ZIndex = 2

    return button
end

local function AddDestroyButton(self: ListElement, callback: any): ListElement
    local button = newDestroyButton()
    button.Parent = self.instance

    self._removedConnection =  button.MouseButton1Down:Connect(function()
        if callback then
            callback()
        end

        self._removedCallback()
        self:Destroy()
    end)

    self:UpdateTheme()
    return self
end

local function UpdateTheme(self: ListElement)
    local theme = Theme.get()
    
    local element = self.instance
    Theme.updateFrame(element)
    if self._clickedConnection then
        element.BackgroundColor3 = self.selected and theme.SelectedColor or theme.UnselectedColor
    end

    if self._removedConnection then
        local elementButton = (element :: any).ImageButton
        Theme.updateFrame(elementButton)
        elementButton.ImageColor3 = theme.XColor
        elementButton.BackgroundColor3 = theme.UnselectedColor
        elementButton.Image = theme.XImage
    end

    Theme.updateText(element.TextLabel, false)
end

local function Destroy(self: ListElement)
    if self._removedConnection then self._removedConnection:Disconnect() end
    if self._clickedConnection then self._clickedConnection:Disconnect() end

    self.instance:Destroy()

    table.clear(self :: any)
end

export type ListElement = {
    _clickedConnection: RBXScriptConnection?,
    _removedCallback: any,
    _removedConnection: RBXScriptConnection?,

    instance: typeof(asset),
    selected: boolean,

    OnClicked: typeof(OnClicked),
    AddDestroyButton: typeof(AddDestroyButton),
    UpdateTheme: typeof(UpdateTheme),
    Destroy: typeof(Destroy),
}

function ListElement.new(parent: typeof(listAsset.ScrollingFrame), removedCallback: any, value: string): ListElement
    local instance = asset:Clone()
    instance.TextLabel.Text = value

    local self: ListElement; self = {
        _removedCallback = removedCallback,

        instance = instance,

        OnClicked = OnClicked,
        AddDestroyButton = AddDestroyButton,
        UpdateTheme = UpdateTheme,
        Destroy = Destroy,
    } :: ListElement

    self:UpdateTheme()
    instance.Parent = parent

    return self
end

return ListElement