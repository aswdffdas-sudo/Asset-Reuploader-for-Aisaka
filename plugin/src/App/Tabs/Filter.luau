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

local UiLibrary = require("../../UiLibrary")

local MarketplaceService = game:GetService("MarketplaceService")

return function(ui: UiLibrary.Ui, plugin: Plugin)
	local tab = ui:CreateTab("Filter")
        local placeList

    _G.getPlaceList = function(): { number } -- guys im so sorry im just so drained :sob: will be back at full on v2.0.0, forgive me for _G use... I wont forgive myself
        local placesListValues = placeList:Get()
        local list = table.create(#placesListValues)
        for _, value in pairs(placesListValues) do
            table.insert(list, tonumber(value))
        end
        return list :: { number }
    end
	
	local split1 = tab:CreateSplit()
    split1:CreateToggle("Search string values", function(state)
        plugin:SetSetting("StrVals", state)
    end, plugin:GetSetting("StrVals"))
    split1:CreateToggle("Search scripts", function(state)
        plugin:SetSetting("Scripts", state)
    end, plugin:GetSetting("Scripts"))
    
    local split2 = tab:CreateSplit()
    split2:CreateToggle("Search int/number values", function(state)
        plugin:SetSetting("NumVals", state)
    end, plugin:GetSetting("NumVals"))

    placeList = tab:CreateList()

	local placeInput = placeList:AddInput("Place Id", function(input)
		local placeId = tonumber(input)
        local success, productInfo = pcall(MarketplaceService.GetProductInfo, MarketplaceService, placeId)

        if not success then
            ui:Notify("Notification", "Error getting product info.") 
            return 
        end

        local assetTypeId = (productInfo :: any).AssetTypeId
		if assetTypeId ~= 9 then
            ui:Notify("Notification", "Invalid place id.") 
            return 
        end

        local stringPlaceId = tostring(placeId)
		if placeList.elements[stringPlaceId] then
            ui:Notify("Notification", "Place id is in list.") 
            return 
        end

		local element = placeList:CreateElement(stringPlaceId)
            :AddDestroyButton()
        
        element.instance.TextLabel.Text = "(" .. tostring(placeId) .. ") " .. tostring((productInfo :: any).Name)
	end)
	placeInput:AddTip(ui:CreateTip(
		"Reuploading needs a place id. Public games under the creator are found automatically."
	))

    local textBox = placeInput.instance.TextBox
    textBox:GetPropertyChangedSignal("Text"):Connect(function() 
        textBox.Text = string.gsub(textBox.Text, "%D", "") 
    end)
end
