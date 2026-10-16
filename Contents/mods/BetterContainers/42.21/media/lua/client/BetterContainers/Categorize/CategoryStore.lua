local IniWriter = require("BetterContainers/_IO/IniWriter")

local OverrideIni = IniWriter.makeFeature("CategoryOverrides", false)
local DefinitionIni = IniWriter.makeFeature("CustomCategories", false)

local Store = {
    defaults = {},
    overrides = {},
    definitions = {},
    loaded = false,
    overridesDirty = false,
    definitionsDirty = false,
}

local function trim(value)
    if type(value) ~= "string" then return "" end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function copyMap(source)
    local out = {}
    for key, value in pairs(source or {}) do
        out[key] = value
    end
    return out
end

local function loadRows()
    Store.overrides = {}
    for fullType, row in pairs(OverrideIni.loadAll()) do
        if fullType ~= "Meta" and type(row) == "table" then
            local category = trim(row.Category)
            if category ~= "" then
                Store.overrides[tostring(fullType)] = category
            end
        end
    end

    Store.definitions = {}
    for categoryID, row in pairs(DefinitionIni.loadAll()) do
        if categoryID ~= "Meta" and type(row) == "table" then
            local id = trim(tostring(categoryID))
            local displayName = trim(row.DisplayName)
            if id ~= "" and displayName ~= "" then
                Store.definitions[id] = { displayName = displayName }
            end
        end
    end

    Store.loaded = true
    Store.overridesDirty = false
    Store.definitionsDirty = false
end

function Store.ensureLoaded()
    if not Store.loaded then
        loadRows()
    end
end

function Store.reload()
    loadRows()
end

function Store.setDefaults(defaults)
    Store.ensureLoaded()
    Store.defaults = copyMap(defaults)
end

function Store.getDefault(fullType)
    return Store.defaults[fullType]
end

function Store.getOverride(fullType)
    Store.ensureLoaded()
    return Store.overrides[fullType]
end

function Store.getEffective(fullType)
    Store.ensureLoaded()
    return Store.overrides[fullType] or Store.defaults[fullType]
end

function Store.hasOverride(fullType)
    Store.ensureLoaded()
    return Store.overrides[fullType] ~= nil
end

function Store.setOverride(fullType, categoryID)
    Store.ensureLoaded()
    fullType = trim(fullType)
    categoryID = trim(categoryID)
    if fullType == "" or categoryID == "" then return false end

    local nextValue = categoryID
    if Store.defaults[fullType] == categoryID then
        nextValue = nil
    end

    if Store.overrides[fullType] == nextValue then return false end
    Store.overrides[fullType] = nextValue
    Store.overridesDirty = true
    return true
end

function Store.resetOverride(fullType)
    Store.ensureLoaded()
    if Store.overrides[fullType] == nil then return false end
    Store.overrides[fullType] = nil
    Store.overridesDirty = true
    return true
end

function Store.getDefinitions()
    Store.ensureLoaded()
    return Store.definitions
end

function Store.getCustomDisplayName(categoryID)
    Store.ensureLoaded()
    local definition = Store.definitions[categoryID]
    return definition and definition.displayName or nil
end

function Store.isCustomCategory(categoryID)
    Store.ensureLoaded()
    return Store.definitions[categoryID] ~= nil
end

local function makeCategoryID(displayName)
    local slug = trim(displayName):gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if slug == "" then slug = "Category" end

    local base = "BC_Custom_" .. slug
    local id = base
    local suffix = 2
    while Store.definitions[id] do
        id = base .. "_" .. tostring(suffix)
        suffix = suffix + 1
    end
    return id
end

function Store.createCustomCategory(displayName)
    Store.ensureLoaded()
    displayName = trim(displayName)
    if displayName == "" then return nil end

    local id = makeCategoryID(displayName)
    Store.definitions[id] = { displayName = displayName }
    Store.definitionsDirty = true
    return id
end

function Store.renameCustomCategory(categoryID, displayName)
    Store.ensureLoaded()
    local definition = Store.definitions[categoryID]
    displayName = trim(displayName)
    if not definition or displayName == "" or definition.displayName == displayName then
        return false
    end
    definition.displayName = displayName
    Store.definitionsDirty = true
    return true
end

function Store.deleteCustomCategory(categoryID)
    Store.ensureLoaded()
    if not Store.definitions[categoryID] then return false end

    Store.definitions[categoryID] = nil
    Store.definitionsDirty = true
    for fullType, assignedID in pairs(Store.overrides) do
        if assignedID == categoryID then
            Store.overrides[fullType] = nil
            Store.overridesDirty = true
        end
    end
    return true
end

function Store.getCategoryDisplayName(categoryID)
    local customName = Store.getCustomDisplayName(categoryID)
    if customName then return customName end
    return getTextOrNull("IGUI_ItemCat_" .. tostring(categoryID)) or tostring(categoryID)
end

function Store.injectCustomTranslations()
    Store.ensureLoaded()
    if not (Translator and Translator.BY_NAME) then return false end

    local ok = pcall(function()
        local igui = Translator.BY_NAME:get("IG_UI")
        if not igui then return end
        for categoryID, definition in pairs(Store.definitions) do
            igui:put("IGUI_ItemCat_" .. categoryID, definition.displayName)
        end
    end)
    return ok
end

function Store.installTextResolver()
    if Store._textResolverInstalled or type(getText) ~= "function" then return end
    Store._textResolverInstalled = true
    local originalGetText = getText
    getText = function(key, ...)
        if type(key) == "string" and string.sub(key, 1, 13) == "IGUI_ItemCat_" then
            local categoryID = string.sub(key, 14)
            local definition = Store.definitions[categoryID]
            if definition then return definition.displayName end
        end
        return originalGetText(key, ...)
    end
end

function Store.getAllCategoryIDs(scriptCategories)
    Store.ensureLoaded()
    local seen = {}
    local out = {}
    local function add(categoryID)
        categoryID = trim(categoryID)
        if categoryID ~= "" and not seen[categoryID] then
            seen[categoryID] = true
            out[#out + 1] = categoryID
        end
    end

    for _, categoryID in pairs(Store.defaults) do add(categoryID) end
    for _, categoryID in pairs(Store.overrides) do add(categoryID) end
    for categoryID in pairs(Store.definitions) do add(categoryID) end
    for _, categoryID in ipairs(scriptCategories or {}) do add(categoryID) end

    table.sort(out, function(a, b)
        return string.lower(Store.getCategoryDisplayName(a)) < string.lower(Store.getCategoryDisplayName(b))
    end)
    return out
end

function Store.flush()
    Store.ensureLoaded()
    local ok = true

    if Store.overridesDirty then
        local sections = { Meta = { SchemaVersion = 1 } }
        for fullType, categoryID in pairs(Store.overrides) do
            sections[fullType] = { Category = categoryID }
        end
        ok = OverrideIni.saveAllOrdered(sections, { "Category" }) and ok
        if ok then Store.overridesDirty = false end
    end

    if Store.definitionsDirty then
        local sections = { Meta = { SchemaVersion = 1 } }
        for categoryID, definition in pairs(Store.definitions) do
            sections[categoryID] = { DisplayName = definition.displayName }
        end
        local saved = DefinitionIni.saveAllOrdered(sections, { "DisplayName" })
        ok = saved and ok
        if saved then Store.definitionsDirty = false end
    end

    return ok
end

return Store
