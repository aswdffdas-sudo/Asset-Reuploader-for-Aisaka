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
local ApiDump = require("../ApiDump")
local retry = require("../Retry")
local WaitGroup = require("../WaitGroup")

local AssetService = game:GetService("AssetService")

local cachedClassProperties: { [string]: { string } } = {}

export type IdPair = {
    newId: number,
    oldId: number
}

-- Whole numeric id token with plain string fallback
local function replaceFullNumberToken(s: any, oldId: number, newId: number): string
    if not s then return tostring(newId) end
    local str = tostring(s)
    local res, count = string.gsub(str, "%f[%d]" .. tostring(oldId) .. "%f[%D]", tostring(newId))
    if count == 0 then
        res = string.gsub(str, tostring(oldId), tostring(newId))
    end
    return res
end

-- Optimized: Do string replacements on smaller chunks to avoid freezing
local function setScriptIds(scriptInstance: LuaSourceContainer, idsToChange: { IdPair })
    local source = scriptInstance.Source
    if not source then
        warn(scriptInstance, "has nil source")
        return
    end

    for _, idPair in pairs(idsToChange) do
        local oldId = idPair.oldId
        local newId = idPair.newId
        local res, count = string.gsub(source, "%f[%d]" .. tostring(oldId) .. "%f[%D]", tostring(newId))
        if count == 0 then
            res = string.gsub(source, tostring(oldId), tostring(newId))
        end
        source = res
    end

    scriptInstance.Source = source
end

local function setAnimationId(animation: Animation, oldId: number, newId: number)
    animation.AnimationId = replaceFullNumberToken(animation.AnimationId, oldId, newId)
end

local function setSoundId(sound: Sound, oldId: number, newId: number)
    sound.SoundId = replaceFullNumberToken(sound.SoundId, oldId, newId)
end

local function setNumberValueId(numValue: NumberValue | IntValue, _: number, newId: number)
    numValue.Value = newId
end

local function setStringValueIds(strValue: StringValue, oldId: number, newId: number)
    strValue.Value = replaceFullNumberToken(strValue.Value, oldId, newId)
end

local function setCharacterMesh(characterMesh: CharacterMesh, _: number, newId: number)
    characterMesh.MeshId = newId
end

local function transferAttributes(oldInstance: Instance, newInstance: Instance)
    for name, value in pairs(oldInstance:GetAttributes()) do
        newInstance:SetAttribute(name, value)
    end
end

local function transferTags(oldInstance: Instance, newInstance: Instance)
    for _, tag in pairs(oldInstance:GetTags()) do
        newInstance:AddTag(tag)
    end
end

local function transferChildren(oldInstance: Instance, newInstance: Instance)
    for _, child in pairs(oldInstance:GetChildren()) do
        if child:IsA("TouchTransmitter") then continue end
        child.Parent = newInstance
    end
end

local function transferProperties(oldInstance: Instance, newInstance: Instance)
    local className = oldInstance.ClassName
    if className ~= newInstance.ClassName then error("oldInstance(" .. tostring(className) .. ") class is not equal to newInstance(" .. tostring(newInstance.ClassName) .. ")") end
    assert(ApiDump.isCached(), "no api dump cached")

    local cachedProperties = cachedClassProperties[className]
    if not cachedProperties then
        cachedProperties = ApiDump.getProperties(className)
        cachedClassProperties[className] = cachedProperties
    end

    for _, property in pairs(cachedProperties) do
        if property == "Parent" or property == "Sandboxed" or property == "brickColor" then continue end
        (newInstance :: any)[property] = (oldInstance :: any)[property]
    end
end

local function transferJoints(oldInstance: Instance, newInstance: Instance)
    for _, instance in pairs(getGameDescendants()) do
        if not instance:IsA("JointInstance") then continue end
        if instance.Part0 == oldInstance then
            instance.Part0 = newInstance
        elseif instance.Part1 == oldInstance then
            instance.Part1 = newInstance
        end
    end
end

