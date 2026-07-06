require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryItem"

local Options = require("BetterContainers/_Options")

local EquippedAttachedSection = {}

local SECTION_KEY = "BetterContainers:EquippedAttachedSection"

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

local function buildSectionStack(pane, sectionItems)
    local items = {}
    local weight = 0

    for _, item in ipairs(sectionItems) do
        if item then
            items[#items + 1] = item
            weight = weight + item:getUnequippedWeight()
        end
    end

    if #items == 0 then return nil end

    table.insert(items, 1, items[1])

    local name = SECTION_KEY
    if pane.collapsed[name] == nil then
        pane.collapsed[name] = false
    end

    return {
        _bcEquippedAttachedSection = true,
        invPanel = pane,
        name = name,
        cat = SECTION_KEY,
        count = #items,
        weight = weight,
        equipped = true,
        inHotbar = true,
        items = items,
    }
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

    local sectionStack = buildSectionStack(pane, sectionItems)
    if not sectionStack then return end

    pane.itemslist[#pane.itemslist + 1] = sectionStack
end

local function getSectionLabels()
    return getTextOrNull("UI_BetterContainers_EquippedAttachedSection") or "Equipped / Attached",
        getTextOrNull("UI_BetterContainers_EquippedAttachedSection_Category") or "Gear"
end

local function getHeaderDisplayName(stack, playerObj)
    if not stack or not stack.items or not stack.items[1] then return nil end

    local item = stack.items[1]
    local name = item:getName(playerObj)
    local realCount = (stack.count or #stack.items) - 1

    if realCount > 1 then
        return name .. " (" .. realCount .. ")"
    end

    return name
end

local function findSectionHeaderDrawTargets(pane)
    if not pane or not pane.itemslist then return nil, nil, nil, nil end

    local playerObj = getSpecificPlayer(pane.player)
    for _, stack in ipairs(pane.itemslist) do
        if stack and stack._bcEquippedAttachedSection then
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
        if stack and stack._bcEquippedAttachedSection then
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

local function renderDetailsWithSectionLabels(oldRenderDetails, pane, doDragged)
    local headerText, categoryText, headerItem, sectionStack = findSectionHeaderDrawTargets(pane)
    if not headerText then
        return oldRenderDetails(pane, doDragged)
    end

    local label, category = getSectionLabels()
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
            text = category
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

            local firstItem = sectionStack and sectionStack.items and sectionStack.items[2] or item
            local secondItem = sectionStack and sectionStack.items and sectionStack.items[3] or nil

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
    local ok, ret = pcall(oldRenderDetails, pane, doDragged)
    pane.drawText = oldDrawText
    ISInventoryItem.renderItemIcon = oldRenderItemIcon

    if not ok then error(ret) end

    if not doDragged and sectionRow and sectionRow > 0 then
        local y = (sectionRow * pane.itemHgt) + pane.headerHgt - 1
        local visibleY = y + pane:getYScroll()
        if visibleY >= pane.headerHgt and visibleY <= pane:getHeight() then
            pane:drawRect(1, y, pane.column4, 1, 0.2, 1, 1, 1)
        end
    end

    return ret
end

local function stripSectionFromSelection(pane)
    if not pane or not pane.selected or not pane.items then return end

    local sectionChildren = nil
    for _, row in ipairs(pane.items) do
        if row and row._bcEquippedAttachedSection then
            sectionChildren = {}
            for i = 2, #row.items do
                sectionChildren[row.items[i]] = true
            end
            break
        end
    end

    if not sectionChildren then return end

    for index, row in pairs(pane.selected) do
        if row and (row._bcEquippedAttachedSection or sectionChildren[row]) then
            pane.selected[index] = nil
        end
    end
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
end

return EquippedAttachedSection
