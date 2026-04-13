local ModData = require("BetterContainers/Reorder/ModData")
local Network = require("BetterContainers/Reorder/Network")

Reorder = {}

Reorder.isLockedForPlayer = function(player, onCharacter)
    return ModData.isLockedForPlayer(player, onCharacter)
end

Reorder.isLocked = function(inventoryPage)
    local player = getSpecificPlayer(inventoryPage.player)
    return Reorder.isLockedForPlayer(player, inventoryPage.onCharacter)
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
    return ModData.getSortLootWindow(playerObj)
end

Reorder.canSortBackpacks = function(inventoryPage)
    return inventoryPage ~= getPlayerLoot(inventoryPage.player)
        or Reorder.getSortLootWindow(getSpecificPlayer(inventoryPage.player))
end

Reorder.setSortPriority = function(player, inventory, priority, isManual)
    Network.setSortPriority(player, inventory, priority, isManual)
end

Reorder.setSortLootWindow = function(playerObj, value)
    Network.setSortLootWindow(playerObj, value)
end

Reorder.toggleLock = function(playerObj, onCharacter)
    Network.toggleLock(playerObj, onCharacter)
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

return Reorder