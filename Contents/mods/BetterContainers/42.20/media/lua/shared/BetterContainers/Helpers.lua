EURY_CONTAINERS = EURY_CONTAINERS or {}

EURY_CONTAINERS.Icons = {
    Save = "media/ui/BetterContainers/save.png",
}

EURY_CONTAINERS.Icons.Loaded = {
    Save = getTexture(EURY_CONTAINERS.Icons.Save),
}

EURY_CONTAINERS.MODULE_ID = "BetterContainers"
EURY_CONTAINERS.OPTIONS_APPLIED = EURY_CONTAINERS.MODULE_ID .. "_OptionsApplied"

LuaEventManager.AddEvent(EURY_CONTAINERS.OPTIONS_APPLIED)

local DEBUG = isDebugEnabled()

function EURY_CONTAINERS.dlog(message, bypass)
    if DEBUG or bypass then
        local title = "[" .. EURY_CONTAINERS.MODULE_ID .. "] "
        DebugLog.log(DebugType.General, title .. tostring(message))
    end
end

Events[EURY_CONTAINERS.OPTIONS_APPLIED].Add(function()
    ISInventoryPage.renderDirty = true
end)

local _ACTIVE_MOD_CACHE = {}

local function _normalizeModId(id)
    return (id and tostring(id) or ""):lower()
        :gsub("\\", "")
        :gsub("/", "")
        :gsub("%s+", "")
end

function EURY_CONTAINERS.isModActive(modId)
    local needle = _normalizeModId(modId)
    if needle == "" then
        return false
    end

    if _ACTIVE_MOD_CACHE[needle] ~= nil then
        return _ACTIVE_MOD_CACHE[needle]
    end

    local mods = getActivatedMods and getActivatedMods() or nil
    if not mods then
        _ACTIVE_MOD_CACHE[needle] = false
        return false
    end

    for i = 0, mods:size() - 1 do
        if _normalizeModId(mods:get(i)) == needle then
            _ACTIVE_MOD_CACHE[needle] = true
            return true
        end
    end

    _ACTIVE_MOD_CACHE[needle] = false
    return false
end

function EURY_CONTAINERS.isCleanUIActive()
    return EURY_CONTAINERS.isModActive("CleanUI")
end

function EURY_CONTAINERS.isPageLeft(page)
    local isCleanUILeft = EURY_CONTAINERS.isCleanUIActive()
        and type(page.isPageLeft) == "function"
        and page:isPageLeft()
    local isBCLeft = page.isPageLeft_BetterContainers and page:isPageLeft_BetterContainers()
    return isCleanUILeft or isBCLeft
end

-- Deterministic + safe icon resolver:
-- 1) If ScriptItem has IconsForTexture, use FIRST entry (index 0)
-- 2) Else use ScriptItem Icon
-- 3) Else fallback to getTexture(fullType)
--
-- Also supports Icon values like "Hammer" vs "Item_Hammer" by trying both.
local _BC_ICON_TEX_CACHE = _BC_ICON_TEX_CACHE or {}

local function _texFromId(id)
    if not id then return nil end

    -- If caller passes a direct path, don't try to "Item_" it.
    if type(id) == "string" and (id:find("/") or id:find("\\") or id:find("%.png$")) then
        return getTexture(id)
    end

    -- 1) As-is
    local tex = getTexture(id)
    if tex then return tex end

    -- 2) If it wasn't already Item_*, try Item_<id>
    if type(id) == "string" and string.sub(id, 1, 5) ~= "Item_" then
        tex = getTexture("Item_" .. id)
        if tex then return tex end
    end

    -- 3) If it WAS Item_*, also try without the prefix (some UI sets use bare ids)
    if type(id) == "string" and string.sub(id, 1, 5) == "Item_" then
        tex = getTexture(string.sub(id, 6))
        if tex then return tex end
    end

    return nil
end

