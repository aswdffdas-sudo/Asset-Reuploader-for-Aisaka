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

local AssetIdFilter = require("./AssetIdFilter")
local Connection = require("./Connection")
local retry = require("./Retry")
local StatusCodes = require("./StatusCodes")
local UiLibrary = require("../UiLibrary")

local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")

local currentVersion = script.Parent.Parent.Parent.Version.Value
local busy = false

type ProductInfo = {
    AssetTypeId: number,
    TargetId: number,
    IsNew: boolean,
    Updated: string, -- ISO format
    AssetId: number,
    ProductId: number,
    MinimumMembershipLevel: number,
    Created: string, -- ISO format
    Creator: {
        Name: string,
        CreatorTargetId: number,
        Id: number,
        HasVerifiedBadge: boolean,
        CreatorType: string
    },
    IsLimited: boolean,
    ContentRatingTypeId: number,
    Sales: number,
    IsPublicDomain: boolean,
    Name: string,
    IsForSale: boolean,
    Description: string,
    IconImageAssetId: number,
    IsLimitedUnique: boolean
}

type Request = {
	placeId: number,         
	creatorId: number,       
	ids: { number },             
	defaultPlaceIds: { number }, 
	pluginVersion: string,   
	assetType: string,       
	exportJson: boolean,     
	isGroup: boolean     
}

local function scriptInjectionEnabled()
    local testScript = Instance.new("Script")
    local success = pcall(function()
        testScript.Source = ""
    end)
    testScript:Destroy()
    return success
end

function getGameInfo(): (boolean, number, number)
    local creatorId, placeId = game.CreatorId, game.PlaceId

    if placeId == 0 then
        return false, creatorId, placeId 
    end

    if creatorId ~= 0 then
        local isGroup =  game.CreatorType == Enum.CreatorType.Group
        return isGroup, creatorId, placeId
    end

    local success, result = retry(3, MarketplaceService.GetProductInfo, MarketplaceService, placeId)
    if not success then
        return false, creatorId, placeId
    end

    local creatorInfo = (result ).Creator
    local isGroup = creatorInfo.CreatorType == "Group"
    return isGroup, creatorInfo.CreatorTargetId, placeId
end

return function(plugin: any, ui: any, filterOptions: any, assetType: string, placeArray: any)
    if busy then
        ui:Notify("Notification", "Plugin is busy.")
        return 
    end
    busy = true

    if not scriptInjectionEnabled() then
        ui:Notify("Notification", "Plugin needs script injection permission.")
        busy = false
        return
    end

    local isGroup, creatorId, placeId = getGameInfo()
    if placeId == 0 then
        ui:Notify("Notification", "Game needs to be published. Restart place after publishing.")
        busy = false
        return
    elseif creatorId == 0 then
        ui:Notify("Notification", "Failed to get place info. Try again or restart the place.")
        busy = false
        return
    end
    
    local filteredIds = AssetIdFilter.filterInstances(filterOptions)
    if next(filteredIds) == nil then
        ui:Notify("Notification", "No ids found.")
        busy = false
        return
    end

    local connection, response = Connection.new(plugin:GetSetting("Port"))
    if not connection then
        ui:Notify("Notification", "Unable to connect to localhost. Did you start the executable?" )
        busy = false
        return
    end

    local function onDataRecieved(data: string)
        local success, result = pcall(HttpService.JSONDecode, HttpService, data)
        if not success then
            if data ~= "done" then return end
            
            ui:Notify("Notification", "Finished reuploading all ids.")
            busy = false
            connection:Destroy()
            return
        end

        if #(result ) == 0 then return end
        AssetIdFilter.replaceIds(filteredIds, result )
        warn("Replaced " .. tostring(#(result )) .. " ids")
    end

    connection.onDataRecieved = onDataRecieved
    connection.onDisconnect = function()
        ui:Notify("Notification", "Disconnected from localhost. (Try reconnecting)")
        busy = false
    end

    local idArray = AssetIdFilter.getIdArray(filteredIds)
    local request: Request = {
        pluginVersion = currentVersion,
        creatorId = creatorId,
        isGroup = isGroup,
        assetType = assetType,
        ids = idArray,
        placeId = placeId,
        defaultPlaceIds = placeArray or {},
        exportJson = plugin:GetSetting("ExportJSON")
    }
    
    local success, statusCode = connection:Send("/reupload", HttpService:JSONEncode(request))
    if not success then
        local message: string = (StatusCodes )[statusCode] or ("Unable to send data to localhost.\n" .. statusCode)
        ui:Notify("Notification", message)

        busy = false
        connection:Destroy()
        return
    end

    ui:Notify("Notification", "Sent " .. tostring(#idArray) .. " ids to localhost.")

    if response then
        onDataRecieved(response)
    end
end
