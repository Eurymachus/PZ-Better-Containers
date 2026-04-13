local Constants = require("BetterContainers/Reorder/Constants")
local Helpers = require("BetterContainers/Helpers")

-- Legacy flat-key constants (for migration only)
local SORT_KEY = Constants.SORT_KEY
local SET_MANUALLY = Constants.SET_MANUALLY

local INV_LOCK = Constants.INV_LOCK
local LOOT_LOCK = Constants.LOOT_LOCK
local LOOT_SORT = Constants.LOOT_SORT

local ModData = {}

local getRoot = Helpers.getModDataRoot

local REORDER_KEY = "reorder"   -- player: reorder.priority/manual maps; owner: reorder[username] scalar

local function isPlayerOwner(obj)
    return obj and instanceof(obj, "IsoPlayer")
end

-- ------------------------------------------------------------
-- Target resolver (unchanged behaviour / keys)
-- ------------------------------------------------------------
ModData.getTargetModDataAndSortKeyAndParentObject = function(playerObj, inventory)
    local playerKey = playerObj:getUsername()
    local resolvedSortKey = SORT_KEY
    local ownerObject = nil
    local targetModDataTable = nil

    local isPlayerInventory = inventory == playerObj:getInventory()

    if isPlayerInventory then
        targetModDataTable = playerObj:getModData()
    else
        resolvedSortKey = playerKey .. SORT_KEY
        local containingItem = inventory:getContainingItem()
        local parentIsoObject = inventory:getParent()
        if containingItem then
            targetModDataTable = containingItem:getModData()
            ownerObject = containingItem
        elseif parentIsoObject then
            targetModDataTable = parentIsoObject:getModData()
            ownerObject = parentIsoObject
        end
    end

    -- Fallback: fake inventories or anything we can't resolve to an owning item/iso object.
    if not ownerObject or not targetModDataTable then
        resolvedSortKey = inventory:getType()
        targetModDataTable = playerObj:getModData()
        ownerObject = playerObj
    end

    return targetModDataTable, resolvedSortKey, ownerObject
end

-- ------------------------------------------------------------
-- Reorder accessors
-- ------------------------------------------------------------

-- Player reorder node: root.reorder.priority/manual maps
local function ensurePlayerReorderData(playerModDataTable)
    if not playerModDataTable then return nil end

    local rootTable = getRoot(playerModDataTable, true)
    if not rootTable then return nil end

    rootTable[REORDER_KEY] = rootTable[REORDER_KEY] or {}
    local playerReorder = rootTable[REORDER_KEY]

    if type(playerReorder.priority) ~= "table" then
        playerReorder.priority = {}
    end
    if type(playerReorder.manual) ~= "table" then
        playerReorder.manual = {}
    end

    return playerReorder, rootTable
end

-- Owner reorder node: root.reorder[username] scalar table (priority/manual)
-- Also migrates legacy flat keys using legacyPriorityKey.
local function ensureOwnerReorderData(ownerModDataTable, username, legacyPriorityKey)
    if not ownerModDataTable then return nil end

    local rootTable = getRoot(ownerModDataTable, true)
    if not rootTable then return nil end

    rootTable[REORDER_KEY] = rootTable[REORDER_KEY] or {}
    local reorderUsers = rootTable[REORDER_KEY]
    local ownerUser = reorderUsers[username]
    if not ownerUser then
        ownerUser = {}
        reorderUsers[username] = ownerUser
    end

    -- migrate legacy flat keys once
    if legacyPriorityKey and ownerModDataTable[legacyPriorityKey] ~= nil and ownerUser.priority == nil then
        ownerUser.priority = ownerModDataTable[legacyPriorityKey]
        ownerModDataTable[legacyPriorityKey] = nil
    end

    if ownerModDataTable[SET_MANUALLY] ~= nil and ownerUser.manual == nil then
        ownerUser.manual = ownerModDataTable[SET_MANUALLY] == true
        ownerModDataTable[SET_MANUALLY] = nil
    end

    return ownerUser, rootTable
end

