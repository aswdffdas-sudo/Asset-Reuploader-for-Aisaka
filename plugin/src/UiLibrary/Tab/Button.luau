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

local Button = {}

local Theme = require("../Theme")

local asset = script.Parent.Parent.Assets.Button

local function ColorSelected(self: Button)
	local theme = Theme.get()
	local instance = self.instance
	instance.BackgroundColor3 = theme.SelectedColor
end

local function ColorUnselected(self: Button)
	local theme = Theme.get()
	local instance = self.instance
	instance.BackgroundColor3 = theme.UnselectedColor
end

local function UpdateTheme(self: Button)
    Theme.updateText(self.instance, true)

    local theme = Theme.get()
    self.instance.BackgroundColor3 = theme.UnselectedColor
end

local function Destroy(self: Button)
    self.instance:Destroy()
    
	table.clear(self )
end

export type Button = {
	instance: typeof(asset),

	ColorSelected: typeof(ColorSelected),
	ColorUnselected: typeof(ColorUnselected),
    UpdateTheme: typeof(UpdateTheme),
	Destroy: typeof(Destroy),
}

function Button.new(parent: GuiObject, text: string, callback: any, autoColor: boolean?): Button
    local instance = asset:Clone()
    instance.Text = text

	local self: Button = {
		instance = instance,

		ColorSelected = ColorSelected,
		ColorUnselected = ColorUnselected,
        UpdateTheme = UpdateTheme,
		Destroy = Destroy,
	}

	if autoColor == nil then
		autoColor = true
	end

	instance.MouseButton1Down:Connect(function()
		if autoColor then self:ColorSelected() end
		callback()
	end)

	if autoColor then
		local function colorUnselected()
			self:ColorUnselected()
		end

		instance.MouseButton1Up:Connect(colorUnselected)
		instance.MouseLeave:Connect(colorUnselected)
	end

    self:UpdateTheme()
    instance.Parent = parent

	return self
end

return Button
