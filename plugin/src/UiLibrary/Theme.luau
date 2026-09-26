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

local Theme = {}

local DEFAULT_THEME_PARAMETERS: RawTheme = {
	Name = "",

    Font = "SourceSansPro",
	TextSize = 15,
    TextColor = { Enum.StudioStyleGuideColor.MainText.Name },
    DimmedTextColor = { Enum.StudioStyleGuideColor.DimmedText.Name },
	StrokeColor = Color3.new(),
    StrokeTransparency = 0.75,  -- varies based on theme: 1 for light, 0.75 for dark if not set

	BorderColor = { Enum.StudioStyleGuideColor.Border.Name },

	BackgroundColor = { Enum.StudioStyleGuideColor.Light.Name },
	BackgroundImage = "",

    ForegroundColor = { Enum.StudioStyleGuideColor.MainBackground.Name },
	ForegroundImage = "",

    UnselectedColor = { Enum.StudioStyleGuideColor.Button.Name },
    SelectedColor = { Enum.StudioStyleGuideColor.Button.Name, Enum.StudioStyleGuideModifier.Pressed.Name },

    ToggleBackgroundColor = { Enum.StudioStyleGuideColor.DialogMainButton.Name },
	ToggleImage = "rbxassetid://97413807029185",

	InputColor = { Enum.StudioStyleGuideColor.MainText.Name },
	InputImage = "rbxassetid://72207659330742",
    TipColor = { Enum.StudioStyleGuideColor.MainText.Name },
    TipImage = "rbxassetid://110240163333510",

	XColor = { Enum.StudioStyleGuideColor.MainText.Name },
	XImage = "rbxassetid://116654648035158",

	NotificationTransparency = 0,
    NotificationImage = "",
    NotificationBackgroundImage = "",
}

local ContentProvider = game:GetService("ContentProvider")
local HttpService = game:GetService("HttpService")

local currentTheme: Theme
local plugin: Plugin
local themes: RawTheme = { Studio = { Name = "Studio" } }

type RawTheme = { [string]: any }

export type Theme = {
	Name: string,
	Id: string,

	Font: Font,
	TextSize: number,
	TextColor: Color3,
	DimmedTextColor: Color3,
	StrokeColor: Color3,
	StrokeTransparency: number,

	BorderColor: Color3,

	BackgroundColor: Color3,
	BackgroundImage: string,

	ForegroundColor: Color3,
	ForegroundImage: string,

	UnselectedColor: Color3,
	SelectedColor: Color3,

	ToggleBackgroundColor: Color3,
	ToggleImage: string,

	InputColor: Color3,
	InputImage: string,
	TipColor: Color3,
	TipImage: string,

	XColor: Color3,
	XImage: string,

	NotificationTransparency: number,
	NotificationImage: string,
	NotificationBackgroundImage: string,
}

local function deepCopy(original)
	assert(type(original) == "table", "can only deep copy tables")

	local copy = {}
	for i, v in pairs(original) do
		copy[i] = (type(v) == "table" and deepCopy(v) or v)
	end

	return copy
end

local function getFont(rawThemeFont)
	return Enum.Font.SourceSans
end

