require "ISUI/ISInventoryPage"

local Helpers = require("BetterContainers/Helpers")
local Options = require("BetterContainers/_Options")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6

local SwitchSides = {}

local function _setAnchors(ui, left, right, top, bottom)
    if not ui then return end

    if ui.setAnchorLeft then ui:setAnchorLeft(left) else ui.anchorLeft = left end
    if ui.setAnchorRight then ui:setAnchorRight(right) else ui.anchorRight = right end
    if top ~= nil then
        if ui.setAnchorTop then ui:setAnchorTop(top) else ui.anchorTop = top end
    end
    if bottom ~= nil then
        if ui.setAnchorBottom then ui:setAnchorBottom(bottom) else ui.anchorBottom = bottom end
    end
end

local function _layoutPage(page)
    if not page or not page.inventoryPane or not page.containerButtonPanel then
        return
    end

    local buttonSize = page.buttonSize or 0
    local width = page:getWidth()
    local left = page.isPageLeft_BetterContainers and page:isPageLeft_BetterContainers()

    page.inventoryPane:setWidth(width - buttonSize)
    page.containerButtonPanel:setWidth(buttonSize)

    page.containerButtonPanel:setY(page.inventoryPane.y)
    page.containerButtonPanel:setHeight(page.inventoryPane.height)

    -- Inventory pane should stretch with the page, but keep its left offset.
    _setAnchors(page.inventoryPane, true, true, true, true)

    if left then
        page.inventoryPane:setX(buttonSize)

        _setAnchors(page.containerButtonPanel, true, false, true, true)
        page.containerButtonPanel:setX(0)
    else
        page.inventoryPane:setX(0)

        _setAnchors(page.containerButtonPanel, false, true, true, true)
        page.containerButtonPanel:setX(width - buttonSize)
    end

    --_layoutControlsUI(page)
end

local function _applyToExistingPages()
    for playerNum = 0, getNumActivePlayers() - 1 do
        local invPage = getPlayerInventory(playerNum)
        if invPage then
            Helpers.dlog("Applying SwitchSides to existing player page")
            _layoutPage(invPage)
        end

        local lootPage = getPlayerLoot(playerNum)
        if lootPage then
            Helpers.dlog("Applying SwitchSides to existing loot page")
            _layoutPage(lootPage)
        end
    end
end