-- Ensures reorder node exists for resolved target and migrates legacy once.
-- Returns ONLY: ownerObject, sortKeyOrNil, reorderNode
--
-- Contract:
--   sortKey ~= nil  => player/type-keyed (reorderNode.priority/manual are tables keyed by sortKey)
--   sortKey == nil  => item/iso-owned (reorderNode.priority/manual are scalar values)
local function ensureTargetReorderNode(playerObj, inventory)
    local targetModDataTable, resolvedSortKey, ownerObject =
        ModData.getTargetModDataAndSortKeyAndParentObject(playerObj, inventory)

    if not (targetModDataTable and ownerObject and playerObj) then
        return nil, nil, nil
    end

    local username = playerObj:getUsername()

    if isPlayerOwner(ownerObject) then
        local playerReorder = ensurePlayerReorderData(targetModDataTable)
        if not playerReorder then
            return nil, nil, nil
        end

        -- migrate legacy priority for this resolved key (old flat-key storage)
        if targetModDataTable[resolvedSortKey] ~= nil and playerReorder.priority[resolvedSortKey] == nil then
            playerReorder.priority[resolvedSortKey] = targetModDataTable[resolvedSortKey]
            targetModDataTable[resolvedSortKey] = nil
        end

        -- migrate legacy SET_MANUALLY by materialising per-key manual
        if targetModDataTable[SET_MANUALLY] ~= nil and playerReorder.manual[resolvedSortKey] == nil then
            playerReorder.manual[resolvedSortKey] = targetModDataTable[SET_MANUALLY] == true
            targetModDataTable[SET_MANUALLY] = nil
        end

        return ownerObject, resolvedSortKey, playerReorder
    end

    -- Owner (item/iso): scalar per-user storage; resolvedSortKey is legacy migration lookup only
    local ownerUser = ensureOwnerReorderData(targetModDataTable, username, resolvedSortKey)
    return ownerObject, nil, ownerUser
end

-- ------------------------------------------------------------
-- Canonical descriptor builder (unchanged)
-- ------------------------------------------------------------
ModData.getEntryOrTarget = function(playerObj, parentObj, priority, isManual)
    if not (playerObj and parentObj) then
        return nil
    end

    -- If this container belongs to an item, that item may be on the ground.
    -- Ground detection must be done on the *item* (getWorldItem)
    if instanceof(parentObj, "InventoryItem") then
        local entry = nil
        local worldItem = parentObj.getWorldItem and parentObj:getWorldItem() or nil
        if worldItem then
            local square = worldItem.getSquare and worldItem:getSquare() or nil
            if square then
                entry = {
                    kind = "groundItem",
                    itemId = parentObj:getID(),
                    x = square:getX(),
                    y = square:getY(),
                    z = square:getZ(),
                }
            end
        else
            -- Not on ground (or no world link): normal inventory item container
            entry = {
                kind = "item",
                itemId = parentObj:getID(),
            }
        end
        entry.priority = priority
        entry.isManual = isManual
        return entry
    end

    -- If not Item then Iso/Player return parent for transmit
    return parentObj
end

function ModData.getSortPriority(playerObj, inventory)
    local ownerObject, sortKeyOrNil, reorderNode = ensureTargetReorderNode(playerObj, inventory)
    if not (ownerObject and reorderNode) then
        return nil
    end

    if sortKeyOrNil then
        -- player / type-keyed
        return reorderNode.priority and reorderNode.priority[sortKeyOrNil] or nil
    end

    -- item / iso-owned
    return reorderNode.priority
end

function ModData.isManual(playerObj, inventory)
    local ownerObject, sortKeyOrNil, reorderNode = ensureTargetReorderNode(playerObj, inventory)
    if not (ownerObject and reorderNode) then
        return false
    end

    if sortKeyOrNil then
        -- player / type-keyed
        return reorderNode.manual
           and reorderNode.manual[sortKeyOrNil] == true
           or false
    end

    -- item / iso-owned (scalar)
    return reorderNode.manual == true
end

