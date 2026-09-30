local Options = require("BetterContainers/_Options")

local WeightColumn = {}

local function sortByWeight(pane)
    local player = getSpecificPlayer(pane.player)
    if player and player:isAsleep() then return end
    pane:sortByWeight(pane.itemSortFunc == ISInventoryPane.itemSortByWeightDesc)
end

local function layout(pane)
    if not pane.nameHeader or not pane.typeHeader then return end
    local defaultWidth = math.max(60, getTextManager():MeasureStringX(pane.font, "9999.99") + 16)
    -- Like vanilla Category, the header extends behind the scrollbar.
    local right = pane.width
    local minimumWidth = math.max(60, getTextManager():MeasureStringX(pane.font, "0.00") + 12)
    local categoryMinimum = math.max(100, pane.bcWeightCategoryMinimum or pane.typeHeader.minimumWidth,
        getTextManager():MeasureStringX(pane.typeHeader.font or UIFont.Small, pane.typeHeader.title or "") + 16)
    local maximumWidth = right - pane.column2 - pane.nameHeader.minimumWidth - categoryMinimum
    local width = math.max(minimumWidth, math.min(pane.bcWeightWidth or defaultWidth, maximumWidth))
    local enabled = Options.showWeightColumn and pane.mode == "details"
        and maximumWidth >= minimumWidth
    if not pane.bcWeightHeader then
        if not enabled then return end
        local button = ISResizableButton:new(0, pane.nameHeader:getY(), width, pane.nameHeader:getHeight(), "", pane, sortByWeight)
        button:initialise()
        button.resizeLeft = true
        button.minimumWidth = minimumWidth
        button.onresize = { ISInventoryPane.onResizeColumn, pane, button }
        button.borderColor.a = 0.2
        button:setImage(getTexture("media/ui/Moodles/32/Status_HeavyLoad.png"))
        pane:addChild(button)
        -- This header is created after vanilla's scrollbars, so restore their foreground order.
        if pane.vscroll then pane.vscroll:bringToTop() end
        if pane.hscroll then pane.hscroll:bringToTop() end
        pane.bcWeightHeader = button
    end
    pane.bcWeightHeader:setVisible(enabled)
    if not enabled then
        if pane.bcWeightX then
            pane.typeHeader.minimumWidth = pane.bcWeightCategoryMinimum
            pane.typeHeader:setWidth(pane.width - pane.typeHeader.x)
            pane.bcWeightX = nil
        end
        return
    end
    if not pane.bcWeightX then pane.bcWeightCategoryMinimum = pane.typeHeader.minimumWidth end
    local left = right - width
    pane.column3 = math.max(pane.column2 + pane.nameHeader.minimumWidth,
        math.min(pane.column3, left - categoryMinimum + 1))
    pane.nameHeader:setWidth(pane.column3 - pane.column2)
    pane.typeHeader:setX(pane.column3 - 1)
    -- Share the border pixel, just like vanilla's Item/Category divider.
    pane.typeHeader:setWidth(math.max(1, left - pane.typeHeader.x + 1))
    pane.typeHeader.minimumWidth = categoryMinimum
    pane.nameHeader.maximumWidth = math.max(pane.nameHeader.minimumWidth, left - categoryMinimum - pane.column2)
    pane.typeHeader.maximumWidth = math.max(categoryMinimum, left - pane.column2 - pane.nameHeader.minimumWidth + 1)
    pane.bcWeightX = left
    pane.bcWeightRight = right
    pane.bcWeightHeader:setX(left)
    pane.bcWeightHeader:setWidth(width)
    pane.bcWeightHeader.minimumWidth = minimumWidth
    -- Stop at Category's minimum instead of pushing the Item/Category divider.
    pane.bcWeightHeader.maximumWidth = math.max(minimumWidth, right - pane.typeHeader.x - categoryMinimum + 1)
    -- headerHgt includes the search strip; follow the actual column button bounds.
    pane.bcWeightHeader:setY(pane.nameHeader:getY())
    pane.bcWeightHeader:setHeight(pane.nameHeader:getHeight())
    -- The 32px moodle texture has only 19px of visible artwork vertically.
    -- Scale the artwork, including its transparent padding, to fill the header.
    local iconSize = math.max(1, math.floor((pane.nameHeader:getHeight() - 4) * 32 / 19))
    pane.bcWeightHeader:forceImageSize(iconSize, iconSize)
end

-- Remove complete UTF-8 characters when fitting translated labels.
local function fitText(text, font, width)
    local manager = getTextManager()
    if manager:MeasureStringX(font, text) <= width then return text end
    local suffix = "..."
    if manager:MeasureStringX(font, suffix) > width then return "" end
    while #text > 0 do
        local last = #text
        while last > 1 and string.byte(text, last) >= 128 and string.byte(text, last) < 192 do
            last = last - 1
        end
        text = string.sub(text, 1, last - 1)
        if manager:MeasureStringX(font, text .. suffix) <= width then return text .. suffix end
    end
    return suffix
