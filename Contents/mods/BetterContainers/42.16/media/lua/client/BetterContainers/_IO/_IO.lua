local IO = {}

-- Portable INI reader/writer (agnostic, safe to copy between mods).
-- Supports:
--   - [Section] headers
--   - key=value rows (numbers + booleans coerced)
--   - ignores blank lines and comment lines starting with ';' or '#'
--   - writeIniSections writes deterministic output (sorted sections/keys)
--
-- Notes:
--   - This is intentionally minimal: no schema, no mod coupling, no logging.
--   - Uses vanilla PZ file I/O: getFileReader / getFileWriter.

-- ---------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------

local function _trim(s)
    if s == nil then return nil end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _isCommentOrEmpty(line)
    if not line then return true end
    local s = _trim(line)
    if s == "" then return true end
    local c = s:sub(1, 1)
    return c == ";" or c == "#"
end

local function _parseValue(raw)
    if raw == nil then return nil end
    local s = _trim(raw)
    if s == nil then return nil end

    -- booleans
    if s == "true" then return true end
    if s == "false" then return false end

    -- numbers (int/float)
    local n = tonumber(s)
    if n ~= nil then
        return n
    end

    -- string (as-is, trimmed)
    return s
end

local function _stringifyValue(v)
    if v == nil then return nil end
    local t = type(v)
    if t == "boolean" then
        return v and "true" or "false"
    end
    if t == "number" then
        -- Preserve numeric formatting reasonably; tostring is fine.
        return tostring(v)
    end
    return tostring(v)
end

local function _sortedKeys(t)
    local keys = {}
    for k, _ in pairs(t) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return keys
end

-- ---------------------------------------------------------
-- Routing (optional per-save)
-- ---------------------------------------------------------

-- Default root for per-save writes. Override from a mod if desired:
--   local IO = require("BUI/_IO/_IO")
--   IO.PER_SAVE_ROOT = "MyRoot"
IO.PER_SAVE_ROOT = IO.PER_SAVE_ROOT or "EURY"

local function _resolveFilename(filename, isSaveOnly)
    if not isSaveOnly then
        return filename
    end

    local p = getCurrentSaveName and getCurrentSaveName() or nil
    if not p then
        return nil
    end

    local s = tostring(p):gsub("\\", "/")
    local i = s:find("/Saves/")
    if not i then
        return nil
    end

    local key = s:sub(i + 7) -- after "/Saves/"
    if not key or key == "" then
        return nil
    end

    return tostring(IO.PER_SAVE_ROOT) .. "/" .. key .. "/" .. tostring(filename)
end

-- ---------------------------------------------------------
-- Public: INI read
-- ---------------------------------------------------------

-- Returns table:
--   {
--     ["SectionName"] = { key = value, ... },
--     ...
--   }
IO.readIniSections = function(filename, isSaveOnly)
    if not filename or filename == "" then
        return {}
    end

    local resolved = _resolveFilename(filename, isSaveOnly)
    if not resolved or resolved == "" then
        return {}
    end

    local reader = getFileReader(resolved, false)
    if not reader then
        return {}
    end

    local out = {}
    local currentSection = nil

    while true do
        local line = reader:readLine()
        if line == nil then break end
        if _isCommentOrEmpty(line) then
            -- ignore
        else
            local s = _trim(line)

            -- Section header
            local sec = s:match("^%[(.-)%]$")
            if sec then
                sec = _trim(sec)
                if sec ~= "" then
                    currentSection = sec
                    if out[currentSection] == nil or type(out[currentSection]) ~= "table" then
                        out[currentSection] = {}
                    end
                end
            else
                -- key=value
                local k, v = s:match("^(.-)=(.*)$")
                if k ~= nil then
                    k = _trim(k)
                    v = _trim(v)
                    if k ~= "" then
                        if not currentSection then
                            -- If the file has key/values before any section header,
                            -- treat them as belonging to a default section.
                            currentSection = "Default"
                            if out[currentSection] == nil or type(out[currentSection]) ~= "table" then
                                out[currentSection] = {}
                            end
                        end
                        out[currentSection][k] = _parseValue(v)
                    end
                end
            end
        end
    end

    reader:close()
    return out
end

