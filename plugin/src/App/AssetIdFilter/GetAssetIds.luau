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


export type FilterOptions = {
    WhitelistedInstances: { string },
    Instances: { Instance },
}

local function isValidId(id: number): boolean
	if id == 0 or id % 1 ~= 0 then return false end

	local idLength = math.floor(math.log10(math.abs(id))) + 1
	return idLength >= 7 and idLength <= 15 -- 7 is minimum length requirement for develop get assets info endpoint do not change
end

-- First %d+ in a URL is often wrong (e.g. ?version=1&id=12345678). Prefer the longest
-- digit run that passes isValidId so we do not drop animations from the reupload list.
local function pickBestValidAssetId(str: string): number?
	local best: number? = nil
	local bestLen = 0
	for matched in string.gmatch(str, "%d+") do
		local id = tonumber(matched)
		if id and isValidId(id) then
			local len = #matched
			if len > bestLen or (len == bestLen and best ~= nil and id > best) then
				bestLen = len
				best = id
			end
		end
	end
	return best
end

local function getId(filteredInstance: Instance, possibleId: any): { [number]: { Instance } }
    local id = tonumber(possibleId)
    if not id or not isValidId(id) then return {} end

    return { [id] = { filteredInstance } }
end

local function getStringIds(filteredInstance: Instance, str: string): { [number]: { Instance } }
    local idMap = {}
	for matchedString in string.gmatch(str, "%d+") do
		local id = tonumber(matchedString)
		if not id or idMap[id] or not isValidId(id) then continue end

		idMap[id] = { filteredInstance }
	end
    return idMap
end

local function getAnimationId(animation: Animation): { [number]: { Instance } }
	local s = tostring((animation ).AnimationId)
	return getId(animation, pickBestValidAssetId(s))
end

local function getSoundId(sound: Sound): { [number]: { Instance } }
	local s = tostring((sound ).SoundId)
	return getId(sound, pickBestValidAssetId(s))
end

local function getScriptIds(scriptInstance: Script | LocalScript | ModuleScript): { [number]: { Instance } }
    return getStringIds(scriptInstance, scriptInstance.Source)
end

local function getStringValueIds(strValue: StringValue): { [number]: { Instance } }
    return getStringIds(strValue, strValue.Value)
end

local function getNumberValueId(numValue: NumberValue | IntValue): { [number]: { Instance } }
    return getId(numValue, numValue.Value)
end

local function getCharacterMesh(characterMesh: CharacterMesh): { [number]: { Instance } }
    return getId(characterMesh, characterMesh.MeshId)
end

local function getMeshPart(meshPart: MeshPart): { [number]: { Instance } }
	local s = tostring((meshPart ).MeshId)
	return getId(meshPart, pickBestValidAssetId(s))
end

local function getSpecialMesh(specialMesh: SpecialMesh): { [number]: { Instance } }
	local s = tostring((specialMesh ).MeshId)
	return getId(specialMesh, pickBestValidAssetId(s))
end

local instanceIdGetters = {
    Animation = getAnimationId,
    Sound = getSoundId,

    NumberValue = getNumberValueId,
    IntValue = getNumberValueId,
    StringValue = getStringValueIds,

    CharacterMesh = getCharacterMesh,
    MeshPart = getMeshPart,
    SpecialMesh = getSpecialMesh,
}

local function createFilterMap(instanceFilter)
    local filterMap = {}  -- yes my code getting lazy i apologize... v2.0.0 will do good code
    for _, className in pairs(instanceFilter) do
        if className == "LuaSourceContainer" then
            filterMap["LocalScript"] = getScriptIds
            filterMap["ModuleScript"] = getScriptIds
            filterMap["Script"] = getScriptIds
        else
            assert(instanceIdGetters[className], tostring(className) .. " is not a supported instance")
            filterMap[className] = instanceIdGetters[className]
        end
    end
    return filterMap
end

local function merge(originalIdMap: { [number]: { Instance } }, otherIdMap: { [number]: { Instance } })
    for id, instanceArray in pairs(otherIdMap) do
        local idInstances = originalIdMap[id]
        if not idInstances then
            originalIdMap[id] = instanceArray
            continue
        end

        for _, instance in pairs(instanceArray) do
            if table.find(idInstances, instance) then continue end
            table.insert(idInstances , instance)
        end
    end
end

return function(filterOptions: FilterOptions): { [number]: { Instance } }
    local idMap = {}
    local filterMap = createFilterMap(filterOptions.WhitelistedInstances)
    for _, instance in pairs(filterOptions.Instances) do
        local okClass, className = pcall(function() return instance.ClassName end)
        if not okClass or not className then continue end
        local parseId = filterMap[className]
        if not parseId then continue end

        local okParse, res = pcall(parseId, instance)
        if okParse and res then
            merge(idMap, res)
        end
    end
    return idMap
end
