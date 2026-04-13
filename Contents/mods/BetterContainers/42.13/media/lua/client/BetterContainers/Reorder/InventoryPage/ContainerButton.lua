local Helpers = require("BetterContainers/Helpers")
local ContainerButton = {}

function ContainerButton:getInstance(button, page)

    if not button then
        Helpers.dlog("Button [" .. tostring(button.name or "unknown") .. "] could not be instanced!")
        return
    end

    button.page = page
    button.player = page.player

    -- Buttons can be reused, so we need to make sure we don't overwrite the original functions

    if not button._onMouseDown_BetterContainers_Reorder then
        button._onMouseDown_BetterContainers_Reorder = button.onMouseDown
    end
    button.onMouseDown = ContainerButton.onMouseDown

    if not button._onMouseMove_BetterContainers_Reorder then
        button._onMouseMove_BetterContainers_Reorder = button.onMouseMove
    end
    button.onMouseMove = ContainerButton.onMouseMove

    if not button._onMouseMoveOutside_BetterContainers_Reorder then
        button._onMouseMoveOutside_BetterContainers_Reorder = button.onMouseMoveOutside
    end
    button.onMouseMoveOutside = ContainerButton.onMouseMoveOutside

    if not button._onMouseUp_BetterContainers_Reorder then
        button._onMouseUp_BetterContainers_Reorder = button.onMouseUp
    end
    button.onMouseUp = ContainerButton.onMouseUp

    if not button._onMouseUpOutside_BetterContainers_Reorder then
        button._onMouseUpOutside_BetterContainers_Reorder = button.onMouseUpOutside
    end
    button.onMouseUpOutside = ContainerButton.onMouseUpOutside

    return button
end

-- Mouse down: start potential drag-to-reorder
function ContainerButton:onMouseDown(x, y)
    -- 'self' is the container BUTTON

    -- Call original
    self._onMouseDown_BetterContainers_Reorder(self, x, y)

    self.reorderStartMouseY = getMouseY()
    self.reorderStartY = self:getY()

    -- Can we drag? (needs the real page)
    self.canDragToReorder = self.page
                            and not Reorder.isLocked(self.page)
                            and Reorder.canSortBackpacks(self.page)
                            or false
end

-- Mouse move: do the drag inside the PANEL, compare thresholds using PAGE buttonSize
function ContainerButton:onMouseMove(dx, dy, skipOgMouseMove)
    if not skipOgMouseMove then
        self._onMouseMove_BetterContainers_Reorder(self, dx, dy)
    end

    if not (self.pressed and self.canDragToReorder) then
        return
    end

    if math.abs(self.reorderStartMouseY - getMouseY()) > (self.page.buttonSize / 2) then
        self.draggingToReorder = true
    end

    local panel = self.parent
    if not panel then return end

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

        self.draggingToReorder = true
    end
end

-- Mouse move outside: keep existing behavior, re-use our onMouseMove
function ContainerButton:onMouseMoveOutside(dx, dy)
    self._onMouseMoveOutside_BetterContainers_Reorder(self, dx, dy)

    if self.pressed and self.canDragToReorder then
        ContainerButton.onMouseMove(self, dx, dy, true)
    end
end

-- Mouse up: apply new order on the PAGE
function ContainerButton:onMouseUp(x, y)
    local page = self.page
    if self.draggingToReorder and page then
        self.pressed = false
        self.draggingToReorder = false
        page:setContainerButtons_Reorder(self)
        page:refreshBackpacks()
    else
        self._onMouseUp_BetterContainers_Reorder(self, x, y)
    end
end

function ContainerButton:onMouseUpOutside(x, y)
    local page = self.page
    if self.draggingToReorder and page then
        self.pressed = false;
        self.draggingToReorder = false
        page:setContainerButtons_Reorder(self)
        page:refreshBackpacks()
    else
        self._onMouseUpOutside_BetterContainers_Reorder(self, x, y)
    end
end

return ContainerButton