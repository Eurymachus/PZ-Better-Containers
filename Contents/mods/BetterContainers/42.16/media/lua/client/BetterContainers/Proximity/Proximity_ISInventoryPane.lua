require "ISUI/ISInventoryPane"

local Proximity = require("BetterContainers/Proximity")

local ProximityInventoryPane = {}

ProximityInventoryPane._installed = false

local function _ISInventoryPane_isSelectAllPossible(page)
    if not page then return false end
    if not page:isVisible() then return false end
    if page.isCollapsed then return false end
    if not page:isMouseOver() then return false end

    for _, _ in pairs(page.inventoryPane.selected) do
        return true
    end

    return false
end

function ProximityInventoryPane.install()
    if ProximityInventoryPane._installed then return end
    ProximityInventoryPane._installed = true

    local _old_ISInventoryPane_update = ISInventoryPane.update
    function ISInventoryPane:update()
        local inv = self.inventory
        local invType = inv and inv:getType() or nil

        if invType ~= Proximity.invName and invType ~= Proximity.invName_corpses then
            return _old_ISInventoryPane_update(self)
        end

        local playerObj = getSpecificPlayer(self.player)

        if self.doController then
            if (self.player ~= 0) or (wasMouseActiveMoreRecentlyThanJoypad() == false) then
                table.wipe(self.selected)
            end
            if self.joyselection == nil then
                self.joyselection = 0
            end
        end

        self:updateTooltip()

        for i, v in ipairs(self.items) do
            if not instanceof(v, "InventoryItem") and self.selected[i] == nil and not self.collapsed[v.name] then
                local anyNot = false
                for j = 2, #v.items do
                    if self.selected[i + j - 1] == nil then
                        anyNot = true
                        break
                    end
                end
                if not anyNot then
                    self.selected[i] = v
                end
            end
        end

        if ISMouseDrag.dragging ~= nil and ISMouseDrag.draggingFocus == self and not isMouseButtonDown(0) then
            if getCore():getGameMode() == "Tutorial" then
                if ISMouseDrag.draggingFocus then
                    ISMouseDrag.draggingFocus:onMouseUp(0, 0)
                end
                ISMouseDrag.draggingFocus = nil
                ISMouseDrag.dragging = nil
                return
            end

            local dragContainsMovables = false
            local dragContainsNonMovables = false
            local mx = getMouseX()
            local my = getMouseY()
            local uis = UIManager.getUI()
            local mouseOverUI

            for i = 0, uis:size() - 1 do
                local ui = uis:get(i)
                if ui:isPointOver(mx, my) then
                    mouseOverUI = ui
                    break
                end
            end

            local noVehicle = true
            local vehicleNoWindow = true
            local vehicleWindowOpen = true

            local vehicle = playerObj:getVehicle()
            if vehicle ~= nil then
                noVehicle = false
                local seat = vehicle:getSeat(playerObj)
                local door = vehicle:getPassengerDoor(seat)
                local windowPart = VehicleUtils.getChildWindow(door)
                if windowPart and (not windowPart:getItemType() or windowPart:getInventoryItem()) then
                    vehicleNoWindow = false
                    local window = windowPart:getWindow()
                    if window:isOpenable() and not window:isOpen() then
                        vehicleWindowOpen = false
                    end
                end
            end

            if self.inventory:getType() ~= "floor" and not mouseOverUI and (noVehicle or vehicleNoWindow or vehicleWindowOpen) then
                local dragging = ISInventoryPane.getActualItems(ISMouseDrag.dragging)

                for _, v in ipairs(dragging) do
                    if not self.inventory:isInside(v) and not v:isFavorite() then
                        if not instanceof(v, "Moveable") or v:CanBeDroppedOnFloor() then
                            ISInventoryPaneContextMenu.dropItem(v, self.player)
                            dragContainsNonMovables = true
                        else
                            dragContainsMovables = dragContainsMovables or v
                        end
                    end
                end

                self.selected = {}
                getPlayerLoot(self.player).inventoryPane.selected = {}
                getPlayerInventory(self.player).inventoryPane.selected = {}
            end

            self.inventoryPage.selectedSqDrop = nil
            self.inventoryPage.render3DItems = {}
            self.dragging = nil
            self.draggedItems:reset()
            ISMouseDrag.dragging = nil
            ISMouseDrag.draggingFocus = nil

            if dragContainsMovables and not dragContainsNonMovables then
                local mo = ISMoveableCursor:new(getSpecificPlayer(self.player))
                getCell():setDrag(mo, mo.player)
                mo:setMoveableMode("place")
                mo:tryInitialItem(dragContainsMovables)
            end
        end

        if self.draggingMarquis and not isMouseButtonDown(0) then
            self.draggingMarquis = false
        end

        if self.doController then
            return
        end

        local page1 = getPlayerInventory(0)
        local page2 = getPlayerLoot(0)
        if not page1 or not page2 then
            return
        end

        if isCtrlKeyDown() and (_ISInventoryPane_isSelectAllPossible(page1) or _ISInventoryPane_isSelectAllPossible(page2)) then
            getCore():setIsSelectingAll(true)
        else
            getCore():setIsSelectingAll(false)
        end

        if isCtrlKeyDown() and isKeyDown(Keyboard.KEY_A) and _ISInventoryPane_isSelectAllPossible(self.parent) then
            table.wipe(self.selected)
            for k, v in ipairs(self.items) do
                self.selected[k] = v
            end
        end
    end

    local _old_clearWorldObjectHighlights = ISInventoryPane.clearWorldObjectHighlights
    function ISInventoryPane:clearWorldObjectHighlights()
        local held = Proximity.getProximityHoveredItem(self.player)

        for worldItem in pairs(self.highlightItems) do
            Proximity.getVanillaHoveredItem(self.player)[worldItem] = nil

            if held[worldItem] then
                self.highlightItems[worldItem] = nil
            end
        end

        return _old_clearWorldObjectHighlights(self)
    end

    local _old_doWorldObjectHighlight = ISInventoryPane.doWorldObjectHighlight
    function ISInventoryPane:doWorldObjectHighlight(_item)
        if instanceof(_item, "InventoryItem") then
            local worldItem = _item:getWorldItem()
            if worldItem and worldItem:getChunk() ~= nil then
                Proximity.getVanillaHoveredItem(self.player)[worldItem] = worldItem
            end
        end

        return _old_doWorldObjectHighlight(self, _item)
    end
end

return ProximityInventoryPane