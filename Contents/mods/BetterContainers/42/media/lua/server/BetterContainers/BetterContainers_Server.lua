local BetterContainers_Const = require("BetterContainers/BetterContainers_Const")

local MODULEID = BetterContainers_Const.MODULEID

local SORT_KEY = BetterContainers_Const.SORT_KEY
local SET_MANUALLY = BetterContainers_Const.SET_MANUALLY

local INV_LOCK = BetterContainers_Const.INV_LOCK
local LOOT_LOCK = BetterContainers_Const.LOOT_LOCK
local LOOT_SORT = BetterContainers_Const.LOOT_SORT

local SPECIAL_SORT_KEYS_BY_INV_TYPE = BetterContainers_Const.SPECIAL_SORT_KEYS_BY_INV_TYPE

local function applyManualFlag(md, entry)
    if entry and entry.isManual then
        md[SET_MANUALLY] = true
    else
        md[SET_MANUALLY] = nil
    end
end

local function findItemByIdInPlayer(playerObj, itemId)
    if not (playerObj and itemId) then
        return nil
    end
    local inv = playerObj:getInventory()
    if not inv then
        return nil
    end

    local items = inv:getItems()
    if not items then
        return nil
    end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item.getID and item:getID() == itemId then
            return item
        end
    end

    return nil
end

local function findIsoObjectByIndex(x, y, z, objectIndex)
    local cell = getCell()
    if not cell then
        return nil
    end

    local sq = cell:getGridSquare(x, y, z)
    if not sq then
        return nil
    end

    local objs = sq:getObjects()
    if not objs then
        return nil
    end

    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj and obj.getObjectIndex and obj:getObjectIndex() == objectIndex then
            return obj
        end
    end

    return nil
end

local function applyEntry(playerObj, entry)
    if not (playerObj and entry and entry.kind and entry.sortValue) then
        return
    end

    local username = playerObj:getUsername()
    local sortValue = tonumber(entry.sortValue)
    if not sortValue then
        return
    end

    -- Player / special targets
    if entry.kind == "player" then
        local md = playerObj:getModData()
        if not md then
            return
        end

        local sortKey = nil
        if entry.slot == "inventory" then
            sortKey = SORT_KEY
        elseif entry.slot == "special" and entry.invType and SPECIAL_SORT_KEYS_BY_INV_TYPE[entry.invType] then
            sortKey = SPECIAL_SORT_KEYS_BY_INV_TYPE[entry.invType]
        end

        if sortKey then
            md[sortKey] = sortValue
            applyManualFlag(md, entry)
            if playerObj.transmitModData then
                playerObj:transmitModData()
            end
        end

        return
    end

    -- Item container targets
    if entry.kind == "item" and entry.itemId then
        local item = findItemByIdInPlayer(playerObj, tonumber(entry.itemId))
        if not item then
            return
        end

        local md = item:getModData()
        if not md then
            return
        end

        md[username .. SORT_KEY] = sortValue
        applyManualFlag(md, entry)

        if item.transmitModData then
            item:transmitModData()
        end

        return
    end

    -- World container targets
    if entry.kind == "world" and entry.x and entry.y and entry.z and entry.objectIndex then
        local obj = findIsoObjectByIndex(tonumber(entry.x), tonumber(entry.y), tonumber(entry.z),
            tonumber(entry.objectIndex))
        if not obj then
            return
        end

        local md = obj:getModData()
        if not md then
            return
        end

        md[username .. SORT_KEY] = sortValue
        applyManualFlag(md, entry)

        if obj.transmitModData then
            obj:transmitModData()
        end

        return
    end
end

local function onClientCommand(module, command, playerObj, args)
    if module ~= MODULEID then
        return
    end
    if not playerObj then
        return
    end

    -- Sorting / manual priority
    if command == BetterContainers_Const.Commands.SaveOrder then
        if not (args and args.entries) then
            return
        end
        for _, entry in ipairs(args.entries) do
            applyEntry(playerObj, entry)
        end
        return
    end

    -- Lock buttons
    if command == BetterContainers_Const.Commands.SetLock then
        if not args then
            return
        end
        local md = playerObj:getModData()
        if not md then
            return
        end

        if args.onCharacter then
            md[INV_LOCK] = args.value == true
        else
            md[LOOT_LOCK] = args.value == true
        end

        playerObj:transmitModData()
        return
    end

    -- Sort loot window checkbox
    if command == BetterContainers_Const.Commands.SetSortLoot then
        if not args then
            return
        end
        local md = playerObj:getModData()
        if not md then
            return
        end

        md[LOOT_SORT] = args.value == true
        playerObj:transmitModData()
        return
    end
end

Events.OnClientCommand.Add(onClientCommand)