-- iconRef = Base.HammerForged or Base.Hammer:0 or Base.Mov_FancyLowTable
function EURY_CONTAINERS.getIconTexture(iconRef)
    if not iconRef then return end

    -- New canonical format:
    --   { kind = "item" | "container", value = "..." }
    -- Legacy format:
    --   "Base.Hammer"
    --   "Base.SomeItem:0"
    if type(iconRef) == "table" then
        local kind = tostring(iconRef.kind or "")
        local value = tostring(iconRef.value or "")
        --EURY_CONTAINERS.dlog("getIconTexture from kind=" .. kind .. " and value=" .. value)

        if kind == "container" then
            if value == "" then return nil end
            if ContainerButtonIcons and ContainerButtonIcons[value] then
                return ContainerButtonIcons[value], value
            end
            return nil
        end

        -- Unknown kinds fall through as item-like only if they expose a value.
        if value == "" then
            return nil
        end
        iconRef = value
    end

    if not iconRef then return end

    local key = tostring(iconRef)
    --EURY_CONTAINERS.dlog("getIconTexture from key=" .. key)

    local cached = _BC_ICON_TEX_CACHE[key]
    if cached then
        if type(cached) == "table" then
            return cached.tex, cached.iconId
        end
        return cached, nil
    end

    local fullType = key
    local idx = 0

    do
        local a, b = key:match("^(.-):(%d+)$")
        if a and b then
            fullType = a
            idx = tonumber(b) or 0
        end
    end

    local tex = nil
    local resolvedIconId = nil

    local ok, result = pcall(function()
        local sm = ScriptManager and ScriptManager.instance
        if not (sm and sm.getItem) then
            return nil
        end

        local scriptItem = sm:getItem(fullType)
        if not scriptItem then
            return nil
        end

        if scriptItem.getIconsForTexture then
            local icons = scriptItem:getIconsForTexture()
            if icons and icons.size and icons:size() > 0 then
                local useIdx = idx
                if useIdx < 0 or useIdx >= icons:size() then
                    useIdx = 0
                end

                local entry = icons:get(useIdx)
                if entry then
                    local id = nil
                    if type(entry) == "string" then
                        id = entry
                    else
                        id = entry.texture
                            or entry.textureName
                            or (entry.getTexture and entry:getTexture())
                    end

                    local t = _texFromId(id)
                    if t then
                        resolvedIconId = id
                        return t
                    end
                end
            end
        end

        if scriptItem.getIcon then
            local icon = scriptItem:getIcon()
            local t = _texFromId(icon)
            if t then
                resolvedIconId = icon
                return t
            end
        end

        return nil
    end)

    if ok then
        tex = result
    else
        tex = nil
    end

    if not tex then
        local item = instanceItem(fullType)
        if item and item.getTexture then
            tex = item:getTexture()
        end
    end

    if not tex then
        tex = _texFromId(fullType)
    end

    if tex then
        _BC_ICON_TEX_CACHE[key] = { tex = tex, iconId = resolvedIconId }
    end
    return tex, resolvedIconId
end

function EURY_CONTAINERS.findItemByIdInPlayer(playerObj, itemId)
    if not (playerObj and itemId) then
        return nil
    end
    return playerObj:getInventory():getItemWithID(itemId)
end

function EURY_CONTAINERS.findItemByIdInWorld(itemId, x, y, z)
    local cell = getCell()
    if not cell then
        return nil
    end

    local sq = cell:getGridSquare(x, y, z)
    if not sq then
        return nil
    end

    local objs = sq:getWorldObjects()
    if not objs then
        return nil
    end
    local worldItem = nil
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj then
            local item = obj:getItem()
            if item and item:getID() == itemId then
                worldItem = item
                break
            end
        end
    end

    return worldItem
end

function EURY_CONTAINERS.isVehicle(object)
    if instanceof(object, "BaseVehicle") then
        return true
    end

    if object and object.getVehicle then
        local veh = object:getVehicle()
        if veh then
            return true
        end
    end

    return false
end

function EURY_CONTAINERS.getIsoParent(inventory)
    if not inventory or not inventory.getParent then
        return nil
    end

    local parent = inventory:getParent()
    if not parent then
        return nil
    end

    -- Exclude vehicle containers (VehiclePart parent exposes getVehicle())
    if EURY_CONTAINERS.isVehicle(parent) then
        return nil
    end

    -- Require IsoObject-like capabilities (we need modData + square)
    if not (parent.getModData and parent.getSquare) then
        return nil
    end

    return parent
end

function EURY_CONTAINERS.getParent(inventory)
    if not inventory then
        return nil
    end

    if instanceof(inventory, "ItemContainer") then
        local parentItem = inventory:getContainingItem()

        -- only returns inventory items
        if instanceof(parentItem, "InventoryItem") then
            return parentItem
        end
    end

    if inventory.getParent then
        local parent = inventory:getParent()
        if not parent then
            return nil
        end

        -- Exclude vehicle containers (VehiclePart parent exposes getVehicle())
        if EURY_CONTAINERS.isVehicle(parent) then
            return nil
        end

        -- only returns iso objects
        if instanceof(parent, "IsoObject") then
            return parent
        end
    end

    return nil
end

function EURY_CONTAINERS.getModDataRoot(modDataTable, create)
    if not modDataTable then return nil end
    local rootTable = modDataTable[EURY_CONTAINERS.MODULE_ID]
    if not rootTable and create then
        rootTable = {}
        modDataTable[EURY_CONTAINERS.MODULE_ID] = rootTable
    end
    return rootTable
end

return EURY_CONTAINERS