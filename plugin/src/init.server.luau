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

local UiLibrary = require("./Plugin/UiLibrary")
local App = require("./Plugin/App")

local RunService = game:GetService("RunService")

if not RunService:IsEdit() then
	return
end

local currentVersion = script.Parent.Version.Value
local topbarTitle = "Bacfr Asset Reuploader 1.7.2"

local toolbar = plugin:CreateToolbar("Asset Reuploader")
local widget = plugin:CreateDockWidgetPluginGui(
	"Asset Reuploader",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 500, 250, 500, 250)
)

local toggleButton = toolbar:CreateButton("Toggle Gui", "Toggle gui visibility", "rbxassetid://83178708216253")
toggleButton.Click:Connect(function() widget.Enabled = not widget.Enabled end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function() toggleButton:SetActive(widget.Enabled) end)
widget.Title = "Bacfr 1.7.2"

if plugin:GetSetting("Port") == nil then
	plugin:SetSetting("Port", 38073)
end

local ui = UiLibrary.new(widget, plugin)
App.init(ui, plugin)

plugin.Unloading:Connect(function()
	ui:Destroy()
end)
