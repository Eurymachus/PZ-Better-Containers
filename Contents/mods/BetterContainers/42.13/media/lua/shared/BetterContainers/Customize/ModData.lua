local Helpers = require("BetterContainers/Helpers")

-- Pure data access/mutation for BetterContainers container customization.
-- Storage lives on IsoObject modData under:
--   modData.BetterContainers.customize[username]  (player override)
--   modData.BetterContainers.customize._global    (optional global fallback)

local ModData = {}

local CUSTOMIZE_KEY = "customize"
local GLOBAL_KEY = "_global"

local getRoot = Helpers.getModDataRoot

-- ---------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------

local function ensureCustomizeRoot(modDataTable, create)
    if not modDataTable then
        return nil
    end

    local root = getRoot(modDataTable, create)
    if not root then
        return nil
    end

    local customize = root[CUSTOMIZE_KEY]
    if customize == nil then
        if not create then return nil end
        customize = {}
        root[CUSTOMIZE_KEY] = customize
    elseif type(customize) ~= "table" then
        -- Defensive: if something polluted the key, reset to a table.
        if not create then return nil end
        customize = {}
        root[CUSTOMIZE_KEY] = customize
    end

    -- Ensure the reserved global node is either nil or a table.
    local g = customize[GLOBAL_KEY]
    if g ~= nil and type(g) ~= "table" then
        if create then
            customize[GLOBAL_KEY] = {}
        else
            customize[GLOBAL_KEY] = nil
        end
    end

    return customize
end

local function ensureUserNode(customizeRoot, username, create)
    if not (customizeRoot and username) then
        return nil
    end

    if username == GLOBAL_KEY then
        -- Never allow clobbering the reserved global key via username.
        return nil
    end

    local node = customizeRoot[username]
    if node == nil then
        if not create then return nil end
        node = {}
        customizeRoot[username] = node
    elseif type(node) ~= "table" then
        if not create then return nil end
        node = {}
        customizeRoot[username] = node
    end

    return node
end

local function sanitizePayload(payload)
    if payload == nil then
        return nil
    end

    if type(payload) ~= "table" then
        return {}
    end

    local out = {}

    -- Name: keep non-empty string only
    if type(payload.name) == "string" then
        local name = payload.name
        -- Trim simple whitespace
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" then
            out.name = name
        end
    end

    -- Icon: keep non-empty string only (fullType or texture id - caller decides)
    if type(payload.icon) == "string" then
        local icon = payload.icon
        icon = icon:gsub("^%s+", ""):gsub("%s+$", "")
        if icon ~= "" then
            out.icon = icon
        end
    end

    -- Color: prefer table. Accept {r,g,b,a} or {0.1,0.2,0.3,1} or {r=...,g=...,b=...,a=...}
    local c = payload.color
    if type(c) == "table" then
        local r, g, b, a

        if c.r ~= nil or c.g ~= nil or c.b ~= nil or c.a ~= nil then
            r, g, b, a = c.r, c.g, c.b, c.a
        else
            r, g, b, a = c[1], c[2], c[3], c[4]
        end

        -- Only keep if numeric-ish
        if tonumber(r) and tonumber(g) and tonumber(b) then
            out.color = {
                r = tonumber(r),
                g = tonumber(g),
                b = tonumber(b),
                a = tonumber(a) or 1,
            }
        end
    end

    return out
end

local function isEmptyPayload(p)
    if not p or type(p) ~= "table" then
        return true
    end
    return p.name == nil and p.icon == nil and p.color == nil
end

-- ---------------------------------------------------------
-- Public API (IsoObject-backed)
-- ---------------------------------------------------------

-- Returns the raw per-user customization table (or nil).
ModData.getUser =  function(parent, username)
    if not (parent and parent.getModData and username) then
        return nil
    end

    local customize = ensureCustomizeRoot(parent:getModData(), false)
    if not customize then return nil end

    local node = customize[username]
    return (type(node) == "table") and node or nil
