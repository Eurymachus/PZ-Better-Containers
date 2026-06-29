local EC = require("BetterContainers/Helpers")
local IniWriter = require("BetterContainers/_IO/IniWriter")
local INI = IniWriter.makeFeature("SavedPresets")

local SavedPresets = {}

-- ---------------------------------------------------------
-- Parsing
-- ---------------------------------------------------------

local function _trim(s)
    if s == nil then return nil end
    return (tostring(s):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _normName(s)
    s = _trim(s)
    if not s then return "" end
    return tostring(s):lower()
end

local function _parseColorRow(row)
    if type(row) ~= "table" then return nil end

    -- Option A: r/g/b/a keys
    local r = tonumber(row.r)
    local g = tonumber(row.g)
    local b = tonumber(row.b)
    local a = tonumber(row.a)

    if r and g and b then
        return { r = r, g = g, b = b, a = a }
    end

    -- Option B: color="r,g,b,a"
    local c = row.color
    if type(c) == "string" then
        local parts = {}
        for token in c:gmatch("[^,]+") do
            parts[#parts + 1] = tonumber(_trim(token))
        end
        if parts[1] and parts[2] and parts[3] then
            return { r = parts[1], g = parts[2], b = parts[3], a = parts[4] }
        end
    end

    return nil
end

local function _rowToPreset(sectionName, row)
    if not sectionName or type(row) ~= "table" then
        return nil
    end

    local name = row.name or row.label or sectionName
    local color = _parseColorRow(row)

    local category = row.category or row.cat
    local sub = row.sub or row.subcategory or row.group

    local payload = {}
    if name and name ~= "" then payload.name = tostring(name) end

    local icon = nil
    local iconKind = row.icon_kind or row.kind
    local iconValue = row.icon_value

    if iconKind and iconValue then
        icon = {
            kind = tostring(iconKind),
            value = tostring(iconValue),
        }
    else
        local legacy = row.icon or row.item or row.texture
        if legacy and legacy ~= "" then
            icon = {
                kind = "item",
                value = tostring(legacy),
            }
        end
    end

    if icon then payload.icon = icon end
    if color then payload.color = color end

    if not (payload.name or payload.icon or payload.color) then
        return nil
    end

    return {
        id = tostring(sectionName),
        name = tostring(name),
        category = category and tostring(category) or nil,
        sub = sub and tostring(sub) or nil,
        payload = payload,
    }
end

-- ---------------------------------------------------------
-- Internal: find existing section by preset name
-- ---------------------------------------------------------

local function _findSectionByName(allSections, presetName)
    local want = _normName(presetName)
    if want == "" then return nil end

    for sectionName, row in pairs(allSections) do
        if type(row) == "table" then
            local rowName = row.name or row.label or sectionName
            if _normName(rowName) == want then
                return tostring(sectionName), row
            end
        end
    end

    return nil
end

local function _makeNewId(allSections, presetName)
    local baseId = tostring(presetName):lower():gsub("%s+", "_"):gsub("[^%w_]", "")
    if baseId == "" then baseId = "preset" end

    local id = baseId
    local i = 1
    while allSections[id] do
        i = i + 1
        id = baseId .. "_" .. tostring(i)
    end
    return id
end

-- ---------------------------------------------------------
-- Public
-- ---------------------------------------------------------

-- Returns flat list: { preset, ... }
SavedPresets.loadAll = function()
    local sections = INI.loadAll() or {}
    local out = {}

    for sectionName, row in pairs(sections) do
        local p = _rowToPreset(sectionName, row)
        if p then
            out[#out + 1] = p
        end
    end

    table.sort(out, function(a, b)
        return tostring(a.name) < tostring(b.name)
    end)

    return out
end

-- Save new preset (NO DUPLICATES):
-- If a preset with the same name already exists, it is overwritten.
-- payload = { name=string, icon=string?, color={r,g,b,a}? }
-- meta    = { category=string?, sub=string? }
SavedPresets.saveNew = function(payload, meta)
    if type(payload) ~= "table" then return nil end
    local name = _trim(payload.name)
    if not name or name == "" then return nil end

    meta = meta or {}

    local all = INI.loadAll() or {}

    -- If name exists already, reuse that section id (overwrite)
    local existingSection = _findSectionByName(all, name)
    local id = existingSection or _makeNewId(all, name)

    local row = {}

    row.name = tostring(name)

    if type(payload.icon) == "table" then
        local kind = tostring(payload.icon.kind or "")
        local value = tostring(payload.icon.value or "")

        if kind ~= "" and value ~= "" then
            row.icon_kind = kind
            row.icon_value = value
        end
    elseif payload.icon and tostring(payload.icon) ~= "" then
        -- Legacy write fallback
        row.icon_kind = "item"
        row.icon_value = tostring(payload.icon)
    end

    if type(payload.color) == "table" then
        row.r = tonumber(payload.color.r)
        row.g = tonumber(payload.color.g)
        row.b = tonumber(payload.color.b)
        if payload.color.a ~= nil then
            row.a = tonumber(payload.color.a)
        end
    end

    if meta.category and tostring(meta.category) ~= "" then
        row.category = tostring(meta.category)
    end
    if meta.sub and tostring(meta.sub) ~= "" then
        row.sub = tostring(meta.sub)
    end

    -- This will set OR replace the section row.
    INI.setOrdered(id, row, { "name", "icon_kind", "icon_value", "r", "g", "b", "a" })

    return _rowToPreset(id, row)
end

SavedPresets.deleteById = function(id)
    if not id or tostring(id) == "" then return false end
    return INI.delete(tostring(id)) == true
end

-- Delete by preset display name (case/whitespace-insensitive)
SavedPresets.deleteByName = function(presetName)
    local name = _trim(presetName)
    if not name or name == "" then return false end

    local all = INI.loadAll() or {}
    local sectionName = _findSectionByName(all, name)
    if not sectionName then
        return false
    end

    return INI.delete(tostring(sectionName)) == true
end

return SavedPresets
