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
local AssetIdFilter = require("../AssetIdFilter")
local getFilterOptions = require("../GetFilterOptions")
local UiLibrary = require("../../UiLibrary")
local ApiDump = require("../ApiDump")

local HttpService = game:GetService("HttpService")
local StudioService = game:GetService("StudioService")

return function(ui: UiLibrary.Ui, plugin: Plugin)
    local tab = ui:CreateTab("Replace")

    local replaceButton = tab:CreateButton("Replace ids", function()
        local file: File? = StudioService:PromptImportFile({"json"} ) 
        if not file then return end

        local fileContents = file:GetBinaryContents()

        local success, idsToReplace = pcall(HttpService.JSONDecode, HttpService, fileContents)
        if not success then
            ui:Notify("Notification", "Can't parse JSON")
            return
        end

        for i, idInfo in pairs(idsToReplace) do
            if type(idInfo) ~= "table" then
                ui:Notify("Notification", "Invalid index: " .. tostring(i))
                return
            end

            local oldId = idInfo["oldId"]
            local newId = idInfo["newId"]

            local isOldIdValid = oldId and type(oldId) == "number"
            if not isOldIdValid then
                ui:Notify("Notification", "Invalid type at " .. tostring(i) .. "[oldId]")
                return
            end

            local isNewIdValid = newId and type(newId) == "number"
            if not isNewIdValid then
                ui:Notify("Notification", "Invalid type at " .. tostring(i) .. "[newId]")
                return
            end
        end

        local filterOptions = getFilterOptions(plugin, getGameDescendants())
        local instancesArray = filterOptions.WhitelistedInstances

        local isApiDumpCached = ApiDump.isCached()
        if not isApiDumpCached then
            warn("Api dump not cached, skipping meshes")
        end

        local classNames = isApiDumpCached and {"Animation", "Sound", "MeshPart", "CharacterMesh", "SpecialMesh"} or {"Animation", "Sound"}
        for _, className in pairs(classNames) do
            table.insert(instancesArray, className)
        end
        
        local filteredIds = AssetIdFilter.filterInstances(filterOptions)
        AssetIdFilter.replaceIds(filteredIds, idsToReplace )

        warn("Finished replacing Ids")
    end)
    replaceButton.instance.LayoutOrder = 2
end
