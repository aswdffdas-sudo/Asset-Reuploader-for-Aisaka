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

local function getGameDescendants()
    local instances = {}
    local services = {"Workspace", "ReplicatedStorage", "ReplicatedFirst", "StarterGui", "StarterPack", "StarterPlayer", "Lighting", "SoundService", "ServerStorage", "ServerScriptService"}
    for _, sName in ipairs(services) do
        local ok, s = pcall(game.GetService, game, sName)
        if ok and s then
            table.insert(instances, s)
            for _, d in ipairs(s:GetDescendants()) do
                table.insert(instances, d)
            end
        end
    end
    return instances
end

--!strict
local getFilterOptions = require("../GetFilterOptions")
local reuploadIds = require("../ReuploadIds")
local UiLibrary = require("../../UiLibrary")

local Selection = game:GetService("Selection")

return function(ui: UiLibrary.Ui, plugin: Plugin)
	local tab = ui:CreateTab("Animation")
	
	local currentGroupId = plugin:GetSetting("GroupID") or 0
	local groupSplit = tab:CreateSplit()
	local groupInput; groupInput = groupSplit:CreateInput("Group ID (0 = User): " .. tostring(currentGroupId), function(input)
		local newGroupId = tonumber(input) or 0
		plugin:SetSetting("GroupID", newGroupId)
		groupInput.instance.TextBox.PlaceholderText = "Group ID: " .. tostring(newGroupId)
		if newGroupId > 0 then
			ui:Notify("Notification", "Set target Group ID to: " .. tostring(newGroupId))
		else
			ui:Notify("Notification", "Target set to User profile (0).")
		end
	end)
	groupSplit:CreateButton("Clear Group", function()
		plugin:SetSetting("GroupID", 0)
		groupInput.instance.TextBox.PlaceholderText = "Group ID: 0"
		ui:Notify("Notification", "Cleared: Uploading to User profile.")
	end)

	tab:CreateButton("Reupload", function()
		local filter = getFilterOptions(plugin, getGameDescendants())
		table.insert(filter.WhitelistedInstances, "Animation")
		if not table.find(filter.WhitelistedInstances, "LuaSourceContainer") then
			table.insert(filter.WhitelistedInstances, "LuaSourceContainer")
		end
		reuploadIds(plugin, ui, filter, "Animation", _G.getPlaceList()) -- forgive me
	end)
	
	tab:CreateButton("Reupload Selected", function()
		local filter =  {
			WhitelistedInstances = { "Animation", "StringValue", "NumberValue", "IntValue", "LuaSourceContainer" },
			Instances = Selection:Get()
		}

		reuploadIds(plugin, ui, filter, "Animation", _G.getPlaceList()) -- forgive me
	end)
end