end

-- Returns the raw global customization table (or nil).
ModData.getGlobal = function(parent)
    if not (parent and parent.getModData) then
        return nil
    end

    local customize = ensureCustomizeRoot(parent:getModData(), false)
    if not customize then return nil end

    local node = customize[GLOBAL_KEY]
    return (type(node) == "table") and node or nil
end

-- Returns effective customization with precedence:
--   user override -> global -> nil
ModData.getEffective = function(parent, username)
    local u = ModData.getUser(parent, username)
    if u then return u end
    return ModData.getGlobal(parent)
end

-- Sets per-user customization payload. If payload sanitizes to empty, clears instead.
ModData.setUser = function(parent, username, payload)
    if not (parent and parent.getModData and username) then
        return false
    end

    local customize = ensureCustomizeRoot(parent:getModData(), true)
    if not customize then return false end

    local clean = sanitizePayload(payload)
    if isEmptyPayload(clean) then
        customize[username] = nil
        return true
    end

    customize[username] = clean
    return true
end

-- Clears per-user customization.
ModData.clearUser = function(parent, username)
    if not (parent and parent.getModData and username) then
        return false
    end

    local customize = ensureCustomizeRoot(parent:getModData(), false)
    if not customize then return false end

    customize[username] = nil
    return true
end

-- Sets global customization payload. If payload sanitizes to empty, clears instead.
ModData.setGlobal = function(parent, payload)
    if not (parent and parent.getModData) then
        return false
    end

    local customize = ensureCustomizeRoot(parent:getModData(), true)
    if not customize then return false end

    local clean = sanitizePayload(payload)
    if isEmptyPayload(clean) then
        customize[GLOBAL_KEY] = nil
        return true
    end

    customize[GLOBAL_KEY] = clean
    return true
end

-- Clears global customization.
ModData.clearGlobal = function(parent)
    if not (parent and parent.getModData) then
        return false
    end

    local customize = ensureCustomizeRoot(parent:getModData(), false)
    if not customize then return false end

    customize[GLOBAL_KEY] = nil
    return true
end

ModData.setVanillaName = function(container, parent, payload)
    if not (container and parent) then return end

    local md = parent.getModData and parent:getModData()
    if not md then return end

    local key = container:getType() .. "_customContainerName"

    local isIsoObject = instanceof(parent, "IsoObject")
    local isItem      = instanceof(parent, "InventoryItem")

    -- Reset / clear
    if (not payload) or payload.name == nil or payload.name == "" then

        if isIsoObject then
            md[key] = nil

            -- Only safe if the container is actually attached to an IsoObject
            if container.getParent and container:getParent() and container.setCustomName then
                container:setCustomName(nil)
            end

        elseif isItem then
            local oldName = md[key]
            md[key] = nil

            -- Only restore if we actually captured a previous name
            if oldName and oldName ~= "" and parent.setName then
                parent:setName(oldName)
            end

            if parent.setCustomName then
                parent:setCustomName(false)
            end
        end

        Helpers.dlog("Reset Vanilla Name")
        return
    end

    if isIsoObject then
        md[key] = payload.name

        if container.getParent and container:getParent() and container.setCustomName then
            container:setCustomName(payload.name)
        end

        Helpers.dlog("Applied Vanilla Name to world container: " .. tostring(payload.name))
        return

    elseif isItem then
        -- Capture current name once so reset can restore
        local oldName = md[key]
        md[key] = oldName or parent.getName and parent:getName()

        if parent.setName then
            parent:setName(payload.name)
        end
        if parent.setCustomName then
            parent:setCustomName(true)
        end

        Helpers.dlog("Applied Vanilla Name to item: " .. tostring(payload.name))
    end
end

-- Utility: expose sanitize for callers (UI/presets) if they want consistent normalization.
function ModData.sanitize(payload)
    return sanitizePayload(payload)
end

return ModData
