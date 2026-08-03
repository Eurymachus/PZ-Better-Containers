require "ISUI/ISInventoryPage"
require "ISUI/ISResizeWidget"

local Helpers = require("BetterContainers/Helpers")
local Options = require("BetterContainers/_Options")

local LockInventory = {}

local _installed = false

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6

local function canLockWindow(page)
    return page
        and not Helpers.isCleanUIActive()
        and (Options.enableLockInventory ~= false)
end

local function isWindowLockActive(page)
    return canLockWindow(page)
        and page.bcIsLocked
        and page:bcIsLocked()
end

local function stopPageMove(page)
    if not page then
        return
    end

    page.moving = false
    if page.setCapture then
        page:setCapture(false)
    end
end

local function updateResizeWidget(page)
    if not page or not canLockWindow(page) then
        return
    end

    local visible = not (page.bcIsLocked and page:bcIsLocked())

    if page.resizeWidget then
        page.resizeWidget:setVisible(visible)
    end

    if page.resizeWidget2 then
        page.resizeWidget2:setVisible(visible)
    end
end

function LockInventory.install()
    if _installed then
        return
    end
    _installed = true

    local old_createChildren = ISInventoryPage.createChildren
    ISInventoryPage.createChildren = function(self)
        old_createChildren(self)
        updateResizeWidget(self)
    end

    local old_update = ISInventoryPage.update
    ISInventoryPage.update = function(self)
        old_update(self)
        updateResizeWidget(self)
    end

    local old_render = ISInventoryPage.render
    ISInventoryPage.render = function(self)
        old_render(self)

        if not isWindowLockActive(self) or self.isCollapsed then
            return
        end

        local rh = BUTTON_HGT / 2 + 2
        local height = self:getHeight()

        self:drawTextureScaled(self.statusbarbkg, 1, height - rh + 1, self:getWidth() - 2, rh - 2, 1, 1, 1, 1)
        self:drawTextureScaled(self.resizeimage, self:getWidth() - rh + 1, height - rh + 1, rh - 2, rh - 2, 1, 1, 0, 0)
    end

    local old_onMouseDown = ISInventoryPage.onMouseDown
    ISInventoryPage.onMouseDown = function(self, x, y)
        if not isWindowLockActive(self) then
            return old_onMouseDown(self, x, y)
        end

        if not self:getIsVisible() then
            return
        end

        local playerObj = self.player ~= nil and getSpecificPlayer(self.player) or nil
        if playerObj then
            playerObj:nullifyAiming()
        end

        self.downX = self:getMouseX()
        self.downY = self:getMouseY()
        self.moving = false
        self:setCapture(false)
    end

    local old_onMouseMove = ISInventoryPage.onMouseMove
    ISInventoryPage.onMouseMove = function(self, dx, dy)
        if self.moving and isWindowLockActive(self) then
            stopPageMove(self)
        end
        return old_onMouseMove(self, dx, dy)
    end

    local old_onMouseMoveOutside = ISInventoryPage.onMouseMoveOutside
    ISInventoryPage.onMouseMoveOutside = function(self, dx, dy)
        if self.moving and isWindowLockActive(self) then
            stopPageMove(self)
        end
        return old_onMouseMoveOutside(self, dx, dy)
    end
end

return LockInventory
