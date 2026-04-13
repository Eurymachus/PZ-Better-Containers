require "ISUI/ISInventoryPane"
local Proximity = require("BetterContainers/Proximity")

-- local copy of vanilla isSelectAllPossible for our overridden update
local function _ISInventoryPane_isSelectAllPossible(page)
    if not page then return false end
    if not page:isVisible() then return false end
    if page.isCollapsed then return false end
    if not page:isMouseOver() then return false end
    for _, v in pairs(page.inventoryPane.selected) do
        return true
    end
    return false
end


-- keep original update around
local _old_ISInventoryPane_update = ISInventoryPane.update

function ISInventoryPane:update()
    local inv = self.inventory
    local invType = inv and inv:getType() or nil

    -- For all normal containers, use vanilla behaviour
    if invType ~= Proximity.invName and invType ~= Proximity.invName_corpses then
        return _old_ISInventoryPane_update(self)
    end

    ----------------------------------------------------------------
    -- Custom update() for virtual containers (Proximity.invName / Proximity.invName_corpses)
    -- based on vanilla ISInventoryPane:update(), but WITHOUT the
    -- "v:getContainer() ~= self.inventory" selection cleanup.
    ----------------------------------------------------------------

    local playerObj = getSpecificPlayer(self.player)

    if self.doController then
        -- vanilla behaviour
        if (self.player ~= 0) or (wasMouseActiveMoreRecentlyThanJoypad() == false) then
            table.wipe(self.selected)
        end
        if self.joyselection == nil then
            self.joyselection = 0
        end
    end

    self:updateTooltip()

    -- *** IMPORTANT DIFFERENCE ***
    -- We DO NOT clear self.selected based on v:getContainer() here,
    -- because Proximity.invName / Proximity.invName_corpses are VIRTUAL containers and
    -- their items always live in their real containers.

    -- Make it select the header if all sub items in expanded item are selected.
    -- (Unchanged vanilla logic)
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

    -- If the user was dragging items from this pane and the mouse wasn't
    -- released over a valid drop location, then we must clear the drag info.
    -- Additionally, if the mouse was released outside any UIElement, then
    -- we will drop the items onto the floor (unless this pane is floor).
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

            -- vanilla: clear selection after drop
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

    -- If the user was draggingMarquis from this pane and the mouse
    -- wasn't released over a valid location, clear the marquis.
    if self.draggingMarquis and not isMouseButtonDown(0) then
        self.draggingMarquis = false
    end

    if self.doController then
        return
    end

    -- Ctrl+A / Select-All handling (unchanged)
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