local function _prerenderLeft(self, oldPrerender)
    local shouldBeVisible = false
    if self.blinkContainer then
        if not self.blinkAlphaContainer then
            self.blinkAlphaContainer = 0.7
            self.blinkAlphaIncreaseContainer = false
        end

        if not self.blinkAlphaIncreaseContainer then
            self.blinkAlphaContainer = self.blinkAlphaContainer - 0.04 * (UIManager.getMillisSinceLastRender() / 33.3)
            if self.blinkAlphaContainer < 0.3 then
                self.blinkAlphaContainer = 0.3
                self.blinkAlphaIncreaseContainer = true
            end
        else
            self.blinkAlphaContainer = self.blinkAlphaContainer + 0.04 * (UIManager.getMillisSinceLastRender() / 33.3)
            if self.blinkAlphaContainer > 0.7 then
                self.blinkAlphaContainer = 0.7
                self.blinkAlphaIncreaseContainer = false
            end
        end

        for i, v in ipairs(self.backpacks) do
            if (self.blinkContainerType and v.inventory:getType() == self.blinkContainerType) or not self.blinkContainerType then
                if v.inventory == self.inventoryPane.inventory then
                    v:setBackgroundRGBA(1, 0, 0, self.blinkAlphaContainer)
                else
                    v:setBackgroundRGBA(1, 0, 0, self.blinkAlphaContainer * 0.75)
                end
            end
        end
    end

    local titleBarHeight = self:titleBarHeight()
    local height = self:getHeight()
    if self.isCollapsed then
        height = titleBarHeight
    end

    self:drawRect(0, 0, self:getWidth(), height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)

    if not self.blink then
        self:drawTextureScaled(self.titlebarbkg, 2, 1, self:getWidth() - 4, titleBarHeight - 2, 1, 1, 1, 1)
    else
        if not self.blinkAlpha then
            self.blinkAlpha = 1
        end

        self:drawRect(1, 1, self:getWidth() - 2, titleBarHeight - 2, self.blinkAlpha, 1, 1, 1)

        if not self.blinkAlphaIncrease then
            self.blinkAlpha = self.blinkAlpha - 0.1 * (UIManager.getMillisSinceLastRender() / 33.3)
            if self.blinkAlpha < 0 then
                self.blinkAlpha = 0
                self.blinkAlphaIncrease = true
            end
        else
            self.blinkAlpha = self.blinkAlpha + 0.1 * (UIManager.getMillisSinceLastRender() / 33.3)
            if self.blinkAlpha > 1 then
                self.blinkAlpha = 1
                self.blinkAlphaIncrease = false
            end
        end
    end

    self:drawRectBorder(0, 0, self:getWidth(), titleBarHeight, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    if not self.isCollapsed then
        self:drawRect(0, titleBarHeight, self.buttonSize, self.inventoryPane.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    end

    if self.title and self.onCharacter then
        self:drawText(self.title, self.infoButton:getRight() + (5 - getCore():getOptionFontSizeReal()) * 2, 0, 1, 1, 1, 1)
    end

    local weightLabel
    local buttonOffset = 1 + (5 - getCore():getOptionFontSizeReal()) * 2

    self.totalWeight = ISInventoryPage.loadWeight(self.inventoryPane.inventory)
    local roundedWeight = round(self.totalWeight, 2)

    if self.capacity then
        local inventory = self.inventoryPane.inventory
        if inventory == getSpecificPlayer(self.player):getInventory() then
            self:drawTextRight(roundedWeight .. " / " .. getSpecificPlayer(self.player):getMaxWeight(), self.pinButton:getX(), 0, 1, 1, 1, 1)
        else
            if isClient() then
                local itemLimit = getServerOptions():getInteger("ItemNumbersLimitPerContainer")
                if itemLimit > 0 then
                    weightLabel = roundedWeight .. " / " .. self.capacity .. " (" .. self.totalItems .. " / " .. itemLimit .. ")"
                else
                    weightLabel = roundedWeight .. " / " .. self.capacity
                end
            else
                weightLabel = roundedWeight .. " / " .. self.capacity
            end
        end
    else
        weightLabel = roundedWeight .. ""
    end

    self:drawTextRight(weightLabel, self.pinButton:getX() - buttonOffset, 0, 1, 1, 1, 1)

    local weightWid = getTextManager():MeasureStringX(UIFont.Small, "9999.99 / 9999") + 30

    if self.title and not self.onCharacter then
        local fontHgt = getTextManager():getFontHeight(self.font)
        local text = self.title
        if self.inventoryPane.inventory and self.inventoryPane.inventory:getParent() then
            local fireTile = self.inventoryPane.inventory:getParent()
            local campfire = CCampfireSystem.instance:getLuaObjectOnSquare(fireTile:getSquare())
            if campfire then
                shouldBeVisible = true
                text = text .. ": " .. (ISCampingMenu.timeString(luautils.round(campfire.fuelAmt)))
            elseif fireTile and fireTile:isFireInteractionObject() then
                shouldBeVisible = true
                if fireTile:isPropaneBBQ() and not fireTile:hasPropaneTank() then
                    text = text .. ": " .. getText("IGUI_BBQ_NeedsPropaneTank")
                else
                    text = text .. ": " .. tostring(ISCampingMenu.timeString(fireTile:getFuelAmount()))
                end
            end
        end

        if self.inventoryPane.inventory and self.inventoryPane.inventory:isOccupiedVehicleSeat() then
            text = text .. " " .. getText("IGUI_invpage_Occupied")
        end

        self:drawTextRight(text, self.width - 20 - weightWid, (titleBarHeight - fontHgt) / 2, 1, 1, 1, 1)
    end

    self:setStencilRect(0, 0, self.width + 1, height)
    if not self.bcSuppressKeepVisible then
        self.containerButtonPanel:keepSelectedButtonVisible()
    end
end

local function _renderLeft(self, oldRender)
    local titleBarHeight = self:titleBarHeight()
    local rh = BUTTON_HGT / 2 + 2
    local height = self:getHeight()
    if self.isCollapsed then
        height = titleBarHeight
    end

    if not self.isCollapsed then
        self:drawRectBorder(0, self.inventoryPane.y, self.buttonSize, self.inventoryPane.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
        self:drawRectBorder(0, height - rh, self:getWidth(), rh, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
        self:drawTextureScaled(self.statusbarbkg, 1, height - rh + 1, self:getWidth() - 2, rh - 2, 1, 1, 1, 1)
        self:drawTextureScaled(self.resizeimage, self:getWidth() - rh + 1, height - rh + 1, rh - 2, rh - 2, 1, 1, 1, 1)
        if self.controlsUI and self.controlsUI:isVisible() then
            self:drawRectBorder(self.controlsUI.x, self.controlsUI.y, self.controlsUI.width, self.controlsUI.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
        end
    end

    self:clearStencilRect()
    self:drawRectBorder(0, 0, self:getWidth(), height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    if self.joyfocus then
        self:drawRectBorder(0, 0, self:getWidth(), self:getHeight(), 0.4, 0.2, 1.0, 1.0)
        self:drawRectBorder(1, 1, self:getWidth() - 2, self:getHeight() - 2, 0.4, 0.2, 1.0, 1.0)
    end

    if self.render3DItems and #self.render3DItems > 0 then
        self:render3DItemPreview()
    end
end

SwitchSides.install = function()
    Helpers.dlog("SwitchSides.install entered.")
    require "ISUI/ISInventoryPage"

    if Helpers.isCleanUIActive() then
        Helpers.dlog("Clean UI active - Switch Sides install skipped.")
        return
    end

    if not ISInventoryPage._BetterContainers_SwitchSides_installed then
        ISInventoryPage.isPageLeft_BetterContainers = function(self)
            if not self then return false end
            if self.onCharacter then
                return Options.inventoryLeft_Player == true
            end
            return Options.inventoryLeft_Loot == true
        end
        
        local _old_createChildren = ISInventoryPage.createChildren
        ISInventoryPage.createChildren = function(self)
            _old_createChildren(self)
            _layoutPage(self)
        end

        local _old_onInventoryContainerSizeChanged = ISInventoryPage.onInventoryContainerSizeChanged
        ISInventoryPage.onInventoryContainerSizeChanged = function(self)
            Helpers.dlog("onInventoryContainerSizeChanged")
            _old_onInventoryContainerSizeChanged(self)
            _layoutPage(self)
        end

        local _old_prerender = ISInventoryPage.prerender
        ISInventoryPage.prerender = function(self)
            local isLeft = self.isPageLeft_BetterContainers and self:isPageLeft_BetterContainers()
            if not isLeft then
                return _old_prerender(self)
            end

            return _prerenderLeft(self, _old_prerender)
        end

        local _old_render = ISInventoryPage.render
        ISInventoryPage.render = function(self)
            local isLeft = self.isPageLeft_BetterContainers and self:isPageLeft_BetterContainers()
            if not isLeft then
                return _old_render(self)
            end

            return _renderLeft(self, _old_render)
        end

        local _old_refreshBackpacks = ISInventoryPage.refreshBackpacks
        ISInventoryPage.refreshBackpacks = function(self)
            _old_refreshBackpacks(self)

            local isLeft = self.isPageLeft_BetterContainers and self:isPageLeft_BetterContainers()
            if not isLeft then
                return
            end

            _layoutPage(self)
        end

        local _old_onMouseWheel = ISInventoryPage.onMouseWheel
        ISInventoryPage.onMouseWheel = function(self, del)
            local isLeft = self.isPageLeft_BetterContainers and self:isPageLeft_BetterContainers()
            if not isLeft then
                return _old_onMouseWheel(self, del)
            end

            local mx = self:getMouseX()
            local buttonSize = self.buttonSize or 0

            -- Left-handed strip: only treat wheel as container-cycle input
            -- when the cursor is actually over the visible strip.
            if mx > buttonSize and not self:isCycleContainerKeyDown() then
                return false
            end

            -- Vanilla expects the strip on the right. Temporarily fake the
            -- mouse X so the existing handler accepts the event.
            local oldGetMouseX = self.getMouseX
            self.getMouseX = function(page)
                return page:getWidth()
            end

            local ok, ret = pcall(_old_onMouseWheel, self, del)

            self.getMouseX = oldGetMouseX

            if ok then
                return ret
            end
            error(ret)
        end

        ISInventoryPage._BetterContainers_SwitchSides_installed = true

        Events[Helpers.OPTIONS_APPLIED].Add(_applyToExistingPages)
    end

    Helpers.dlog("SwitchSides page wrappers installed.")
end

return SwitchSides