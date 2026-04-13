local Helpers = require("BetterContainers/Helpers")

-- Pure data access/mutation for BetterContainers container customization.
-- Storage lives on parent modData under:
--   modData.BetterContainers.customize[username]  (player override)
--   modData.BetterContainers.customize._global    (optional global fallback)
--
-- Root payload fields apply to container index 0.
-- Additional containers are stored under:
--   customize[username].containers[index]
--   customize._global.containers[index]

local ModData = {}

local CUSTOMIZE_KEY = "customize"
local GLOBAL_KEY = "_global"

local getRoot = Helpers.getModDataRoot

local function normalizeContainerIndex(containerIndex)
    local idx = tonumber(containerIndex) or 0
    idx = math.floor(idx)
    if idx < 0 then idx = 0 end
    return idx
end

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
        if not create then return nil end
        customize = {}
        root[CUSTOMIZE_KEY] = customize
    end

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

local function ensureContainersNode(node, create)
    if type(node) ~= "table" then
        return nil
    end

    local containers = node.containers
    if containers == nil then
        if not create then return nil end
        containers = {}
        node.containers = containers
    elseif type(containers) ~= "table" then
        if not create then return nil end
        containers = {}
        node.containers = containers
    end

    return containers
end

local function sanitizeIcon(icon)
    if type(icon) == "string" then
        local v = icon:gsub("^%s+", ""):gsub("%s+$", "")
        if v ~= "" then
            -- Legacy format -> lazy normalize to new runtime shape
            return {
                kind = "item",
                value = v,
            }
        end
        return nil
    end

    if type(icon) == "table" then
        local kind = type(icon.kind) == "string" and icon.kind:gsub("^%s+", ""):gsub("%s+$", "") or nil
        local value = type(icon.value) == "string" and icon.value:gsub("^%s+", ""):gsub("%s+$", "") or nil

        if kind and kind ~= "" and value and value ~= "" then
            return {
                kind = kind,
                value = value,
            }
        end
    end

    return nil
end

local function sanitizePayload(payload)
    if payload == nil then
        return nil
    end

    if type(payload) ~= "table" then
        return {}
    end

    local out = {}

    if type(payload.name) == "string" then
        local name = payload.name:gsub("^%s+", ""):gsub("%s+$", "")
        if name ~= "" then
            out.name = name
        end
    end

    local icon = sanitizeIcon(payload.icon)
    if icon ~= nil then
        out.icon = icon
    end

    local c = payload.color
    if type(c) == "table" then
        local r, g, b, a

        if c.r ~= nil or c.g ~= nil or c.b ~= nil or c.a ~= nil then
            r, g, b, a = c.r, c.g, c.b, c.a
        else
            r, g, b, a = c[1], c[2], c[3], c[4]
        end

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

local function sanitizeRootPayload(node)
    if type(node) ~= "table" then
        return nil
    end

    local clean = sanitizePayload({
        name = node.name,
        icon = node.icon,
        color = node.color,
    })

    if isEmptyPayload(clean) then
        return nil
    end

    return clean
end

local function pruneNode(node)
    if type(node) ~= "table" then
        return true
    end

    if not isEmptyPayload(sanitizeRootPayload(node)) then
        return false
    end

    local containers = node.containers
    if type(containers) == "table" then
        local any = false
        for k, v in pairs(containers) do
            if type(v) == "table" and not isEmptyPayload(sanitizePayload(v)) then
                any = true
            else
                containers[k] = nil
            end
        end
        if any then
            return false
        end
        node.containers = nil
    end

    return true
end

ModData.getContainerIndex = function(container, parent)
    if not container then
        return 0
    end

    if parent and instanceof(parent, "IsoObject") and parent.getContainerCount and parent.getContainerByIndex then
        local count = parent:getContainerCount() or 0
        for i = 0, count - 1 do
            local c = parent:getContainerByIndex(i)
            if c == container then
                return i
            end
        end
    end

    return 0
end

ModData.getUser = function(parent, username, containerIndex)
    if not (parent and parent.getModData and username) then
        return nil
    end

    local idx = normalizeContainerIndex(containerIndex)
    local customize = ensureCustomizeRoot(parent:getModData(), false)
    if not customize then return nil end

    local node = customize[username]
    if type(node) ~= "table" then return nil end

    if idx == 0 then
        return sanitizeRootPayload(node)
    end

    local containers = ensureContainersNode(node, false)
    if not containers then return nil end

    local payload = containers[idx]
    if type(payload) ~= "table" then return nil end

    local clean = sanitizePayload(payload)
    if isEmptyPayload(clean) then return nil end
    return clean
end

