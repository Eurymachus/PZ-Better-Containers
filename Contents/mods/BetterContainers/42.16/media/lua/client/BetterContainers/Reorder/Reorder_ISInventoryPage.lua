require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISMouseDrag"
require "ISUI/ISInventoryPage"

local Reorder = require("BetterContainers/Reorder")
local Helpers = require("BetterContainers/Helpers")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6

local ContainerButton = require("BetterContainers/Reorder/ContainerButton")

local function isButtonValid(invPage, button)
    local panel = invPage and invPage.containerButtonPanel
    return button:getIsVisible() and panel and panel.children and panel.children[button.ID] ~= nil
end

local function refreshContainerButtonPanelScrollHeight(page)
    if not page or not page.containerButtonPanel then
        return
    end

    local maxBottom = 0
    for _, button in ipairs(page.backpacks or {}) do
        if isButtonValid(page, button) then
            maxBottom = math.max(maxBottom, button:getBottom())
        end
    end

    page.containerButtonPanel:setScrollHeight(maxBottom)
end

local function getNextAutoSort(lastSort)
    if lastSort == nil or lastSort < 0 then
        return 10
    end

    return (math.floor(lastSort / 10) + 1) * 10
end

-- =========================================================
-- UPDATE OVERRIDE
-- =========================================================

local Reorder_ISInventoryPage = {}