-- Convenience: get a single section row table or nil.
IO.getIniSectionRow = function(filename, sectionName, isSaveOnly)
    if not (filename and sectionName) then
        return nil
    end
    local all = IO.readIniSections(filename, isSaveOnly)
    local row = all[sectionName]
    return (type(row) == "table") and row or nil
end

-- ---------------------------------------------------------
-- Public: INI write
-- ---------------------------------------------------------

-- Writes all sections in deterministic order (sorted sections + keys).
-- Overwrites existing file.
IO.writeIniSections = function(filename, sections, isSaveOnly)
    if not filename or filename == "" then
        return false
    end

    if type(sections) ~= "table" then
        sections = {}
    end

    local resolved = _resolveFilename(filename, isSaveOnly)
    if not resolved or resolved == "" then
        return false
    end

    local writer = getFileWriter(resolved, true, false)
    if not writer then
        return false
    end

    local sectionNames = _sortedKeys(sections)

    for si = 1, #sectionNames do
        local secName = sectionNames[si]
        local row = sections[secName]
        if type(row) == "table" then
            writer:write("[" .. tostring(secName) .. "]\n")

            local keys = _sortedKeys(row)
            for ki = 1, #keys do
                local k = keys[ki]
                local v = row[k]
                local sv = _stringifyValue(v)
                if sv ~= nil then
                    writer:write(tostring(k) .. "=" .. sv .. "\n")
                end
            end

            -- blank line between sections for readability
            writer:write("\n")
        end
    end

    writer:close()
    return true
end

-- Writes all sections with preferred key order, then remaining keys sorted.
-- keyOrder: array like {"name","icon","r","g","b","a"}
IO.writeIniSectionsOrdered = function(filename, sections, keyOrder, isSaveOnly)
    if not filename or filename == "" then
        return false
    end
    if type(sections) ~= "table" then
        sections = {}
    end
    if type(keyOrder) ~= "table" then
        keyOrder = {}
    end

    local resolved = _resolveFilename(filename, isSaveOnly)
    if not resolved or resolved == "" then
        return false
    end

    local writer = getFileWriter(resolved, true, false)
    if not writer then
        return false
    end

    local sectionNames = _sortedKeys(sections)

    local function _hasKey(t, k)
        return t and t[k] ~= nil
    end

    for si = 1, #sectionNames do
        local secName = sectionNames[si]
        local row = sections[secName]
        if type(row) == "table" then
            writer:write("[" .. tostring(secName) .. "]\n")

            local written = {}

            -- preferred order first
            for i = 1, #keyOrder do
                local k = keyOrder[i]
                if type(k) == "string" and _hasKey(row, k) then
                    local sv = _stringifyValue(row[k])
                    if sv ~= nil then
                        writer:write(tostring(k) .. "=" .. sv .. "\n")
                    end
                    written[k] = true
                end
            end

            -- then the rest sorted
            local keys = _sortedKeys(row)
            for ki = 1, #keys do
                local k = keys[ki]
                if not written[k] then
                    local sv = _stringifyValue(row[k])
                    if sv ~= nil then
                        writer:write(tostring(k) .. "=" .. sv .. "\n")
                    end
                end
            end

            writer:write("\n")
        end
    end

    writer:close()
    return true
end

-- Convenience: set/replace one section row (loads file, updates section, writes file).
IO.setIniSectionRow = function(filename, sectionName, row, isSaveOnly)
    if not (filename and sectionName) then
        return false
    end
    if type(row) ~= "table" then
        row = {}
    end

    local all = IO.readIniSections(filename, isSaveOnly)
    all[sectionName] = row
    return IO.writeIniSections(filename, all, isSaveOnly)
end

IO.setIniSectionRowOrdered = function(filename, sectionName, row, keyOrder, isSaveOnly)
    if not (filename and sectionName) then
        return false
    end
    if type(row) ~= "table" then
        row = {}
    end
    local all = IO.readIniSections(filename, isSaveOnly)
    all[sectionName] = row
    return IO.writeIniSectionsOrdered(filename, all, keyOrder, isSaveOnly)
end

-- Convenience: delete a section (loads file, removes section, writes file).
IO.deleteIniSection = function(filename, sectionName, isSaveOnly)
    if not (filename and sectionName) then
        return false
    end

    local all = IO.readIniSections(filename, isSaveOnly)
    if all[sectionName] == nil then
        return true
    end

    all[sectionName] = nil
    return IO.writeIniSections(filename, all, isSaveOnly)
end

return IO