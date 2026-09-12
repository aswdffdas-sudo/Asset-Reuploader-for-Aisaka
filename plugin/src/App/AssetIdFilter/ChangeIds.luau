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

-- Whole numeric id token (same idea as setScriptIds). Plain gsub(oldId) can match a
-- digit prefix inside a larger rbxassetid and corrupt the URL.
local function replaceFullNumberToken(s: string, oldId: number, newId: number): string
	return string.gsub(s, "%f[%d]" .. tostring(oldId) .. "%f[%D]", tostring(newId))
end

-- Optimized: Do string replacements on smaller chunks to avoid freezing
local function setScriptIds(scriptInstance: LuaSourceContainer, idsToChange: { IdPair })
    local source = scriptInstance.Source
    if not source then
        warn(scriptInstance, "has nil source")
        return
    end

    -- Batch process replacements more efficiently
    for _, idPair in pairs(idsToChange) do
        local oldId = idPair.oldId
        local newId = idPair.newId
        source = string.gsub(source, "%f[%d]" .. tostring(oldId) .. "%f[%D]", tostring(newId))
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
    local waitGroup = WaitGroup.new()
    local scriptIdChanges = {}

    for _, idPair in pairs(idsToChange) do
        local oldId = idPair.oldId
        local newId = idPair.newId

        local instanceArray = filteredIds[oldId]
        if not instanceArray then continue end

        for _, instance in pairs(instanceArray) do
            if instance:IsA("LuaSourceContainer") then
                if not scriptIdChanges[instance] then scriptIdChanges[instance] = {} end
                table.insert(scriptIdChanges[instance], idPair)
                continue
            end

            local className = instance.ClassName
            local setInstanceId = instanceIdSetters[className]
            if not setInstanceId then error(tostring(className) .. " is not supported") end

            -- Use task.delay to prevent lag spikes
            waitGroup:Add(function()
                task.delay(0, function()
                    local success, result = pcall(setInstanceId :: any, instance, oldId, newId)
                    if not success then warn("Failed to change", instance, tostring(oldId) .. " to " .. tostring(newId) .. ":", result) end
                end)
            end)
        end
    end

    for instance, idPairs in pairs(scriptIdChanges) do
        waitGroup:Add(function()
            -- Stagger script updates to prevent freezing
            task.delay(0, function()
                local success, result = pcall(setScriptIds, instance, idPairs)
                if not success then warn("Failed to bulk change", instance, result) end
            end)
        end)  
    end

    waitGroup:Wait()
end