Reorder_ISInventoryPage.install = function()
    local _old_update = ISInventoryPage.update
    ISInventoryPage.update = function(self)
        if Helpers.isCleanUIActive() then return _old_update(self) end

        local playerObj = getSpecificPlayer(self.player)
        if self.inventory:getEffectiveCapacity(playerObj) ~= self.capacity then
            self.capacity = self.inventory:getEffectiveCapacity(playerObj)
        end

        self:updateContainerHighlight()

        if (ISMouseDrag.dragging ~= nil and #ISMouseDrag.dragging > 0) or self.pin then
            self.collapseCounter = 0;
            if isClient() and self.isCollapsed then
                self.inventoryPane.inventory:requestSync();
            end
            self.isCollapsed = false;
            self:clearMaxDrawHeight();
            self.collapseCounter = 0;
        end

        if not self.onCharacter then
            if self.lastDir ~= playerObj:getDir() then
                self.lastDir = playerObj:getDir()
                self:refreshBackpacks()
            elseif self.lastSquare ~= playerObj:getCurrentSquare() then
                self.lastSquare = playerObj:getCurrentSquare()
                self:refreshBackpacks()
            end

            -- If the currently-selected container is locked to the player, select another container.
            local object = self.inventory and self.inventory:getParent() or nil
            if #self.backpacks > 1 and instanceof(object, "IsoThumpable") and object:isLockedToCharacter(playerObj) then
                local currentIndex = self:getCurrentBackpackIndex()
                local unlockedIndex = self:prevUnlockedContainer(currentIndex, false)
                if unlockedIndex == -1 then
                    unlockedIndex = self:nextUnlockedContainer(currentIndex, false)
                end
                if unlockedIndex ~= -1 then
                    if playerObj:getJoypadBind() ~= -1 then
                        self.backpackChoice = unlockedIndex
                    end
                    self:selectContainer(self.backpacks[unlockedIndex])
                end
            end
        end

        if self.controlsUI then
            self.controlsUI:arrange()
            self.inventoryPane:setHeight(self.height - self.inventoryPane.y - self.resizeWidget.height - self.controlsUI.height)
            self.inventoryPane:setY(self:titleBarHeight())
        end
        self.containerButtonPanel:setHeight(self.inventoryPane.height)
        self.containerButtonPanel:setY(self.inventoryPane.y)
        --self.containerButtonPanel:setScrollHeight(self.backpacks[#self.backpacks]:getBottom())

        self:updateContainerOpenCloseSounds()
    end

    ISInventoryPage.setContainerButtons_Reorder = function(self, draggedButton)
        if draggedButton and math.abs(draggedButton:getY() - draggedButton.reorderStartY) <= self.buttonSize then
            draggedButton:setY(draggedButton.reorderStartY)
            return
        end

        local playerObj = getSpecificPlayer(self.player)

        local inventoriesAndY = {}
        for index, button in ipairs(self.backpacks) do
            if isButtonValid(self, button) then
                table.insert(inventoriesAndY, {
                    inventory = button.inventory,
                    y = button:getY()
                })
            end
        end

        table.sort(inventoriesAndY, function(a, b)
            return a.y < b.y
        end)

        local seenObjs = {}
        local lastSort = 0
        for index, data in ipairs(inventoriesAndY) do
            local rd = Reorder.getData(playerObj, data.inventory)
            local parent = rd and rd.owner
            local isManual = rd and rd:isManual()
            local isDraggedButton = draggedButton and data.inventory == draggedButton.inventory

            if not isDraggedButton and parent ~= playerObj and seenObjs[parent] then
                -- Skip this button, some IsoObjects have multiple inventories
            else
                if parent then
                    seenObjs[parent] = true
                end

                local savedSort = rd and rd:getSortNumber() or nil
                if not isManual or isDraggedButton or savedSort == nil then
                    lastSort = getNextAutoSort(lastSort)
                    if rd and rd.setSort then
                        rd:setSort(lastSort, nil)
                    end
               else
                    if index > 1 then
                        local prevInventory = inventoriesAndY[index - 1].inventory
                        local prevSort = Reorder.getSortPriority(playerObj, prevInventory)

                        if prevSort >= savedSort then
                            if savedSort <= 0 then
                                -- No valid non-negative slot exists above this anchor.
                                -- Promote this anchor just enough to make room.
                                savedSort = prevSort + 10
                                Reorder.setSortPriority(playerObj, data.inventory, savedSort, true)
                            else
                                Reorder.setSortPriority(playerObj, prevInventory, savedSort - 1, false)
                            end
                        end
                    end

                    lastSort = savedSort
                end
            end
        end
    end

    local _old_addContainerButton = ISInventoryPage.addContainerButton
    function ISInventoryPage:addContainerButton(container, texture, name, tooltip)
        local button = _old_addContainerButton(self, container, texture, name, tooltip)
        return ContainerButton:getInstance(button, self)
    end

    ISInventoryPage.applyBackpackOrder = function(self)
        local playerObj = getSpecificPlayer(self.player)

        local buttonsAndSort = {}
        for index, button in ipairs(self.backpacks) do
            if isButtonValid(self, button) then
                local sort = 1000 + index
                local rd = Reorder.getData(playerObj, button.inventory)
                if rd then
                    sort = rd:getSortNumber() or (1000 + index)
                end
                table.insert(buttonsAndSort, {
                    button = button,
                    sort = sort
                })
            end
        end

        table.sort(buttonsAndSort, function(a, b)
            return a.sort < b.sort
        end)

        local offset = self:bcIsFooterUtilityMode() and 0 or self:bcGetUtilityPanelHeight()
        for index, data in ipairs(buttonsAndSort) do
            data.button:setY(offset + ((index - 1) * self.buttonSize))
        end

        refreshContainerButtonPanelScrollHeight(self)
    end

    local _old_refreshBackpacks = ISInventoryPage.refreshBackpacks
    ISInventoryPage.refreshBackpacks = function(self)
        if self.killTheChoice then
            self.backpackChoice = nil
            self.killTheChoice = false
        end

        _old_refreshBackpacks(self)

        self:bcRefreshUtilityPanel()

        if Reorder.canSortBackpacks(self) then
            self:applyBackpackOrder()
        else
            self:bcApplyTopButtonsOffset()
        end
        refreshContainerButtonPanelScrollHeight(self)

        self.pendingReorder = false
    end

    local _old_onMouseWheel = ISInventoryPage.onMouseWheel
    ISInventoryPage.onMouseWheel = function(self, del)
        local inContainerArea = false
        if Helpers.isPageLeft(self) then
            inContainerArea = self:getMouseX() < self.containerButtonPanel.width
        else
            inContainerArea = self:getMouseX() >= (self:getWidth() - self.containerButtonPanel.width)
        end

        if not inContainerArea and not self:isCycleContainerKeyDown() then
            --return false
        end

        local originalOrder = {}
        for index, button in ipairs(self.backpacks) do
            originalOrder[button] = index
        end

        table.sort(self.backpacks, function(a, b)
            return a:getY() < b:getY()
        end)

        self.pendingReorder = true

        local retVal = _old_onMouseWheel(self, del)

        if self.pendingReorder then
            table.sort(self.backpacks, function(a, b)
                return originalOrder[a] < originalOrder[b]
            end)
            self.pendingReorder = false
        end

        return retVal
    end

    local _old_onJoypadDown = ISInventoryPage.onJoypadDown
    local function onJoypadDown(self, target, button)
        local originalOrder = {}
        for index, buttonObj in ipairs(target.backpacks) do
            originalOrder[buttonObj] = index
        end

        table.sort(target.backpacks, function(a, b)
            return a:getY() < b:getY()
        end)

        target.killTheChoice = true

        local retVal = _old_onJoypadDown(self, button)

        table.sort(target.backpacks, function(a, b)
            return originalOrder[a] < originalOrder[b]
        end)

        return retVal
    end

    ISInventoryPage.onJoypadDown = function(self, button)
        if button == Joypad.LBumper then
            return onJoypadDown(self, getPlayerInventory(self.player), button)
        end

        if button == Joypad.RBumper then
            local lootPage = getPlayerLoot(self.player)
            if Reorder.canSortBackpacks(lootPage) then
                return onJoypadDown(self, lootPage, button)
            end
        end

        return _old_onJoypadDown(self, button)
    end
end

return Reorder_ISInventoryPage