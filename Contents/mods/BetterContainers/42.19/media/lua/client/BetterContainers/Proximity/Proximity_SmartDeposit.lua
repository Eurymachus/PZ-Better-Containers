local Helpers = require("BetterContainers/Helpers")
local Options = require("BetterContainers/_Options")
local Proximity = require("BetterContainers/Proximity")

require("TimedActions/ISInventoryTransferUtil")
require("TimedActions/ISWalkToTimedAction")

local ProximitySmartDeposit = {}

ProximitySmartDeposit._installed = false

local SKIP_CONTAINER_TYPES = {
    [Proximity.invName] = true,
    [Proximity.invName_corpses] = true,
    floor = true,
    ["local"] = true,
    localContainer = true,
    localInventory = true,


    stove = true,
    microwave = true,
    oven = true,
    washingmachine = true,
    dryer = true,
    clothingwasher = true,
    clothingdryer = true,
    combinationwasherdryer = true,
}

local function getContainerType(container)
    if not (container and container.getType) then return nil end
    local ok, value = pcall(function()
        return container:getType()
    end)
    if ok and value then
        return tostring(value)
    end
    return nil
end

local function isCorpseContainerType(containerType)
    return containerType == "inventorymale"
        or containerType == "inventoryfemale"
end

local function isCorpseMode()
    local eff = Options.getEffectivePermissions() or {}
    return eff.corpseOnly == true
end

local function isSmartDepositTarget(container)
    local containerType = getContainerType(container)
    return containerType == Proximity.invName
        or (containerType == Proximity.invName_corpses and isCorpseMode())
end

local function getItemFullType(item)
    if not (item and item.getFullType) then return nil end
    local ok, value = pcall(function()
        return item:getFullType()
    end)
    if ok and value and value ~= "" then
        return tostring(value)
    end
    return nil
end

local function getItemCategory(item)
    if not item then return nil end

    if item.getDisplayCategory then
        local ok, value = pcall(function()
            return item:getDisplayCategory()
        end)
        if ok and value and value ~= "" then
            return tostring(value)
        end
    end

    if item.getCategory then
        local ok, value = pcall(function()
            return item:getCategory()
        end)
        if ok and value and value ~= "" then
            return tostring(value)
        end
    end

    return nil
end

local function getItemWeight(item)
    if not item then return 0 end

    if item.getUnequippedWeight then
        local ok, value = pcall(function()
            return item:getUnequippedWeight()
        end)
        if ok and type(value) == "number" then
            return value
        end
    end

    if item.getActualWeight then
        local ok, value = pcall(function()
            return item:getActualWeight()
        end)
        if ok and type(value) == "number" then
            return value
        end
    end

    return 0
end

local function isLockedForPlayer(container, playerObj)
    local parent = container and container.getParent and container:getParent() or nil
    if not (parent and playerObj) then return false end

    if instanceof(parent, "IsoThumpable") and parent.isLockedToCharacter then
        local ok, locked = pcall(function()
            return parent:isLockedToCharacter(playerObj)
        end)
        return ok and locked == true
    end

    return false
end

local function isRealStorage(container, playerObj)
    local containerType = getContainerType(container)
    if not containerType then return false end
    if SKIP_CONTAINER_TYPES[containerType] then return false end
    if isCorpseContainerType(containerType) and not isCorpseMode() then return false end
    if isLockedForPlayer(container, playerObj) then return false end
    return true
end

