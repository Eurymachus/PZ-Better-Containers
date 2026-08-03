local ModData = require("BetterContainers/Reorder/ModData")
local Network = require("BetterContainers/Reorder/Network")

Reorder = {}

Reorder.isLocked = function(inventoryPage)
    if inventoryPage and inventoryPage.bcIsLocked then
        return inventoryPage:bcIsLocked()
    end
    return false
end

Reorder.isLockedForPlayer = function(player, onCharacter)
    if not player then
        return false
    end

    local page = onCharacter and getPlayerInventory(player:getPlayerNum()) or getPlayerLoot(player:getPlayerNum())
    if page and page.bcIsLocked then
        return page:bcIsLocked()
    end

    return false
end

Reorder.getSortPriority = function(player, inventory, inventoryPage)
    local priority = ModData.getSortPriority(player, inventory)

    if priority ~= nil then
        return priority
    end

    return ModData.getDefaultSortPriority(inventory, inventoryPage)
end

Reorder.isManual = function(player, inventory)
    local isManual = ModData.isManual(player, inventory)
    return isManual or false
end

Reorder.getSortLootWindow = function(playerObj)
    if not playerObj then
        return false
    end

    local lootPage = getPlayerLoot(playerObj:getPlayerNum())
    if lootPage and lootPage.bcGetSortLootWindow then
        return lootPage:bcGetSortLootWindow()
    end

    return false
end

Reorder.canSortBackpacks = function(inventoryPage)
    if not inventoryPage then
        return false
    end

    return inventoryPage ~= getPlayerLoot(inventoryPage.player)
        or (inventoryPage.bcGetSortLootWindow and inventoryPage:bcGetSortLootWindow())
        or false
end

Reorder.setSortPriority = function(player, inventory, priority, isManual)
    Network.setSortPriority(player, inventory, priority, isManual)
end

Reorder.setSortLootWindow = function(playerObj, value)
    if not playerObj then
        return false
    end

    local lootPage = getPlayerLoot(playerObj:getPlayerNum())
    if lootPage and lootPage.bcSetSortLootWindow then
        return lootPage:bcSetSortLootWindow(value)
    end

    return false
end

local function asInventory(invOrContainer)
    if not invOrContainer then return nil end
    if invOrContainer.getInventory then
        return invOrContainer:getInventory()
    end
    return invOrContainer
end

-- ------------------------------------------------------------
-- Handle
-- ------------------------------------------------------------
local function makeHandle(playerObj, inventory, owner)
    local rd = {}

    rd.player = playerObj
    rd.inventory = inventory
    rd.owner = owner or playerObj

    function rd:getSort()
        return ModData.getSortPriority(self.player, self.inventory)
    end

    function rd:getSortNumber()
        local v = self:getSort()
        if v == nil then return nil end
        return tonumber(v)
    end

    function rd:isManual()
        return ModData.isManual(self.player, self.inventory)
    end

    -- Writes: go straight to Network (ModData.setSortPriority is called there).
    function rd:setSort(priority, isManual)
        Network.setSortPriority(self.player, self.inventory, priority, isManual == true)
    end

    function rd:clearSort()
        Network.setSortPriority(self.player, self.inventory, nil, false)
    end

    return rd
end

-- Public factory
Reorder.getData = function(playerObj, inventoryOrContainer)
    if not (playerObj and inventoryOrContainer) then
        return nil
    end

    local inventory = asInventory(inventoryOrContainer)
    if not inventory then
        return nil
    end

    local _, _, owner = ModData.getTargetModDataAndSortKeyAndParentObject(playerObj, inventory)
    return makeHandle(playerObj, inventory, owner)
end

Reorder._installed = false

Reorder.install = function()
    if Reorder._installed then return end
    Reorder._installed = true
    local Reorder_ISBaseIcon = require("BetterContainers/Reorder/Reorder_ISBaseIcon")
    local Reorder_ISInventoryPage = require("BetterContainers/Reorder/Reorder_ISInventoryPage")

    Reorder_ISBaseIcon.install()
    Reorder_ISInventoryPage.install()
end

return Reorder