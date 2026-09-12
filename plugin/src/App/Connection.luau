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

local function checkConnectionStatus(self: Connection)
    local connected, data = pcall(get, self._port)
    if not connected then
        if self.onDisconnect then self.onDisconnect() end
        self:Destroy()
        return
    end

    if self.onDataRecieved then self.onDataRecieved(data :: string) end
    self._thread = task.delay(1, checkConnectionStatus, self)
end

local function Send(self: Connection, path: string, JSON: string): (boolean, string)
    local success, response = pcall(post, self._port, path, JSON)
    return success :: boolean, response :: string
end

local function Destroy(self: Connection)
    coroutine.yield(self._thread)
    coroutine.close(self._thread)
    table.clear(self :: any)
end

type Connection = {
    _port: number,
    _thread: thread,

	onDisconnect: any,
	onDataRecieved: any,

	Send: typeof(Send),
    Destroy: typeof(Destroy),
}

function Connection.new(port: number): (Connection?, string?)
    local connected, data = pcall(get :: any, port)
	if not connected then return nil, nil end
	
    local self; self = {
        _port = port,

        Send = Send,
        Destroy = Destroy,
    } :: Connection
    self._thread = task.delay(1, checkConnectionStatus, self)
    
	return self, data ~= "null\n" and (data :: string) or nil
end

return Connection
