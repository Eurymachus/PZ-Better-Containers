local BetterContainers_Const = require("BetterContainers/BetterContainers_Const")

local MODULEID = BetterContainers_Const.MODULEID

local SORT_KEY = BetterContainers_Const.SORT_KEY
local SET_MANUALLY = BetterContainers_Const.SET_MANUALLY

local INV_LOCK = BetterContainers_Const.INV_LOCK
local LOOT_LOCK = BetterContainers_Const.LOOT_LOCK
local LOOT_SORT = BetterContainers_Const.LOOT_SORT

-- For special containers that aren't "real"
local SPECIAL_SORT_KEYS_BY_INV_TYPE = BetterContainers_Const.SPECIAL_SORT_KEYS_BY_INV_TYPE

BetterContainers = {}

BetterContainers.isLocked = function(inventoryPage)
    local player = getSpecificPlayer(inventoryPage.player)
    if inventoryPage.onCharacter then
        return player:getModData()[INV_LOCK]
    else
        return player:getModData()[LOOT_LOCK]
    end
end

-- Mouse down: start potential drag-to-reorder
BetterContainers.onMouseDown = function(self, x, y)
    -- 'self' is the container BUTTON
    local panel = self.parent
    local page = panel and panel.parent or nil

    -- Call original (bound in BetterContainers_InventoryPage.lua)
    self._onMouseDown_BetterContainers(self, x, y)

    self.reorderStartMouseY = getMouseY()
    self.reorderStartY = self:getY()

    -- Can we drag? (needs the real page)
    self.canDragToReorder = page and not BetterContainers.isLocked(page) and
                                BetterContainers.canSortBackpacks(page) or false
end

-- Mouse move: do the drag inside the PANEL, compare thresholds using PAGE buttonSize
BetterContainers.onMouseMove = function(self, dx, dy, skipOgMouseMove)
    if not skipOgMouseMove then
        self._onMouseMove_BetterContainers(self, dx, dy)
    end

    if not (self.pressed and self.canDragToReorder) then
        return
    end

    local panel = self.parent
    local page = panel and panel.parent or nil
    if not (panel and page) then
        return
    end

    if math.abs(self.reorderStartMouseY - getMouseY()) > (page.buttonSize / 2) then
        self.draggingToReorder = true
    end

    if self.draggingToReorder then
        local x = getMouseX()
        local y = getMouseY()

        -- Position within the PANEL (buttons are children of the panel now)
        local panelAbsY = panel:getAbsoluteY()
        local newY = y - panelAbsY - (self:getHeight() / 2)

        -- Clamp to panel area (0..panel:getHeight()-button)
        newY = math.max(0, newY)

        self:setY(newY)
        self:bringToTop()
    end
end

-- Mouse move outside: keep existing behavior, re-use our onMouseMove
BetterContainers.onMouseMoveOutside = function(self, dx, dy)
    self._onMouseMoveOutside_BetterContainers(self, dx, dy)
    BetterContainers.onMouseMove(self, dx, dy, true)

    if self.draggingToReorder and not isMouseButtonDown(0) then
        BetterContainers.onMouseUp(self, 0, 0)
    end
end

-- Mouse up: apply new order on the PAGE
BetterContainers.onMouseUp = function(self, x, y)
    local panel = self.parent
    local page = panel and panel.parent or nil

    if self.draggingToReorder and page then
        self.pressed = false
        self.draggingToReorder = false
        page:setContainerButtons(self)
        page:refreshBackpacks()
    else
        self._onMouseUp_BetterContainers(self, x, y)
    end
end

BetterContainers.getTargetModDataAndSortKeyAndParentObject = function(player, inventory)
    local playerKey = player:getUsername()
    local sortKey = SORT_KEY
    local parentObject = nil
    local targetModData = nil

    if inventory == player:getInventory() then
        sortKey = SORT_KEY
        targetModData = player:getModData()
    elseif SPECIAL_SORT_KEYS_BY_INV_TYPE[inventory:getType()] then
        sortKey = SPECIAL_SORT_KEYS_BY_INV_TYPE[inventory:getType()]
        targetModData = player:getModData()
    else
        sortKey = playerKey .. SORT_KEY

        local item = inventory:getContainingItem()
        local isoObject = inventory:getParent()
        if item then
            targetModData = item:getModData()
            parentObject = item
        elseif isoObject then
            targetModData = isoObject:getModData()
            parentObject = isoObject
        end
    end

    return targetModData, sortKey, parentObject
