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

local reuploadIds = require("../ReuploadIds")
local UiLibrary = require("../../UiLibrary")
local Selection = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

return function(ui: any, plugin: Plugin)
    local tab = ui:CreateTab("Gamepass")

    tab:CreateButton("Reupload Gamepasses as T-Shirts", function()
        local gamepassIds = {}
        local seen = {}

        local services = {"Workspace", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer"}
        for _, sName in ipairs(services) do
            local ok, s = pcall(game.GetService, game, sName)
            if ok and s then
                for _, desc in ipairs(s:GetDescendants()) do
                    if desc:IsA("LuaSourceContainer") then
                        local src = desc.Source
                        if src then
                            for numStr in string.gmatch(src, "[^%d](%d%d%d%d%d+)[^%d]") do
                                local num = tonumber(numStr)
                                if num and not seen[num] then
                                    local pat = "[^%c]+" .. numStr .. "[^%c]+"
                                    local line = string.match(src, pat) or ""
                                    local low = line:lower()
                                    if low:find("pass") or low:find("owns") or low:find("prompt") or low:find("shop") or low:find("earlyaccess") then
                                        seen[num] = true
                                        table.insert(gamepassIds, num)
                                    end
                                end
                            end
                        end
                    elseif desc:IsA("IntValue") or desc:IsA("NumberValue") then
                        local n = desc.Name:lower()
                        if n:find("gamepass") or n:find("pass") then
                            local num = tonumber(desc.Value)
                            if num and not seen[num] then
                                seen[num] = true
                                table.insert(gamepassIds, num)
                            end
                        end
                    end
                end
            end
        end

        if #gamepassIds == 0 then
            ui:Notify("Notification", "No Gamepass IDs found in game scripts.")
            return
        end

        local filter = {
            WhitelistedInstances = { "LuaSourceContainer", "IntValue", "NumberValue", "StringValue" },
            Instances = getGameDescendants()
        }

        ui:Notify("Notification", "Found " .. tostring(#gamepassIds) .. " Gamepass IDs! Reuploading as T-Shirts to Aisaka...")
        reuploadIds(plugin, ui, filter, "Gamepass", gamepassIds)
    end)

    tab:CreateButton("Convert APIs (GamePass -> T-Shirt)", function()
        local services = {"Workspace", "ReplicatedStorage", "ServerScriptService", "ServerStorage", "StarterGui", "StarterPack", "StarterPlayer"}
        local converted = 0
        for _, sName in ipairs(services) do
            local ok, s = pcall(game.GetService, game, sName)
            if ok and s then
                for _, desc in ipairs(s:GetDescendants()) do
                    if desc:IsA("LuaSourceContainer") then
                        local src = desc.Source
                        if src and (src:find("UserOwnsGamePassAsync") or src:find("PromptGamePassPurchase")) then
                            local newSrc = src:gsub("UserOwnsGamePassAsync", "PlayerOwnsAsset")
                            newSrc = newSrc:gsub("PromptGamePassPurchaseFinished", "PromptPurchaseFinished")
                            newSrc = newSrc:gsub("PromptGamePassPurchase", "PromptPurchase")
                            if newSrc ~= src then
                                desc.Source = newSrc
                                converted = converted + 1
                            end
                        end
                    end
                end
            end
        end
        ChangeHistoryService:SetWaypoint("Converted GamePass APIs to T-Shirt")
        ui:Notify("Notification", "Converted GamePass APIs in " .. tostring(converted) .. " scripts to T-Shirt Asset APIs!")
    end)
end
