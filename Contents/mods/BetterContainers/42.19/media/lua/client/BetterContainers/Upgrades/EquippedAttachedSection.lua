require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryItem"

local Options = require("BetterContainers/_Options")

local EquippedAttachedSection = {}

local SECTION_KEY = "BetterContainers:EquippedAttachedSection"
local SEPARATOR_KEY = SECTION_KEY .. ":Separator"

local function addUnique(items, seen, item)
    if not item or seen[item] then return end
    if item.isHidden and item:isHidden() then return end

    seen[item] = true
    items[#items + 1] = item
end

local function collectEquippedAttachedItems(playerObj)
    local items = {}
    local seen = {}

    if not playerObj then return items, seen end

    local wornItems = playerObj:getWornItems()
    if wornItems then
        for i = 0, wornItems:size() - 1 do
            local wornItem = wornItems:get(i)
            addUnique(items, seen, wornItem and wornItem:getItem())
        end
    end

    addUnique(items, seen, playerObj:getPrimaryHandItem())
    addUnique(items, seen, playerObj:getSecondaryHandItem())

    local attachedItems = playerObj:getAttachedItems()
    if attachedItems then
        for i = 0, attachedItems:size() - 1 do
            local attachedItem = attachedItems:get(i)
            addUnique(items, seen, attachedItem and attachedItem:getItem())
        end
    end

    return items, seen
end

local function removeGroupedItemsFromExistingStacks(pane, groupedSet)
    if not pane or not pane.itemslist or not groupedSet then return end

    local keptStacks = {}

    for _, stack in ipairs(pane.itemslist) do
        local keptItems = {}
        local weight = 0

        for i = 2, #stack.items do
            local item = stack.items[i]
            if item and not groupedSet[item] then
                keptItems[#keptItems + 1] = item
                weight = weight + item:getUnequippedWeight()
            end
        end

        if #keptItems > 0 then
            table.insert(keptItems, 1, keptItems[1])
            stack.items = keptItems
            stack.count = #keptItems
            stack.weight = weight
            stack.equipped = false
            keptStacks[#keptStacks + 1] = stack
        end
    end

    pane.itemslist = keptStacks
end

local function isSectionCollapsed(pane)
    return pane and pane.bcEquippedAttachedCollapsed == true
end

local function buildSeparatorStack(pane, sectionItems)
    local firstItem = sectionItems and sectionItems[1] or nil
    if not firstItem then return nil end

    -- Keep vanilla's stack renderer happy, but force this row to stay one-line.
    pane.collapsed[SEPARATOR_KEY] = true

    return {
        _bcEquippedAttachedSeparator = true,
        _bcEquippedAttachedItems = sectionItems,
        _bcEquippedAttachedCount = #sectionItems,
        invPanel = pane,
        name = SEPARATOR_KEY,
        cat = SEPARATOR_KEY,
        count = 2,
        weight = 0,
        equipped = false,
        inHotbar = false,
        items = { firstItem, firstItem },
    }
end

local function buildItemStack(pane, item, index)
    local name = SECTION_KEY .. ":Item:" .. tostring(index) .. ":" .. tostring(item)
    pane.collapsed[name] = true

    return {
        _bcEquippedAttachedChild = true,
        invPanel = pane,
        name = name,
        cat = item:getDisplayCategory() or item:getCategory(),
        count = 2,
        weight = item:getUnequippedWeight(),
        equipped = false,
        inHotbar = true,
        items = { item, item },
    }
end

local function getItemDisplayName(item, playerObj)
    if not item then return "" end
    return item:getName(playerObj) or item:getDisplayName() or item:getType() or ""
end

local function getItemCategory(item)
    if not item then return "" end
    return item:getDisplayCategory() or item:getCategory() or ""
end

local function sortTextAsc(a, b)
    if a == b then return false end
    return not string.sort(a, b)
end

local function sortTextDesc(a, b)
    if a == b then return false end
    return string.sort(a, b)
end

local function sortSectionItems(pane, sectionItems, playerObj)
    if not pane or not pane.itemSortFunc or not sectionItems then return end

    local sortFunc = pane.itemSortFunc

    table.sort(sectionItems, function(a, b)
        if sortFunc == ISInventoryPane.itemSortByWeightAsc then
            return a:getUnequippedWeight() < b:getUnequippedWeight()
        end

        if sortFunc == ISInventoryPane.itemSortByWeightDesc then
            return a:getUnequippedWeight() > b:getUnequippedWeight()
        end

        local aName = getItemDisplayName(a, playerObj)
        local bName = getItemDisplayName(b, playerObj)

        if sortFunc == ISInventoryPane.itemSortByCatInc or sortFunc == ISInventoryPane.itemSortByCatDesc then
            local aCat = getItemCategory(a)
            local bCat = getItemCategory(b)

            if aCat == bCat then
                return sortTextAsc(aName, bName)
            end

            if sortFunc == ISInventoryPane.itemSortByCatInc then
                return sortTextAsc(aCat, bCat)
            end

            return sortTextDesc(aCat, bCat)
        end

        if sortFunc == ISInventoryPane.itemSortByNameDesc then
            return sortTextDesc(aName, bName)
        end

        return sortTextAsc(aName, bName)
    end)
end

local function applySection(pane)
    if not Options.showEquippedAttachedSection then return end
    if not pane or not pane.parent or not pane.parent.onCharacter then return end
    if not pane.itemslist or not pane.collapsed then return end

    local playerObj = getSpecificPlayer(pane.player)
    if not playerObj or pane.inventory ~= playerObj:getInventory() then return end

    local sectionItems, groupedSet = collectEquippedAttachedItems(playerObj)
    if #sectionItems == 0 then return end

    removeGroupedItemsFromExistingStacks(pane, groupedSet)
    sortSectionItems(pane, sectionItems, playerObj)

    local separatorStack = buildSeparatorStack(pane, sectionItems)
    if not separatorStack then return end

    pane.itemslist[#pane.itemslist + 1] = separatorStack

    if isSectionCollapsed(pane) then return end

    for index, item in ipairs(sectionItems) do
        pane.itemslist[#pane.itemslist + 1] = buildItemStack(pane, item, index)
    end
end

local function getSectionLabels()
    return getTextOrNull("UI_BetterContainers_EquippedAttachedSection") or "Equipped Items"
end

local function getHeaderDisplayName(stack, playerObj)
    if not stack or not stack.items or not stack.items[1] then return nil end

    local item = stack.items[1]
    return item:getName(playerObj)
end

local function findSectionHeaderDrawTargets(pane)
    if not pane or not pane.itemslist then return nil, nil, nil, nil end

    local playerObj = getSpecificPlayer(pane.player)
    for _, stack in ipairs(pane.itemslist) do
        if stack and stack._bcEquippedAttachedSeparator then
            local item = stack.items[1]
            local category = item and (item:getDisplayCategory() or item:getCategory()) or ""
            return getHeaderDisplayName(stack, playerObj),
                getTextOrNull("IGUI_ItemCat_" .. category) or category,
                item,
                stack
        end
    end

    return nil, nil, nil, nil
end

local function getSectionHeaderRow(pane)
    if not pane or not pane.itemslist then return nil end

    local row = 0
    for _, stack in ipairs(pane.itemslist) do
        if stack and stack._bcEquippedAttachedSeparator then
            return row
        end

        local rows = 1
        if stack and stack.items and not (pane.collapsed and stack.name and pane.collapsed[stack.name]) then
            rows = math.min(#stack.items, ISInventoryPane.MAX_ITEMS_IN_STACK_TO_RENDER + 1)
            if rows < 1 then rows = 1 end
        end
        row = row + rows
    end

    return nil
end

local function isSeparatorRow(row)
    return row and row._bcEquippedAttachedSeparator == true
end

local function getRowIndexAtLocalY(pane, y)
    if not pane or not pane.items or not y then return nil end
    if y < pane.headerHgt then return nil end

    local rowIndex = math.floor(((y - pane.headerHgt) / pane.itemHgt) + 1)
    if rowIndex < 1 then return nil end
    if not pane.items[rowIndex] then return nil end

    return rowIndex
end

local function getRowAtLocalY(pane, y)
    local rowIndex = getRowIndexAtLocalY(pane, y)
    return rowIndex and pane.items[rowIndex] or nil, rowIndex
end

local function isSeparatorRowAtPointer(pane, sectionRow)
    if not pane or not sectionRow then return false end

    local mouseX = pane:getMouseX()
    if mouseX < 0 or mouseX > pane.column4 then return false end

    local row, rowIndex = getRowAtLocalY(pane, pane:getMouseY())
    return isSeparatorRow(row) and rowIndex == sectionRow + 1
end

local function renderDetailsWithSectionLabels(oldRenderDetails, pane, doDragged)
    local headerText, categoryText, headerItem, sectionStack = findSectionHeaderDrawTargets(pane)
    if not headerText then
        return oldRenderDetails(pane, doDragged)
    end

    local label = getSectionLabels() .. " (" .. tostring(sectionStack._bcEquippedAttachedCount or 0) .. ")"
    local oldDrawText = pane.drawText
    local oldRenderItemIcon = ISInventoryItem.renderItemIcon
    local replacedHeader = false
    local replacedCategory = false
    local renderedHeaderIcon = false

    pane.drawText = function(self, text, x, y, r, g, b, a, font, ...)
        if not replacedHeader and text == headerText and x < self.column3 then
            replacedHeader = true
            text = label
        elseif replacedHeader and not replacedCategory and text == categoryText and x >= self.column3 then
            replacedCategory = true
            text = ""
        end

        return oldDrawText(self, text, x, y, r, g, b, a, font, ...)
    end

    ISInventoryItem.renderItemIcon = function(self, item, ...)
        if not renderedHeaderIcon and item == headerItem then
            renderedHeaderIcon = true
            local args = { ... }
            local x = args[1] or 0
            local y = args[2] or 0
            local alpha = args[3] or 1
            local width = args[4] or pane.itemHgt
            local height = args[5] or width

            local sectionItems = sectionStack and sectionStack._bcEquippedAttachedItems or nil
            local firstItem = sectionItems and sectionItems[1] or item
            local secondItem = sectionItems and sectionItems[2] or nil

            local firstSize = math.min(width, height) * (secondItem and 0.78 or 0.86)
            local firstX = x + ((width - firstSize) / 2) - (secondItem and 2 or 0)
            local firstY = y + ((height - firstSize) / 2) - (secondItem and 2 or 0)
            oldRenderItemIcon(self, firstItem, firstX, firstY, alpha * 0.9, firstSize, firstSize)

            if secondItem then
                local secondSize = math.min(width, height) * 0.58
                local secondX = x + width - secondSize - 1
                local secondY = y + height - secondSize - 1
                oldRenderItemIcon(self, secondItem, secondX, secondY, alpha * 0.85, secondSize, secondSize)
            end
            return
        end

        return oldRenderItemIcon(self, item, ...)
    end

    local sectionRow = getSectionHeaderRow(pane)
    local separatorHovered = not doDragged and sectionRow and isSeparatorRowAtPointer(pane, sectionRow)
    local oldMouseOverOption = pane.mouseOverOption
    if separatorHovered then
        pane.mouseOverOption = 0
    end

    local ok, ret = pcall(oldRenderDetails, pane, doDragged)
    pane.drawText = oldDrawText
    ISInventoryItem.renderItemIcon = oldRenderItemIcon
    pane.mouseOverOption = oldMouseOverOption

    if not ok then error(ret) end

    if separatorHovered then
        local y = (sectionRow * pane.itemHgt) + pane.headerHgt
        pane:drawRect(1, y, pane.column4 - 1, pane.itemHgt, 0.05, 1, 1, 1)
    end

    if not doDragged and sectionRow and sectionRow > 0 then
        local y = (sectionRow * pane.itemHgt) + pane.headerHgt - 1
        local visibleY = y + pane:getYScroll()
        if visibleY >= pane.headerHgt and visibleY <= pane:getHeight() then
            pane:drawRect(1, y, pane.column4, 1, 0.2, 1, 1, 1)
        end
    end

    if not doDragged and sectionRow then
        local size = math.min(15, 8 + getCore():getOptionFontSizeReal() * 2)
        local xPos = math.max(2, (2 + pane.column2 - pane.itemHgt - size) / 2)
        local yPos = (sectionRow * pane.itemHgt) + pane.headerHgt + ((pane.itemHgt - size) / 2)
        local icon = isSectionCollapsed(pane) and pane.treecolicon or pane.treeexpicon
        if icon then
            pane:drawTextureScaled(icon, xPos, yPos, size, size, 1, 1, 1, 0.8)
        end
    end

    return ret
end

local function stripSectionFromSelection(pane)
    if not pane or not pane.selected or not pane.items then return end

    local sectionChildren = nil
    for _, row in ipairs(pane.items) do
        if row and row._bcEquippedAttachedSeparator then
            sectionChildren = {}
            for _, item in ipairs(row._bcEquippedAttachedItems or {}) do
                sectionChildren[item] = true
            end
            break
        end
    end

    if not sectionChildren then return end

    for index, row in pairs(pane.selected) do
        if row and (row._bcEquippedAttachedSeparator or row._bcEquippedAttachedChild or sectionChildren[row]) then
            pane.selected[index] = nil
        end
    end
end

local function getMouseOverRow(pane)
    if not pane or not pane.items or not pane.mouseOverOption then return nil end
    if pane.mouseOverOption == 0 then return nil end
    return pane.items[pane.mouseOverOption]
end

local function toggleSection(pane)
    if not pane then return end

    pane.bcEquippedAttachedCollapsed = not isSectionCollapsed(pane)
    pane.selected = {}
    pane.dragging = nil
    pane.selectedItems = nil
    pane:refreshContainer()
end

function EquippedAttachedSection.install()
    if EquippedAttachedSection._installed then return end
    EquippedAttachedSection._installed = true

    local oldRefreshContainer = ISInventoryPane.refreshContainer
    ISInventoryPane.refreshContainer = function(self, ...)
        oldRefreshContainer(self, ...)
        applySection(self)
        self:updateScrollbars()
    end

    local oldRenderDetails = ISInventoryPane.renderdetails
    ISInventoryPane.renderdetails = function(self, doDragged, ...)
        return renderDetailsWithSectionLabels(oldRenderDetails, self, doDragged, ...)
    end

    local oldUpdate = ISInventoryPane.update
    ISInventoryPane.update = function(self, ...)
        local ret = oldUpdate(self, ...)

        if Options.showEquippedAttachedSection and isCtrlKeyDown() and isKeyDown(Keyboard.KEY_A) then
            stripSectionFromSelection(self)
        end

        return ret
    end

    local oldUpdateTooltip = ISInventoryPane.updateTooltip
    ISInventoryPane.updateTooltip = function(self, ...)
        if Options.showEquippedAttachedSection and isSeparatorRow(getRowAtLocalY(self, self:getMouseY())) then
            if self.toolRender then
                self.toolRender:removeFromUIManager()
                self.toolRender:setVisible(false)
            end
            if self.parent and self.parent.onCharacter then
                Key.setHighlightDoors(self.player, nil)
            end
            return
        end

        return oldUpdateTooltip(self, ...)
    end

    local oldOnMouseDown = ISInventoryPane.onMouseDown
    ISInventoryPane.onMouseDown = function(self, x, y, ...)
        local row = getRowAtLocalY(self, y) or getMouseOverRow(self)
        if Options.showEquippedAttachedSection and isSeparatorRow(row) then
            toggleSection(self)
            return
        end

        return oldOnMouseDown(self, x, y, ...)
    end

    local oldOnRightMouseUp = ISInventoryPane.onRightMouseUp
    ISInventoryPane.onRightMouseUp = function(self, x, y, ...)
        local row = getRowAtLocalY(self, y) or getMouseOverRow(self)
        if Options.showEquippedAttachedSection and isSeparatorRow(row) then
            self.selected = {}
            return true
        end

        return oldOnRightMouseUp(self, x, y, ...)
    end
end

return EquippedAttachedSection
