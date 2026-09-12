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

local ApiDump = {}

local API_DUMP_URL = "https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/refs/heads/roblox/API-Dump.json"

local retry = require("./Retry")

local HttpService = game:GetService("HttpService")

local classIndexMap: { [string]: number } = {}
local cachedDump: ApiDump? = nil
local blacklistedTags: { [string]: boolean } = {
	Hidden = true,
	ReadOnly = true,
	NotScriptable = true
}

type Member = {
	Category: string?,
	MemberType: string,
	Name: string,
	Security: {
		Read: string,
		Write: string
	},
	Serialization: {
		CanLoad: boolean,
		CanSave: boolean
	}?,
	Tags: { string }?,
	ThreadSafety: string,
	ValueType: {
		Category: string,
		Name: string
	}?,
	Parameters: {
		{
			Name: string,
			Type: {
				Category: string,
				Name: string
			}
		}
	}?,
	ReturnType: {
		Category: string,
		Name: string
	}?
}

export type ApiDump = {
    Classes: {
		{
			Members: {
				Member
			},
			MemoryCategory: string,
			Name: string,
			Superclass: string,
			Tags: { string }?
		}
    },
    Enums: {
        {
            Items: {
                {
                    Name: string,
                    Value: number
                }
            },
            Name: string,
            Tags:  {string }?
        }
    },
    Version: number
}

function ApiDump.isCached(): boolean
    return cachedDump ~= nil
end

local function cacheDump(apiDump: ApiDump)
	cachedDump = apiDump
	
	for i, class in pairs(apiDump.Classes) do
		classIndexMap[class.Name] = i
	end
end

function ApiDump.get(): ApiDump?
    if cachedDump then return cachedDump end

    local success, response = retry(3, HttpService.GetAsync, HttpService, API_DUMP_URL)
	if not success then
		warn("Failed to get latest roblox API dump:", response)
		return nil
	end

	local apiDump = HttpService:JSONDecode(response :: string)
	cacheDump(apiDump)
	return cachedDump
end

local function isValidProperty(member: Member): boolean
	if member.MemberType ~= "Property" then return false end
	if member.Security.Write ~= "None" then return false end

	local tags = member.Tags
	if tags then
		for _, tag in pairs(tags) do
			if not blacklistedTags[tag] then continue end
			return false
		end
	end

	return true
end

function ApiDump.getProperties(className: string): { string }
	assert(cachedDump, "api dump is not cached use ApiDump.get()")
	local properties = {}
	
	local classIndex = classIndexMap[className]
	if not classIndex then error(tostring(className) .. " is not in api dump cache") end
	
	local class = cachedDump.Classes[classIndex]
	for _, member in pairs(class.Members) do
		if not isValidProperty(member) then continue end
		table.insert(properties, member.Name)
	end
	
	if class.Superclass ~= "<<<ROOT>>>" then
		for _, property in pairs(ApiDump.getProperties(class.Superclass)) do
			table.insert(properties, property)
		end
	end
	
	return properties
end

return ApiDump
