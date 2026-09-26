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

local WaitGroup = {}

local function Add(self: WaitGroup, f: any)
    self._threads += 1
    task.spawn(function()
        f()
        self._threads -= 1

        local waitThread = self._waitThread
        if self._threads == 0 and waitThread then
            self._waitThread = nil
            coroutine.resume(waitThread)
        end
    end)
end

local function Wait(self: WaitGroup)
    if self._threads == 0 then return end
    assert(not self._waitThread, "WaitGroup:Wait() already in progress")

    self._waitThread = coroutine.running()
    coroutine.yield()
end

type WaitGroup = {
    _threads: number,
    _waitThread: thread?,

    Add: typeof(Add),
    Wait: typeof(Wait),
}

function WaitGroup.new(): WaitGroup
    return {
        _threads = 0,

        Add=Add,
        Wait=Wait
    }
end

return WaitGroup