-- ------------------------------------------------------------
-- Server-side apply (item-based entries only)
-- ------------------------------------------------------------
function ModData.applyPriority(playerObj, entry)
    Helpers.dlog("applyPriority triggered")
    -- priority may be 0; only reject nil.
    if not (playerObj and entry and entry.kind and entry.priority ~= nil) then
        return
    end

    local username = playerObj:getUsername()
    local priorityNumber = tonumber(entry.priority)
    if priorityNumber == nil then
        return
    end

    local function applyToItem(item)
        if not item then return end
        local itemModData = item:getModData()
        if not itemModData then return end

        -- Legacy key used previously for item-based storage
        local legacyKey = username .. SORT_KEY
        local ownerUser = ensureOwnerReorderData(itemModData, username, legacyKey)
        if not ownerUser then return end

        ownerUser.priority = priorityNumber
        ownerUser.manual = entry.isManual == true
    end

    if entry.itemId then
        local itemIdNumber = tonumber(entry.itemId)

        if entry.kind == "item" then
            local item = Helpers.findItemByIdInPlayer(playerObj, itemIdNumber)
            if not item then
                Helpers.dlog("Could not find player item with ID: " .. tostring(itemIdNumber))
                return
            end
            applyToItem(item)
            return
        end

        if entry.kind == "groundItem" and entry.x and entry.y and entry.z then
            local item = Helpers.findItemByIdInWorld(itemIdNumber, entry.x, entry.y, entry.z)
            if not item then
                Helpers.dlog("Could not find ground item with ID: " .. tostring(itemIdNumber))
                return
            end
            applyToItem(item)
            return
        end
    end
end

function ModData.setSortPriority(playerObj, inventory, priority, isManual)
    local ownerObject, sortKeyOrNil, reorderNode = ensureTargetReorderNode(playerObj, inventory)
    if not (ownerObject and reorderNode) then
        return nil
    end

    if sortKeyOrNil then
        -- player / type-keyed
        reorderNode.priority[sortKeyOrNil] = priority
        reorderNode.manual[sortKeyOrNil]   = isManual == true
    else
        -- item / iso-owned
        reorderNode.priority = priority
        reorderNode.manual   = isManual == true
    end

    return ModData.getEntryOrTarget(playerObj, ownerObject, priority, isManual)
end

-- ------------------------------------------------------------
-- Player-only root (lock + sortLoot + customize)
-- ------------------------------------------------------------
local function ensurePlayerRoot(playerObj)
    local playerModData = playerObj and playerObj:getModData() or nil
    if not playerModData then return nil end

    local rootTable = getRoot(playerModData, true)
    if not rootTable then return nil end

    rootTable.lock = rootTable.lock or {}

    -- Legacy player lock/sortLoot migration (ONE place)
    if playerModData[INV_LOCK] ~= nil and rootTable.lock.inventory == nil then
        rootTable.lock.inventory = playerModData[INV_LOCK] == true
        playerModData[INV_LOCK] = nil
    end

    if playerModData[LOOT_LOCK] ~= nil and rootTable.lock.loot == nil then
        rootTable.lock.loot = playerModData[LOOT_LOCK] == true
        playerModData[LOOT_LOCK] = nil
    end

    if playerModData[LOOT_SORT] ~= nil and rootTable.sortLoot == nil then
        rootTable.sortLoot = playerModData[LOOT_SORT] == true
        playerModData[LOOT_SORT] = nil
    end

    return rootTable
end

function ModData.setLock(playerObj, onCharacter, value)
    local rootTable = ensurePlayerRoot(playerObj)
    if not rootTable then return end

    if onCharacter then
        rootTable.lock.inventory = value == true
    else
        rootTable.lock.loot = value == true
    end
end

function ModData.setSortLootWindow(playerObj, value)
    local rootTable = ensurePlayerRoot(playerObj)
    if not rootTable then return end
    rootTable.sortLoot = value == true
end

ModData.toggleLootLock = function(playerObj)
    local rootTable = ensurePlayerRoot(playerObj)
    if not rootTable then return false end
    rootTable.lock.loot = not rootTable.lock.loot
    return rootTable.lock.loot
end

ModData.toggleInventoryLock = function(playerObj)
    local rootTable = ensurePlayerRoot(playerObj)
    if not rootTable then return false end
    rootTable.lock.inventory = not rootTable.lock.inventory
    return rootTable.lock.inventory
end

ModData.getSortLootWindow = function(playerObj)
    local rootTable = ensurePlayerRoot(playerObj)
    if not rootTable then return nil end
    return rootTable.sortLoot
end

ModData.isLockedForPlayer = function(playerObj, onCharacter)
    local rootTable = ensurePlayerRoot(playerObj)
    if not rootTable then return nil end

    if onCharacter then
        return rootTable.lock.inventory
    else
        return rootTable.lock.loot
    end
end

ModData.getDefaultSortPriority = function(inventory, inventoryPage)
    local index = 0
    for i, backpack in ipairs(inventoryPage.backpacks) do
        if backpack.inventory == inventory then
            index = i
            break
        end
    end
    return 1000 + index
end

return ModData
