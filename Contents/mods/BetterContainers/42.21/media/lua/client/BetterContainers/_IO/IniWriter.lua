local ROOT = "BetterContainers"
local IO = require("BetterContainers/_IO/_IO")
IO.PER_SAVE_ROOT = ROOT

local IniWriter = {}

-- -----------------------------
-- Stateless core (explicit file)
-- -----------------------------

-- Returns: { [sectionName] = rowTable }
IniWriter.loadAll = function(filename, isSaveOnly)
    if not filename or filename == "" then return {} end
    local sections = IO.readIniSections(filename, isSaveOnly)
    return (type(sections) == "table") and sections or {}
end

-- Overwrites file.
IniWriter.saveAll = function(filename, sections, isSaveOnly)
    if not filename or filename == "" then return false end
    if type(sections) ~= "table" then sections = {} end
    return IO.writeIniSections(filename, sections, isSaveOnly)
end

-- Overwrites file with deterministic key order within each section row.
IniWriter.saveAllOrdered = function(filename, sections, keyOrder, isSaveOnly)
    if not filename or filename == "" then return false end
    if type(sections) ~= "table" then sections = {} end
    IO.writeIniSectionsOrdered(filename, sections, keyOrder, isSaveOnly)
    return true
end

IniWriter.listSections = function(filename, isSaveOnly)
    local all = IniWriter.loadAll(filename, isSaveOnly)
    local keys = {}
    for k, _ in pairs(all) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

IniWriter.get = function(filename, sectionName, isSaveOnly)
    if not (filename and sectionName) then return nil end
    local row = IO.getIniSectionRow(filename, sectionName, isSaveOnly)
    return (type(row) == "table") and row or nil
end

IniWriter.set = function(filename, sectionName, row, isSaveOnly)
    if not (filename and sectionName) then return false end
    if type(row) ~= "table" then row = {} end
    return IO.setIniSectionRow(filename, sectionName, row, isSaveOnly)
end

IniWriter.setOrdered = function(filename, sectionName, row, keyOrder, isSaveOnly)
    if not (filename and sectionName) then return false end
    if row == nil then
        return IniWriter.delete(filename, sectionName, isSaveOnly)
    end
    IO.setIniSectionRowOrdered(filename, sectionName, row, keyOrder, isSaveOnly)
    return true
end

IniWriter.delete = function(filename, sectionName, isSaveOnly)
    if not (filename and sectionName) then return false end
    return IO.deleteIniSection(filename, sectionName, isSaveOnly)
end

-- fn(rowOrNil) -> newRowTable OR nil (nil means delete section)
IniWriter.update = function(filename, sectionName, fn, isSaveOnly)
    if not (filename and sectionName and type(fn) == "function") then return false end

    local cur = IniWriter.get(filename, sectionName, isSaveOnly)
    local nextRow = fn(cur)

    if nextRow == nil then
        return IniWriter.delete(filename, sectionName, isSaveOnly)
    end

    return IniWriter.set(filename, sectionName, nextRow, isSaveOnly)
end

IniWriter.updateOrdered = function(filename, sectionName, fn, keyOrder, isSaveOnly)
    if not (filename and sectionName and type(fn) == "function") then return false end

    local cur = IniWriter.get(filename, sectionName, isSaveOnly)
    local nextRow = fn(cur)

    if nextRow == nil then
        return IniWriter.delete(filename, sectionName, isSaveOnly)
    end

    IO.setIniSectionRowOrdered(filename, sectionName, nextRow, keyOrder, isSaveOnly)
    return true
end

-- -----------------------------
-- Filename helpers
-- -----------------------------

-- ROOT-scoped: e.g "ModName/Feature.ini"
IniWriter.makeFilename = function(featureName)
    featureName = tostring(featureName or "Data")
    return ROOT .. "/" .. featureName .. ".ini"
end

-- Base lua root: "Feature.ini"
IniWriter.makeBaseFilename = function(name)
    name = tostring(name or ROOT)
    return name .. ".ini"
end

-- -----------------------------
-- Instance creators (bound file)
-- -----------------------------

local function _makeInstance(filename, isSaveOnly)
    local w = {
        filename = filename,
        isSaveOnly = isSaveOnly and true or false,
    }

    w.loadAll = function()
        return IniWriter.loadAll(w.filename, w.isSaveOnly)
    end

    w.saveAll = function(sections)
        return IniWriter.saveAll(w.filename, sections, w.isSaveOnly)
    end

    w.saveAllOrdered = function(sections, keyOrder)
        return IniWriter.saveAllOrdered(w.filename, sections, keyOrder, w.isSaveOnly)
    end

    w.listSections = function()
        return IniWriter.listSections(w.filename, w.isSaveOnly)
    end

    w.get = function(sectionName)
        return IniWriter.get(w.filename, sectionName, w.isSaveOnly)
    end

    w.set = function(sectionName, row)
        return IniWriter.set(w.filename, sectionName, row, w.isSaveOnly)
    end

    w.setOrdered = function(sectionName, row, keyOrder)
        return IniWriter.setOrdered(w.filename, sectionName, row, keyOrder, w.isSaveOnly)
    end

    w.delete = function(sectionName)
        return IniWriter.delete(w.filename, sectionName, w.isSaveOnly)
    end

    w.update = function(sectionName, fn)
        return IniWriter.update(w.filename, sectionName, fn, w.isSaveOnly)
    end

    w.updateOrdered = function(sectionName, fn, keyOrder)
        return IniWriter.updateOrdered(w.filename, sectionName, fn, keyOrder, w.isSaveOnly)
    end

    return w
end

-- ROOT-based INIs (your normal per-mod pattern).
-- Example: local Presets = IniWriter.makeFeature("SavedPresets", true)
IniWriter.makeFeature = function(featureName, isSaveOnly)
    local filename = IniWriter.makeFilename(featureName)
    return _makeInstance(filename, isSaveOnly)
end

-- Base lua root INIs (no ROOT).
-- Example: local GlobalMeta = IniWriter.make("GlobalMeta")
IniWriter.make = function(name)
    local filename = IniWriter.makeBaseFilename(name)
    return _makeInstance(filename, false)
end

return IniWriter