end

BetterContainers.getSortPriority = function(player, inventory, inventoryPage)
    local targetModData, sortKey = BetterContainers.getTargetModDataAndSortKeyAndParentObject(player, inventory)
    if targetModData then
        return targetModData[sortKey] or BetterContainers.getDefaultSortPriority(inventory, inventoryPage)
    end
    return BetterContainers.getDefaultSortPriority(inventory, inventoryPage)
end

BetterContainers.getDefaultSortPriority = function(inventory, inventoryPage)
    local index = 0
    for i, backpack in ipairs(inventoryPage.backpacks) do
        if backpack.inventory == inventory then
            index = i
            break
        end
    end
    return 1000 + index
end

BetterContainers.setSortPriority = function(player, inventory, priority, isManual)
    local targetModData, sortKey = BetterContainers.getTargetModDataAndSortKeyAndParentObject(player, inventory)
    if targetModData then
        targetModData[sortKey] = priority
        targetModData[SET_MANUALLY] = isManual
    end
end

BetterContainers.isManual = function(player, inventory)
    local targetModData, sortKey = BetterContainers.getTargetModDataAndSortKeyAndParentObject(player, inventory)
    return targetModData and targetModData[SET_MANUALLY]
end

BetterContainers.getSortLootWindow = function(playerObj)
    return playerObj:getModData()[LOOT_SORT]
end

BetterContainers.setSortLootWindow = function(playerObj, value)
    playerObj:getModData()[LOOT_SORT] = value
end

BetterContainers.canSortBackpacks = function(inventoryPage)
    return inventoryPage ~= getPlayerLoot(inventoryPage.player) or
               BetterContainers.getSortLootWindow(getSpecificPlayer(inventoryPage.player))
end

BetterContainers.toggleLootLock = function(playerObj)
    local modData = playerObj:getModData()
    modData[LOOT_LOCK] = not modData[LOOT_LOCK]
    return modData[LOOT_LOCK]
end

BetterContainers.toggleInventoryLock = function(playerObj)
    local modData = playerObj:getModData()
    modData[INV_LOCK] = not modData[INV_LOCK]
    return modData[INV_LOCK]
end

BetterContainers.buildTargetDescriptor = function(playerObj, inventory)
    if not (playerObj and inventory) then
        return nil
    end

    -- Player inventory
    if inventory == playerObj:getInventory() then
        return {
            kind = "player",
            slot = "inventory"
        }
    end

    -- Special non-real containers (floor / SpiffUI)
    local invType = inventory:getType()
    if SPECIAL_SORT_KEYS_BY_INV_TYPE[invType] then
        return {
            kind = "player",
            slot = "special",
            invType = invType
        }
    end

    -- Container inside an InventoryItem
    local item = inventory:getContainingItem()
    if item and item.getID then
        return {
            kind = "item",
            itemId = item:getID()
        }
    end

    -- World container (IsoObject parent)
    local isoObject = inventory:getParent()
    if isoObject and isoObject.getObjectIndex then
        return {
            kind = "world",
            x = isoObject:getX(),
            y = isoObject:getY(),
            z = isoObject:getZ(),
            objectIndex = isoObject:getObjectIndex()
        }
    end

    return nil
end

local PZVersion = require("BetterContainers/PZVersion")
local isMP = PZVersion.isAtLeastFull(42, 13)

BetterContainers.sendSaveOrderToServer = function(playerObj, entries)
    if not (isMP and isClient() and playerObj and entries and #entries > 0) then
        return
    end
    sendClientCommand(playerObj, MODULEID, BetterContainers_Const.Commands.SaveOrder, {
        entries = entries
    })
end

-- MP: sync player-level settings to server
function BetterContainers.sendSetLockToServer(playerObj, onCharacter, value)
    if not (isMP and isClient() and playerObj) then
        return
    end
    sendClientCommand(playerObj, MODULEID, BetterContainers_Const.Commands.SetLock, {
        onCharacter = onCharacter == true,
        value = value == true
    })
end

function BetterContainers.sendSetLootSortToServer(playerObj, value)
    if not (isMP and isClient() and playerObj) then
        return
    end
    sendClientCommand(playerObj, MODULEID, BetterContainers_Const.Commands.SetSortLoot, {
        value = value == true
    })
end