local function setMeshPart(meshPart: MeshPart, oldId: number, newId: number)
    local contentRetrieved, content: Content = retry(3, Content.fromAssetId, newId) 
    if not contentRetrieved then
        warn("failed to get content from " .. tostring(newId) .. ", skipping " .. tostring(oldId))
        return
    end
    
    local newMeshPart = AssetService:CreateMeshPartAsync(content, {
        CollisionFidelity = meshPart.CollisionFidelity,
        RenderFidelity = meshPart.RenderFidelity,
        FluidFidelity = meshPart.FluidFidelity
    } :: any)

    local success, result = pcall(function()
        transferProperties(meshPart, newMeshPart)
        transferAttributes(meshPart, newMeshPart)
        transferTags(meshPart, newMeshPart)
        transferChildren(meshPart, newMeshPart)
        transferJoints(meshPart, newMeshPart)
    end)
    if not success then
        newMeshPart:Destroy()
        error(result)
    end

    newMeshPart.Parent = meshPart.Parent
    meshPart:Destroy()
end

local function setSpecialMesh(specialMesh: SpecialMesh, oldId: number, newId: number)
    specialMesh.MeshId = replaceFullNumberToken(specialMesh.MeshId, oldId, newId)
end

local instanceIdSetters = {
    Animation = setAnimationId,
    Sound = setSoundId,

    NumberValue = setNumberValueId,
    IntValue = setNumberValueId,
    StringValue = setStringValueIds,

    CharacterMesh = setCharacterMesh,
    MeshPart = setMeshPart,
    SpecialMesh = setSpecialMesh,
}

return function(filteredIds: { [number]: { Instance } }, idsToChange: { IdPair })
    local ChangeHistoryService = game:GetService("ChangeHistoryService")
    pcall(function() ChangeHistoryService:SetWaypoint("AssetReuploader_ChangeIds_Start") end)

    local scriptIdChanges = {}
    local changedCount = 0

    for _, idPair in pairs(idsToChange) do
        local oldId = tonumber(idPair.oldId) or idPair.oldId
        local newId = tonumber(idPair.newId) or idPair.newId

        local instanceArray = filteredIds[oldId]
        if not instanceArray then
            instanceArray = filteredIds[tostring(oldId)]
        end
        if not instanceArray then
            for k, arr in pairs(filteredIds) do
                if tonumber(k) == oldId then
                    instanceArray = arr
                    break
                end
            end
        end

        if instanceArray then
            for _, instance in pairs(instanceArray) do
                if instance:IsA("LuaSourceContainer") then
                    if not scriptIdChanges[instance] then scriptIdChanges[instance] = {} end
                    table.insert(scriptIdChanges[instance], idPair)
                else
                    local className = instance.ClassName
                    local setInstanceId = instanceIdSetters[className]
                    if setInstanceId then
                        local success, result = pcall(setInstanceId :: any, instance, oldId, newId)
                        if success then
                            changedCount = changedCount + 1
                            print(string.format("[Asset Reuploader] Replaced %s in %s (%s -> %s)", className, instance:GetFullName(), tostring(oldId), tostring(newId)))
                        else
                            warn(string.format("[Asset Reuploader] Failed to change %s: %s", instance:GetFullName(), tostring(result)))
                        end
                    end
                end
            end
        else
            warn(string.format("[Asset Reuploader] No instance found in filter map for old ID: %s", tostring(oldId)))
        end
    end

    for instance, idPairs in pairs(scriptIdChanges) do
        local success, result = pcall(setScriptIds, instance, idPairs)
        if success then
            changedCount = changedCount + 1
            print(string.format("[Asset Reuploader] Updated %d ID(s) in script: %s", #idPairs, instance:GetFullName()))
        else
            warn(string.format("[Asset Reuploader] Failed to update script %s: %s", instance:GetFullName(), tostring(result)))
        end
    end

    pcall(function() ChangeHistoryService:SetWaypoint("AssetReuploader_ChangeIds_End") end)
    print(string.format("[Asset Reuploader] Successfully replaced %d instances/scripts with new IDs!", changedCount))
end
