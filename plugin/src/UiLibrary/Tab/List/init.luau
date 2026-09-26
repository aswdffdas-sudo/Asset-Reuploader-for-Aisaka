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

local List = {}

local Input = require("./Input")
local Theme = require(".././Theme")
local ListElement = require("./List/ListElement")

local assets = script.Parent.Parent.Assets
local tabAsset = assets.Tab
local asset = assets.List

local function Get(self: List): { string }
    local values = {}
    for i, _ in pairs(self.elements) do
        table.insert(values, i)
    end
    return values
end

local function AddInput(self: List, placeholderText: string, callback: any): Input.Input
    local input = Input.new(self.instance , placeholderText, callback)

    local scrollingFrame = self.instance.ScrollingFrame
    scrollingFrame.Position = UDim2.new(0.5, 0, 0, 23)
    scrollingFrame.Size = UDim2.new(1, 0, 1, -23)

    self._input = input
    return input
end

local function CreateElement(self: List, value: string): ListElement.ListElement
    local listElement = ListElement.new(
        self.instance.ScrollingFrame , 
        function() self.elements[value] = nil end,
        value
    )

    self.elements[value] = listElement
    return listElement
end

local function RemoveElement(self: List, value: string)
    if not self.elements[value] then error(tostring(value) .. " does not exist in list") end
    self.elements[value]:Destroy()
    self.elements[value] = nil
end

local function UpdateTheme(self: List)
    local listFrame = self.instance.ScrollingFrame
    Theme.updateFrame(listFrame)

    for _, element in pairs(self.elements) do
        element:UpdateTheme()
    end

    if self._input then
        self._input:UpdateTheme()
    end
end

local function Destroy(self: List)
    for _, element in pairs(self.elements) do
        element:Destroy()
    end

    self.instance:Destroy()

    table.clear(self )
end

export type List = {
    _input: Input.Input?,

    elements: { [string]: ListElement.ListElement },
    instance: typeof(asset),

    Get: typeof(Get),
    AddInput: typeof(AddInput),
    CreateElement: typeof(CreateElement),
    RemoveElement: typeof(RemoveElement),
    UpdateTheme: typeof(UpdateTheme),
    Destroy: typeof(Destroy),
}

function List.new(parent: typeof(tabAsset)): List
    local instance = asset:Clone()
    instance.Size = UDim2.new(1, 0, 1, -parent.UIListLayout.AbsoluteContentSize.Y - 7)

    local self = {
        elements = {},
        instance = instance,

        Get = Get,
        AddInput = AddInput,
        CreateElement = CreateElement,
        RemoveElement = RemoveElement,
        UpdateTheme = UpdateTheme,
        Destroy = Destroy,
    } 

    self:UpdateTheme()
    instance.Parent = parent

    return self
end

return List
