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

local Connection = {}

local HttpService = game:GetService("HttpService")

local function get(port: number): string
    return HttpService:GetAsync("http://localhost:" .. tostring(port))
end

local function post(port: number, path: string, data: string): string
    return HttpService:PostAsync("http://localhost:" .. tostring(port) .. tostring(path), data)
end

function Connection.new(port: number)
    local connected, data = pcall(get, port)
    if not connected then return nil, nil end
    
    local self = {
        _port = port,
        _active = true,
        onDisconnect = nil,
        onDataRecieved = nil,
    }
    
    self.Send = function(s, path, json)
        local success, response = pcall(post, self._port, path, json)
        return success, response
    end
    
    self.Destroy = function(s)
        self._active = false
        table.clear(self)
    end

    -- Continuous background polling loop that runs reliably in Studio Edit mode
    coroutine.wrap(function()
        while self._active do
            wait(0.8)
            if not self._active then break end

            local ok, respData = pcall(get, self._port)
            if not ok then
                if self.onDisconnect then
                    pcall(self.onDisconnect)
                end
                self._active = false
                break
            end

            if respData and #respData > 0 and respData ~= "null\n" and respData ~= "[]\n" and respData ~= "[]" then
                if self.onDataRecieved then
                    pcall(self.onDataRecieved, respData)
                end
            end
        end
    end)()

    local initialData = (data ~= "null\n" and data ~= "[]\n" and data ~= "[]") and data or nil
    return self, initialData
end

return Connection