local function collectNearbyStorage(playerNum, playerObj)
    local containers = {}
    local known = {}
    local page = getPlayerLoot and getPlayerLoot(playerNum) or nil
    if not (page and page.backpacks) then return containers, known end

    for i = 1, #page.backpacks do
        local container = page.backpacks[i] and page.backpacks[i].inventory or nil
        if container and not known[container] and isRealStorage(container, playerObj) then
            known[container] = true
            containers[#containers + 1] = container
        end
    end

    return containers, known
end

local function containerHasFullType(container, fullType, movingItems)
    if not (container and fullType) then return false end
    local items = container:getItems()
    if not items then return false end

    for i = 0, items:size() - 1 do
        local other = items:get(i)
        if other and not movingItems[other] and getItemFullType(other) == fullType then
            return true
        end
    end

    return false
end

local function containerHasCategory(container, category, movingItems)
    if not (container and category) then return false end
    local items = container:getItems()
    if not items then return false end

    for i = 0, items:size() - 1 do
        local other = items:get(i)
        if other and not movingItems[other] and getItemCategory(other) == category then
            return true
        end
    end

    return false
end

local function hasRoomForPlannedItem(container, playerObj, item, reservedWeight)
    if not (container and item) then return false end
    if not container.isItemAllowed or not container:isItemAllowed(item) then return false end
    if container.isInside and container:isInside(item) then return false end

    reservedWeight = reservedWeight or 0
    if reservedWeight <= 0 then
        local ok, value = pcall(function()
            return container:hasRoomFor(playerObj, item)
        end)
        if ok then return value == true end
    end

    local plannedWeight = reservedWeight + getItemWeight(item)
    local ok, value = pcall(function()
        return container:hasRoomFor(playerObj, plannedWeight, plannedWeight)
    end)
    if ok then return value == true end

    ok, value = pcall(function()
        return container:hasRoomFor(playerObj, item)
    end)
    return ok and value == true
end

local function isMovableDepositItem(item, targetContainer, playerObj)
    if not (item and targetContainer and playerObj and item.getContainer and item:getContainer()) then return false end
    if item.isFavorite and item:isFavorite() and not targetContainer:isInCharacterInventory(playerObj) then return false end
    if targetContainer.isInside and targetContainer:isInside(item) then return false end
    if item.getContainer and item:getContainer() == targetContainer then return false end
    return true
end

local function findDestination(item, containers, playerObj, movingItems, reservedWeights)
    local fullType = getItemFullType(item)
    local category = getItemCategory(item)

    for _, container in ipairs(containers) do
        if hasRoomForPlannedItem(container, playerObj, item, reservedWeights[container])
            and containerHasFullType(container, fullType, movingItems)
        then
            return container
        end
    end

    if category then
        for _, container in ipairs(containers) do
            if hasRoomForPlannedItem(container, playerObj, item, reservedWeights[container])
                and containerHasCategory(container, category, movingItems)
            then
                return container
            end
        end
    end

    for _, container in ipairs(containers) do
        if hasRoomForPlannedItem(container, playerObj, item, reservedWeights[container]) then
            return container
        end
    end

    return nil
end

local function queueWalkNearContainer(container, playerObj)
    if not (container and playerObj) then return false end
    if container:getType() == "floor" then return true end
    if container.isInCharacterInventory and container:isInCharacterInventory(playerObj) then return true end

    local parent = container.getParent and container:getParent() or nil
    if not (parent and parent.getSquare and parent:getSquare()) then
        return true
    end

    local playerSquare = playerObj:getCurrentSquare()
    if not playerSquare then return false end

    if instanceof(parent, "IsoDeadBody") then
        return true
    end

    if instanceof(parent, "BaseVehicle") then
        if playerObj:getVehicle() == parent then
            return true
        end

        local part = container.getVehiclePart and container:getVehiclePart() or nil
        if part and part.getArea and part:getArea() then
            if part:getVehicle():canAccessContainer(part:getIndex(), playerObj) then
                return true
            end

            if ISPathFindAction and ISPathFindAction.pathToVehicleArea then
                ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(playerObj, part:getVehicle(), part:getArea()))
                return true
            end
        end

        return false
    end

    if parent:getSquare():DistToProper(playerSquare) < 2 then
        return true
    end

    local adjacent = AdjacentFreeTileFinder and AdjacentFreeTileFinder.Find(parent:getSquare(), playerObj) or nil
    if not adjacent then return false end
    if adjacent ~= playerSquare then
        ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, adjacent))
    end

    return true
end