local function normalizeRawTheme(rawTheme: RawTheme, themeId: string): Theme
	local studioTheme = settings().Studio.Theme 
	local theme: { [string]: any } = {}

	local function normalizeValue(key: string, value: any): any
		if type(value) ~= "table" then return value end

		local valueType = type( (value )[1] )
		if valueType == "string" then
			if #value > 2 then error(tostring(key) .. " could not create a StudioStyleGuide") end

			local color, modifier = _unpack(value )

			local colorEnum = nil
			pcall(function()
				colorEnum = Enum.StudioStyleGuideColor[color]
			end)
			if not colorEnum then
				colorEnum = Enum.StudioStyleGuideColor.MainBackground
			end

			local modifierEnum = nil
			if modifier then
				pcall(function()
					modifierEnum = Enum.StudioStyleGuideModifier[modifier]
				end)
			end

			return studioTheme:GetColor(colorEnum, modifierEnum)
		elseif valueType == "number" then
			if #value ~= 3 then error(tostring(key) .. " needs 3 values to create a Color3") end

			local R, G, B = _unpack(value )
			local success, result = pcall(Color3.fromRGB, R, G, B)
			if not success then error(tostring(key) .. " could not create a Color3") end
			return result
		end

		error(tostring(key) .. " is an invalid type")
	end

	for k, v in pairs(DEFAULT_THEME_PARAMETERS) do
		if k == "Font" then
			theme[k] = rawTheme[k] and getFont(rawTheme[k]) or getFont(v)
			continue
		end

		if rawTheme[k] then
			theme[k] = normalizeValue(k, rawTheme[k])
			continue
		end

		if k == "StrokeTransparency" then
			theme[k] = studioTheme.Name == "Light" and 1 or 0.75
			continue
		end

		theme[k] = normalizeValue(k, v)
	end

	theme.Id = themeId
	return theme
end

local function preloadThemeAssets(theme: Theme)
	local assets = {
		theme.ForegroundImage, theme.BackgroundImage, theme.ToggleImage, theme.TipImage,
		theme.XImage, theme.NotificationImage, theme.NotificationBackgroundImage
	}
	task.spawn(ContentProvider.PreloadAsync, ContentProvider, assets)
end

local function save()
	assert(plugin, "theme needs to be initialized, call Theme.init() first")
	
	local themesToSave = {}
	for themeId, theme in pairs(themes) do
		if themeId == "Studio" then continue end
		themesToSave[themeId] = theme
	end

	plugin:SetSetting("Themes", themesToSave)
end

function Theme.init(currentPlugin: Plugin)
	assert(not plugin, "theme is already initialized")
	plugin = currentPlugin

	local savedThemes = plugin:GetSetting("Themes") or {}
	for themeId, theme in pairs(savedThemes) do
		themes[themeId] = theme
	end

	local savedThemeId = plugin:GetSetting("CurrentTheme")
	if themes[savedThemeId] then
		Theme.set(savedThemeId)
		return
	end

	Theme.set("Studio")
end

function Theme.getThemes(): { [string]: RawTheme }
	return themes
end

function Theme.get(): Theme
	return currentTheme
end

function Theme.set(themeId: string)
	local theme: RawTheme? = themes[themeId]
	assert(theme, "theme does not exist")

	currentTheme = normalizeRawTheme(theme, themeId)
	plugin:SetSetting("CurrentTheme", themeId)
	preloadThemeAssets(currentTheme)
end

function Theme.add(rawTheme: RawTheme): string
	assert(type(rawTheme["Name"]) == "string", "theme requires a name")

	local id = HttpService:GenerateGUID(false)
	while themes[id] do 
		id = HttpService:GenerateGUID(false) 
	end
	themes[id] = rawTheme

	local success, result = pcall(normalizeRawTheme, rawTheme, id)
	assert(success, result)

	save()
	return id
end

function Theme.updateFrame(frame: GuiObject)
	frame.BackgroundColor3 = currentTheme.ForegroundColor
	frame.BorderColor3 = currentTheme.BorderColor
end

function Theme.updateText(text: TextBox | TextLabel | TextButton, updateBackground: boolean?)
	pcall(function() text.Font = currentTheme.Font or Enum.Font.SourceSans end)
	text.TextSize = currentTheme.TextSize
	text.TextColor3 = currentTheme.TextColor
	text.TextStrokeColor3 = currentTheme.StrokeColor
	text.TextStrokeTransparency = currentTheme.StrokeTransparency
	if text:IsA("TextBox") then text.PlaceholderColor3 = currentTheme.DimmedTextColor end

	if updateBackground then 
		Theme.updateFrame(text) 
	end
end

function Theme.remove(themeId: string)
	themes[themeId] = nil
	save()
end

return Theme
