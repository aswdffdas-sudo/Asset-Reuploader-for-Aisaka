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

local Split = {}

local Input = require("./Input")
local Toggle = require("./Toggle")
local Button = require("./Button")

local function sizeElement(self: Split, instance: GuiObject)
    if #self._elements == 0 then
        instance.Size = UDim2.new(0.5, -5, 1, 0)
        instance.Parent = self.instance
    else
        instance.Size = UDim2.new(0.5, -5, 1, 0)
        instance.AnchorPoint = Vector2.new(1, 0)
        instance.Position = UDim2.new(1, 0, 0, 0)
        instance.Parent = self.instance
    end
end

local function CreateButton(self: Split, text: string, callback: any): Button.Button
    assert(#self._elements <= 2, "split can only have 2 elements")

    local button = Button.new(self.instance, text, callback)
    sizeElement(self, button.instance)
    table.insert(self._elements, button)
    return button
end

local function CreateInput(self: Split, placeholderText: string, callback: any): Input.Input
    assert(#self._elements <= 2, "split can only have 2 elements")

    local input = Input.new(self.instance, placeholderText, callback)
    sizeElement(self, input.instance)
    table.insert(self._elements, input)
    return input
end

local function CreateToggle(self: Split, text: string, callback: any, defaultState: boolean?): Toggle.Toggle
    assert(#self._elements <= 2, "split can only have 2 elements")

    local toggle = Toggle.new(self.instance, text, callback, defaultState)
    sizeElement(self, toggle.instance)
    table.insert(self._elements, toggle)
    return toggle
end

local function UpdateTheme(self: Split)
    for _, element in pairs(self._elements) do
        element:UpdateTheme()
    end
end

local function Destroy(self: Split)
    for _, element in pairs(self._elements) do
        element:Destroy()
    end
    table.clear(self._elements)

    self.instance:Destroy()

    table.clear(self )
end

export type Split = {
    _elements: { any },

    instance: Frame,

    CreateButton: typeof(CreateButton),
    CreateInput: typeof(CreateInput),
    CreateToggle: typeof(CreateToggle),
    UpdateTheme: typeof(UpdateTheme),
    Destroy: typeof(Destroy),
}

function Split.new(parent: GuiObject): Split
    local instance = Instance.new("Frame")
    instance.Size = UDim2.new(1, 0, 0, 20)
    instance.BackgroundTransparency = 1
    instance.Parent = parent

    return {
        _elements = {},

        instance = instance,

        CreateButton = CreateButton,
        CreateInput = CreateInput,
        CreateToggle = CreateToggle,
        UpdateTheme = UpdateTheme,
        Destroy = Destroy,
    }
end

return Split