local function getSmartDepositPlan(playerNum, playerObj, items, targetContainer)
    local containers = collectNearbyStorage(playerNum, playerObj)
    if #containers == 0 then return nil end

    local movingItems = {}
    for _, item in ipairs(items or {}) do
        if item then
            movingItems[item] = true
        end
    end

    local reservedWeights = {}
    local destinationOrder = {}
    local groupedItems = {}

    for _, item in ipairs(items or {}) do
        if isMovableDepositItem(item, targetContainer, playerObj) then
            local origin = item:getContainer()
            local destination = findDestination(item, containers, playerObj, movingItems, reservedWeights)
            if destination and destination ~= origin then
                if not groupedItems[destination] then
                    groupedItems[destination] = {}
                    destinationOrder[#destinationOrder + 1] = destination
                end
                groupedItems[destination][#groupedItems[destination] + 1] = item
                reservedWeights[destination] = (reservedWeights[destination] or 0) + getItemWeight(item)
            end
        end
    end

    if #destinationOrder == 0 then return nil end

    return {
        destinationOrder = destinationOrder,
        groupedItems = groupedItems,
    }
end

local function hasSmartDepositDestination(playerNum, playerObj, targetContainer)
    if not (ISMouseDrag and ISMouseDrag.dragging) then return false end

    local dragging = ISInventoryPane.getActualItems(ISMouseDrag.dragging)
    local plan = getSmartDepositPlan(playerNum, playerObj, dragging, targetContainer)
    return plan ~= nil
end

local function runSmartDeposit(pane, items, targetContainer)
    if not (pane and items and targetContainer) then return end

    local playerNum = pane.player or 0
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end

    if pane.sortItemsByTypeAndWeight then
        pane:sortItemsByTypeAndWeight(items)
    end

    local plan = getSmartDepositPlan(playerNum, playerObj, items, targetContainer)
    if not plan then return end

    ISTimedActionQueue.clear(playerObj)

    for _, destination in ipairs(plan.destinationOrder) do
        if queueWalkNearContainer(destination, playerObj) then
            for _, item in ipairs(plan.groupedItems[destination]) do
                local origin = item and item.getContainer and item:getContainer() or nil
                if origin and origin ~= destination then
                    ISTimedActionQueue.add(
                        ISInventoryTransferUtil.newInventoryTransferAction(
                            playerObj,
                            item,
                            origin,
                            destination
                        )
                    )
                end
            end
        end
    end
end

function ProximitySmartDeposit.install()
    if ProximitySmartDeposit._installed then return end
    ProximitySmartDeposit._installed = true

    local oldTransferItemsByWeight = ISInventoryPane.transferItemsByWeight
    function ISInventoryPane:transferItemsByWeight(items, container, ...)
        if isSmartDepositTarget(container) then
            local ok, err = pcall(runSmartDeposit, self, items, container)
            if not ok then
                Helpers.dlog("Proximity SmartDeposit " .. tostring(err))
            end
            return
        end

        return oldTransferItemsByWeight(self, items, container, ...)
    end

    local oldPaneCanPutIn = ISInventoryPane.canPutIn
    function ISInventoryPane:canPutIn(...)
        if isSmartDepositTarget(self.inventory) then
            local playerObj = getSpecificPlayer(self.player)
            return hasSmartDepositDestination(self.player, playerObj, self.inventory)
        end

        return oldPaneCanPutIn(self, ...)
    end

    local oldPageCanPutIn = ISInventoryPage.canPutIn
    function ISInventoryPage:canPutIn(...)
        local target = self.mouseOverButton and self.mouseOverButton.inventory or nil
        if isSmartDepositTarget(target) then
            local playerObj = getSpecificPlayer(self.player)
            return hasSmartDepositDestination(self.player, playerObj, target)
        end

        return oldPageCanPutIn(self, ...)
    end

    if ISInventoryPaneDraggedItems and type(ISInventoryPaneDraggedItems.update) == "function" then
        local oldDraggedItemsUpdate = ISInventoryPaneDraggedItems.update
        function ISInventoryPaneDraggedItems:update(...)
            oldDraggedItemsUpdate(self, ...)

            local target = self.mouseOverContainer
            if not (isSmartDepositTarget(target) and self.items and self.itemNotOK) then
                return
            end

            local playerNum = self.inventoryPane and self.inventoryPane.player or self.playerNum or 0
            local playerObj = getSpecificPlayer(playerNum)
            if not hasSmartDepositDestination(playerNum, playerObj, target) then
                return
            end

            for _, item in ipairs(self.items) do
                if item and isMovableDepositItem(item, target, playerObj) then
                    self.itemNotOK[item] = nil
                end
            end
        end
    end
end

return ProximitySmartDeposit