ModData.getGlobal = function(parent, containerIndex)
    if not (parent and parent.getModData) then
        return nil
    end

    local idx = normalizeContainerIndex(containerIndex)
    local customize = ensureCustomizeRoot(parent:getModData(), false)
    if not customize then return nil end

    local node = customize[GLOBAL_KEY]
    if type(node) ~= "table" then return nil end

    if idx == 0 then
        return sanitizeRootPayload(node)
    end

    local containers = ensureContainersNode(node, false)
    if not containers then return nil end

    local payload = containers[idx]
    if type(payload) ~= "table" then return nil end

    local clean = sanitizePayload(payload)
    if isEmptyPayload(clean) then return nil end
    return clean
end

ModData.getEffective = function(parent, username, containerIndex)
    local u = ModData.getUser(parent, username, containerIndex)
    if u then return u end
    return ModData.getGlobal(parent, containerIndex)
end

ModData.setUser = function(parent, username, payload, containerIndex)
    if not (parent and parent.getModData and username) then
        return false
    end

    local idx = normalizeContainerIndex(containerIndex)
    local customize = ensureCustomizeRoot(parent:getModData(), true)
    if not customize then return false end

    local node = ensureUserNode(customize, username, true)
    if not node then return false end

    local clean = sanitizePayload(payload)

    if idx == 0 then
        node.name = clean and clean.name or nil
        node.icon = clean and clean.icon or nil
        node.color = clean and clean.color or nil
    else
        local containers = ensureContainersNode(node, true)
        if not containers then return false end

        if isEmptyPayload(clean) then
            containers[idx] = nil
        else
            containers[idx] = clean
        end
    end

    if pruneNode(node) then
        customize[username] = nil
    end

    return true
end

ModData.clearUser = function(parent, username, containerIndex)
    if not (parent and parent.getModData and username) then
        return false
    end

    local idx = normalizeContainerIndex(containerIndex)
    local customize = ensureCustomizeRoot(parent:getModData(), false)
    if not customize then return false end

    local node = customize[username]
    if type(node) ~= "table" then return false end

    if idx == 0 then
        node.name = nil
        node.icon = nil
        node.color = nil
    else
        local containers = ensureContainersNode(node, false)
        if containers then
            containers[idx] = nil
        end
    end

    if pruneNode(node) then
        customize[username] = nil
    end

    return true
end

ModData.setGlobal = function(parent, payload, containerIndex)
    if not (parent and parent.getModData) then
        return false
    end

    local idx = normalizeContainerIndex(containerIndex)
    local customize = ensureCustomizeRoot(parent:getModData(), true)
    if not customize then return false end

    local node = customize[GLOBAL_KEY]
    if type(node) ~= "table" then
        node = {}
        customize[GLOBAL_KEY] = node
    end

    local clean = sanitizePayload(payload)

    if idx == 0 then
        node.name = clean and clean.name or nil
        node.icon = clean and clean.icon or nil
        node.color = clean and clean.color or nil
    else
        local containers = ensureContainersNode(node, true)
        if not containers then return false end

        if isEmptyPayload(clean) then
            containers[idx] = nil
        else
            containers[idx] = clean
        end
    end

    if pruneNode(node) then
        customize[GLOBAL_KEY] = nil
    end

    return true
end

ModData.clearGlobal = function(parent, containerIndex)
    if not (parent and parent.getModData) then
        return false
    end

    local idx = normalizeContainerIndex(containerIndex)
    local customize = ensureCustomizeRoot(parent:getModData(), false)
    if not customize then return false end

    local node = customize[GLOBAL_KEY]
    if type(node) ~= "table" then return false end

    if idx == 0 then
        node.name = nil
        node.icon = nil
        node.color = nil
    else
        local containers = ensureContainersNode(node, false)
        if containers then
            containers[idx] = nil
        end
    end

    if pruneNode(node) then
        customize[GLOBAL_KEY] = nil
    end

    return true
end

ModData.setVanillaName = function(container, parent, payload, containerIndex)
    if not (container and parent) then return end

    local md = parent.getModData and parent:getModData()
    if not md then return end

    local idx = normalizeContainerIndex(containerIndex)
    local key = "container_" .. tostring(idx) .. "_customContainerName"

    local isIsoObject = instanceof(parent, "IsoObject")
    local isItem      = instanceof(parent, "InventoryItem")

    if (not payload) or payload.name == nil or payload.name == "" then
        if isIsoObject then
            md[key] = getTextOrNull("IGUI_ContainerTitle_" .. container:getType())

            if container.getParent and container:getParent() and container.setCustomName then
                container:setCustomName(getTextOrNull("IGUI_ContainerTitle_" .. container:getType()))
            end
        elseif isItem then
            local oldName = md[key]
            md[key] = nil

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
        local oldName = md[key]
        md[key] = oldName or (parent.getScriptItem and parent:getScriptItem() and parent:getScriptItem():getDisplayName())

        if parent.setName then
            parent:setName(payload.name)
        end
        if parent.setCustomName then
            parent:setCustomName(true)
        end

        Helpers.dlog("Applied Vanilla Name to item: " .. tostring(payload.name))
    end
end

function ModData.sanitize(payload)
    return sanitizePayload(payload)
end

return ModData