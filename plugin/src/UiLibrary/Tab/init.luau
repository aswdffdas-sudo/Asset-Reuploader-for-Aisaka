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

local Tab = {}

local Button = require("./Tab/Button")
local Label = require("./Tab/Label")
local List = require("./Tab/List")
local Split = require("./Tab/Split")
local Toggle = require("./Tab/Toggle")

local assets = script.Parent.Assets
local asset = assets.Tab
local mainUiFrame = assets.MainFrame

local function CreateButton(self: Tab, text: string, callback: any): Button.Button
	local button = Button.new(self.instance, text, callback)
	table.insert(self._elements, button)
	return button
end

local function CreateToggle(self: Tab, text: string, callback: any, defaultState: boolean?): Toggle.Toggle
	local toggle = Toggle.new(self.instance, text, callback, defaultState)
	table.insert(self._elements, toggle)
	return toggle
end

local function CreateSplit(self: Tab): Split.Split
	local split = Split.new(self.instance)
	table.insert(self._elements, split)
	return split
end

local function CreateList(self: Tab): List.List
	local list = List.new(self.instance )
	table.insert(self._elements, list)
	return list
end

local function CreateLabel(self: Tab, text: string): Label.Label
	local label = Label.new(self.instance , text)
	table.insert(self._elements, label)
	return label
end

local function UpdateTheme(self: Tab)
	self.button:UpdateTheme()

	for _, element in pairs(self._elements) do 
		element:UpdateTheme() 
	end
end

local function Destroy(self: Tab)
	for _, element in pairs(self._elements) do 
		element:Destroy() 
	end

	table.clear(self )
end

export type Tab = {
	_elements: { any },

	button: Button.Button,
	instance: typeof(asset),

	CreateButton: typeof(CreateButton),
	CreateToggle: typeof(CreateToggle),
	CreateSplit: typeof(CreateSplit),
	CreateList: typeof(CreateList),
	CreateLabel: typeof(CreateLabel),
	UpdateTheme: typeof(UpdateTheme),
	Destroy: typeof(Destroy),
}

function Tab.new(uiFrame: typeof(mainUiFrame), clickedCallback: any, name: string): Tab
    local instance = asset:Clone()
	local self: Tab = {
        _elements = {},
        
		button = Button.new(uiFrame.Topbar.Frame, name, clickedCallback, false),
		instance = instance,

		CreateButton = CreateButton,
		CreateToggle = CreateToggle,
		CreateSplit = CreateSplit,
		CreateList = CreateList,
		CreateLabel = CreateLabel,
		UpdateTheme = UpdateTheme,
		Destroy = Destroy,
	}

	self:UpdateTheme()
	instance.Parent =  uiFrame.Main.Tabs

	return self
end

return Tab
