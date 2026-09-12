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
local ApiDump = require("../ApiDump")

local Selection = game:GetService("Selection")

local meshSettings: { [string]: string } = {
    ["MeshParts"] = "MeshPart",
    ["SpecialMeshes"] = "SpecialMesh",
    ["CharacterMeshes"] = "CharacterMesh"
}

return function(ui: UiLibrary.Ui, plugin: Plugin)
	local tab = ui:CreateTab("Mesh")

    if not ApiDump.get() then
        local thread = coroutine.running()
        local button; button = tab:CreateButton("Failed to get api dump: retry", function()
            if not ApiDump.get() then return end
            (button :: any):Destroy()
            coroutine.resume(thread)
        end)
        coroutine.yield(thread)
    end

    local split = tab:CreateSplit()
    split:CreateToggle("Search mesh parts", function(state)
        plugin:SetSetting("MeshParts", state)
    end, plugin:GetSetting("MeshParts"))
    split:CreateToggle("Search special meshes", function(state)
        plugin:SetSetting("SpecialMeshes", state)
    end, plugin:GetSetting("SpecialMeshes"))

    local split2 = tab:CreateSplit()
    split2:CreateToggle("Search character meshes", function(state)
        plugin:SetSetting("CharacterMeshes", state)
    end, plugin:GetSetting("CharacterMeshes"))

	tab:CreateButton("Reupload", function()
        local filter = getFilterOptions(plugin, getGameDescendants())
        for settingName, className in pairs(meshSettings) do
            if not plugin:GetSetting(settingName) then continue end
            table.insert(filter.WhitelistedInstances, className)
        end

		reuploadIds(plugin, ui, filter, "Mesh", _G.getPlaceList()) -- forgive me
	end)
	
	tab:CreateButton("Reupload Selected", function()
        local filter = {
            WhitelistedInstances = {
                "MeshPart", "SpecialMesh", "CharacterMesh", 
                "StringValue", "NumberValue", "IntValue",
                "LuaSourceContainer",
            },
            Instances = Selection:Get()
        }

        reuploadIds(plugin, ui, filter, "Mesh", _G.getPlaceList()) -- forgive me
	end)
end