end

local function drawWeight(pane, row, weight)
    if pane.dragging and pane.dragStarted and pane.selected and pane.selected[row + 1] then return end
    local top = pane.headerHgt + row * pane.itemHgt
    local visibleTop = top + pane:getYScroll()
    if visibleTop + pane.itemHgt <= pane.headerHgt or visibleTop >= pane.height then return end
    local text = string.format("%.2f", weight or 0)
    text = fitText(text, pane.font, pane.bcWeightRight - pane.bcWeightX - 8)
    pane:drawText(text, pane.bcWeightX + 8,
        top + (pane.itemHgt - pane.fontHgt) / 2, 0.75, 0.75, 0.75, 1, pane.font)
end

local function drawWeights(pane)
    local clipHeight = pane.height - pane.headerHgt - 1
    if clipHeight <= 0 then return end
    -- Draw partial rows normally; clip their text instead of hiding the whole value.
    pane:setStencilRect(0, pane.headerHgt, pane.width - 1, clipHeight)
    local row = 0
    for _, stack in ipairs(pane.itemslist or {}) do
        if not stack._bcEquippedAttachedSeparator then drawWeight(pane, row, stack.weight) end
        if not (pane.collapsed and pane.collapsed[stack.name]) then
            local items = stack.items or {}
            for index = 2, math.min(#items, ISInventoryPane.MAX_ITEMS_IN_STACK_TO_RENDER + 1) do
                row = row + 1
                drawWeight(pane, row, items[index]:getUnequippedWeight())
            end
        end
        row = row + 1
    end
    pane:clearStencilRect()
    pane:repaintStencilRect(0, pane.headerHgt, pane.width - 1, clipHeight)
end

function WeightColumn.install()
    if WeightColumn._installed then return end
    WeightColumn._installed = true
    require("ISUI/ISInventoryPane")

    local oldResizeColumn = ISInventoryPane.onResizeColumn
    ISInventoryPane.onResizeColumn = function(self, button)
        if button == self.bcWeightHeader then
            self.bcWeightWidth = button:getWidth()
            layout(self)
            return
        end
        oldResizeColumn(self, button)
        layout(self)
    end

    local oldSaveLayout = ISInventoryPane.SaveLayout
    ISInventoryPane.SaveLayout = function(self, name, saved)
        oldSaveLayout(self, name, saved)
        saved.bcWeightWidth = self.bcWeightWidth
    end
    local oldRestoreLayout = ISInventoryPane.RestoreLayout
    ISInventoryPane.RestoreLayout = function(self, name, saved)
        self.bcWeightWidth = tonumber(saved.bcWeightWidth)
        oldRestoreLayout(self, name, saved)
        layout(self)
    end

    local oldRenderDetails = ISInventoryPane.renderdetails
    ISInventoryPane.renderdetails = function(self, doDragged, ...)
        layout(self)
        if doDragged or not self.bcWeightX then return oldRenderDetails(self, doDragged, ...) end
        local oldDrawText = self.drawText
        local oldDrawProgressBar = self.drawProgressBar
        -- Keep backgrounds and hit targets full width, fitting only row contents.
        self.drawText = function(pane, text, x, y, r, g, b, a, font, ...)
            if y >= pane.headerHgt then
                text = fitText(text, font or pane.font, math.max(0, pane.bcWeightX - x - 6))
            end
            return oldDrawText(pane, text, x, y, r, g, b, a, font, ...)
        end
        self.drawProgressBar = function(pane, x, y, width, ...)
            width = math.min(width, pane.bcWeightX - x - 6)
            if width > 0 then return oldDrawProgressBar(pane, x, y, width, ...) end
        end
        local result = oldRenderDetails(self, doDragged, ...)
        self.drawText = oldDrawText
        self.drawProgressBar = oldDrawProgressBar
        drawWeights(self)
        return result
    end

    local oldPrerender = ISInventoryPane.prerender
    ISInventoryPane.prerender = function(self, ...)
        -- Also restore the normal header when switching to icon mode.
        layout(self)
        return oldPrerender(self, ...)
    end

    local oldRender = ISInventoryPane.render
    ISInventoryPane.render = function(self, ...)
        local result = oldRender(self, ...)
        local header = self.bcWeightHeader
        -- Vanilla draws the resize guide only for its two built-in headers.
        if self.bcWeightX and header and (header.resizing or header.mouseOverResize) then
            local x, y = header:getX(), header:getY()
            self:repaintStencilRect(x, y, 2, self.height)
            self:drawRectStatic(x, y, 2, self.height, 0.5, 1, 1, 1)
        end
        return result
    end
end

return WeightColumn
