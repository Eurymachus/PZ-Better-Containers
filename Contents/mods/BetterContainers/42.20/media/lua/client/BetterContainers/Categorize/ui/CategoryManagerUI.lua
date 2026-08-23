require("ISUI/ISCollapsableWindow")
require("ISUI/ISScrollingListBox")
require("ISUI/ISTextEntryBox")
require("ISUI/ISComboBox")
require("ISUI/ISButton")
require("ISUI/ISTextBox")

local Categorize = require("BetterContainers/Categorize")
local Store = require("BetterContainers/Categorize/CategoryStore")

local CategoryManagerUI = ISCollapsableWindow:derive("BetterContainers_CategoryManagerUI")
CategoryManagerUI._instanceByPlayer = {}

local W = 760
local H = 560
local PAD = 10
local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_H = math.max(25, FONT_HGT_SMALL + 6)
local LABEL_W = 110
local RESIZE_BAR_H = 12
local HEADER_H = BUTTON_H
local NAME_COLUMN_RATIO = 0.65

local function text(key, fallback)
    return getTextOrNull(key) or fallback
end

local function scriptItemName(scriptItem, fullType)
    if scriptItem and scriptItem.getDisplayName then
        local ok, name = pcall(function() return scriptItem:getDisplayName() end)
        if ok and name and name ~= "" then return tostring(name) end
    end
    return fullType
end

local function isScriptItemHidden(scriptItem)
    if not (scriptItem and scriptItem.isHidden) then return false end
    local ok, hidden = pcall(function() return scriptItem:isHidden() end)
    return ok and hidden == true
end

function CategoryManagerUI:new(x, y, playerNum)
    local o = ISCollapsableWindow.new(self, x, y, W, H)
    o.playerNum = playerNum or 0
    o.title = text("UI_BetterContainers_CategoryManager_Title", "Category Manager")
    o.resizable = true
    o.minimumWidth = 620
    o.minimumHeight = 420
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.92 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.45 }
    o.allItems = {}
    o.filteredItems = {}
    o.categories = {}
    o.lastSearch = nil
    o.sortColumn = "name"
    o.sortAscending = true
    return o
end

function CategoryManagerUI:_collectItems()
    self.allItems = {}
    local items = getAllItems and getAllItems() or nil
    if not items then return end

    for i = 0, items:size() - 1 do
        local scriptItem = items:get(i)
        if scriptItem and scriptItem.getFullName and not isScriptItemHidden(scriptItem) then
            local fullType = scriptItem:getFullName()
            if fullType and fullType ~= "" then
                local name = scriptItemName(scriptItem, fullType)
                local effectiveCategory = Store.getEffective(fullType)
                local categoryName = effectiveCategory and Store.getCategoryDisplayName(effectiveCategory) or ""
                self.allItems[#self.allItems + 1] = {
                    fullType = fullType,
                    fullTypeSortKey = string.lower(fullType),
                    name = name,
                    nameSortKey = string.lower(name),
                    defaultCategory = Store.getDefault(fullType),
                    effectiveCategory = effectiveCategory,
                    categoryName = categoryName,
                    categorySortKey = string.lower(categoryName),
                    overridden = Store.hasOverride(fullType),
                }
            end
        end
    end
end

function CategoryManagerUI:_refreshCategories(selectID)
    self.categories = Categorize.getAvailableCategories() or {}
    self.categoryCombo:clear()

    local selected = 1
    for i = 1, #self.categories do
        local id = self.categories[i]
        local label = Store.getCategoryDisplayName(id)
        if Store.isCustomCategory(id) then
            label = label .. " *"
        end
        self.categoryCombo:addOptionWithData(label, id)
        if id == selectID then selected = i end
    end
    if #self.categories > 0 then
        self.categoryCombo.selected = selected
    end
end

function CategoryManagerUI:_refreshList(preserveFullType)
    local search = string.lower(self.searchEntry:getText() or "")
    self.filteredItems = {}
    self.itemList:clear()

    local selected = 0
    for i = 1, #self.allItems do
        local entry = self.allItems[i]
        local matches = search == ""
            or string.find(entry.nameSortKey, search, 1, true)
            or string.find(entry.fullTypeSortKey, search, 1, true)
            or string.find(entry.categorySortKey, search, 1, true)
        if matches then
            self.filteredItems[#self.filteredItems + 1] = entry
        end
    end

    local sortColumn = self.sortColumn
    local ascending = self.sortAscending
    table.sort(self.filteredItems, function(a, b)
        local av
        local bv
        if sortColumn == "category" then
            av = a.categorySortKey
            bv = b.categorySortKey
        else
            av = a.nameSortKey
            bv = b.nameSortKey
        end
        if av == bv then
            av = a.nameSortKey
            bv = b.nameSortKey
        end
        if av == bv then
            av = a.fullType
            bv = b.fullType
        end
        if ascending then return av < bv end
        return av > bv
    end)

    for i = 1, #self.filteredItems do
        local entry = self.filteredItems[i]
        self.itemList:addItem(entry.name, entry)
        if entry.fullType == preserveFullType then selected = i end
    end

    if selected > 0 then
        self.itemList.selected = selected
        self.itemList:ensureVisible(selected)
    elseif #self.filteredItems > 0 then
        self.itemList.selected = math.min(self.itemList.selected > 0 and self.itemList.selected or 1, #self.filteredItems)
    end
    self:_syncSelectedItem()
end

function CategoryManagerUI:_updateSortHeaders()
    if not self.nameHeader then return end
    local name = text("UI_BetterContainers_CategoryManager_NameHeader", "Name")
    local category = text("UI_BetterContainers_CategoryManager_CategoryHeader", "Category")
    if self.sortColumn == "name" then
        name = name .. (self.sortAscending and " ^" or " v")
    else
        category = category .. (self.sortAscending and " ^" or " v")
    end
    self.nameHeader:setTitle(name)
    self.categoryHeader:setTitle(category)
end

function CategoryManagerUI:onSort(button, column)
    local selected = self:_selectedEntry()
    if self.sortColumn == column then
        self.sortAscending = not self.sortAscending
    else
        self.sortColumn = column
        self.sortAscending = true
    end
    self:_updateSortHeaders()
    self:_refreshList(selected and selected.fullType)
end

function CategoryManagerUI:_rebuildData(preserveFullType, selectCategoryID)
    self:_collectItems()
    self:_refreshCategories(selectCategoryID)
    self:_refreshList(preserveFullType)
end

function CategoryManagerUI:_selectedEntry()
    local row = self.itemList.items[self.itemList.selected]
    return row and row.item or nil
end

function CategoryManagerUI:_selectedCategoryID()
    if self.categoryCombo.selected <= 0 then return nil end
    return self.categoryCombo:getOptionData(self.categoryCombo.selected)
end

function CategoryManagerUI:_syncSelectedItem()
    local entry = self:_selectedEntry()
    if not entry then
        self.selectionLabel:setName(text("UI_BetterContainers_CategoryManager_NoSelection", "No item selected"))
        self.assignButton:setEnable(false)
        self.resetButton:setEnable(false)
        return
    end

    local effectiveName = entry.effectiveCategory
        and Store.getCategoryDisplayName(entry.effectiveCategory)
        or text("UI_BetterContainers_CategoryManager_Uncategorised", "Uncategorised")
    local suffix = entry.overridden and text("UI_BetterContainers_CategoryManager_OverrideSuffix", " (customized)") or ""
    self.selectionLabel:setName(entry.fullType .. "  |  " .. effectiveName .. suffix)
    self.assignButton:setEnable(true)
    self.resetButton:setEnable(entry.overridden)

    if entry.effectiveCategory then
        for i = 1, #self.categories do
            if self.categories[i] == entry.effectiveCategory then
                self.categoryCombo.selected = i
                break
            end
        end
    end
end

function CategoryManagerUI:onItemSelected()
    self:_syncSelectedItem()
end

function CategoryManagerUI:onAssign()
    local entry = self:_selectedEntry()
    local categoryID = self:_selectedCategoryID()
    if not (entry and categoryID) then return end

    Store.setOverride(entry.fullType, categoryID)
    Categorize.applySingleCategoryChange(entry.fullType, false)
    self:_rebuildData(entry.fullType, categoryID)
end

function CategoryManagerUI:onReset()
    local entry = self:_selectedEntry()
    if not entry then return end

    Store.resetOverride(entry.fullType)
    Categorize.applySingleCategoryChange(entry.fullType, false)
    self:_rebuildData(entry.fullType, Store.getDefault(entry.fullType))
end

function CategoryManagerUI:onCreateCategoryResult(button)
    if not button or button.internal ~= "OK" then return end
    local displayName = button.parent and button.parent.entry and button.parent.entry:getText() or ""
    local categoryID = Store.createCustomCategory(displayName)
    if not categoryID then return end
    Store.injectCustomTranslations()
    self:_refreshCategories(categoryID)
end

function CategoryManagerUI:onCreateCategory()
    local modal = ISTextBox:new(0, 0, 360, 180,
        text("UI_BetterContainers_CategoryManager_NewPrompt", "New category name"),
        "", self, CategoryManagerUI.onCreateCategoryResult)
    modal:initialise()
    modal.noEmpty = true
    modal:addToUIManager()
end

function CategoryManagerUI:onRenameCategoryResult(button, categoryID)
    if not button or button.internal ~= "OK" then return end
    local displayName = button.parent and button.parent.entry and button.parent.entry:getText() or ""
    if Store.renameCustomCategory(categoryID, displayName) then
        Store.injectCustomTranslations()
        self:_rebuildData(self:_selectedEntry() and self:_selectedEntry().fullType, categoryID)
    end
end

function CategoryManagerUI:onRenameCategory()
    local categoryID = self:_selectedCategoryID()
    if not Store.isCustomCategory(categoryID) then return end
    local modal = ISTextBox:new(0, 0, 360, 180,
        text("UI_BetterContainers_CategoryManager_RenamePrompt", "Rename custom category"),
        Store.getCustomDisplayName(categoryID) or "", self,
        CategoryManagerUI.onRenameCategoryResult, nil, categoryID)
    modal:initialise()
    modal.noEmpty = true
    modal:addToUIManager()
end

function CategoryManagerUI:onDeleteCategory()
    local categoryID = self:_selectedCategoryID()
    if not Store.isCustomCategory(categoryID) then return end
    local selected = self:_selectedEntry()
    Store.deleteCustomCategory(categoryID)
    Categorize.applyCategoryChanges(false)
    self:_rebuildData(selected and selected.fullType, nil)
end

function CategoryManagerUI:doDrawItem(y, row, alt)
    local entry = row.item
    local h = self.itemList.itemheight
    if y + self.itemList:getYScroll() + h < 0 or y + self.itemList:getYScroll() >= self.itemList.height then
        return y + h
    end

    local width = self.itemList:getWidth()
    if self.itemList.selected == row.itemindex then
        self.itemList:drawRect(0, y, width, h, 0.60, 0.70, 0.35, 0.15)
    elseif alt then
        self.itemList:drawRect(0, y, width, h, 0.05, 1, 1, 1)
    end

    self.itemList:drawRectBorder(0, y, width - 1, h, 0.25, 1, 1, 1)

    local marker = entry.overridden and "* " or "  "
    local textY = y + (h - FONT_HGT_SMALL) / 2
    self.itemList:drawText(marker .. entry.name, 8, textY, 1, 1, 1, 0.95, UIFont.Small)
    local categoryName = entry.categoryName
    local categoryWidth = getTextManager():MeasureStringX(UIFont.Small, categoryName)
    local right = self.itemList.width - ((self.itemList.vscroll and self.itemList.vscroll.width) or 0) - 8
    self.itemList:drawText(categoryName, right - categoryWidth, textY, 0.75, 0.85, 1, 0.9, UIFont.Small)
    return y + h
end

function CategoryManagerUI:_getLayout()
    local contentTop = self:titleBarHeight() + PAD
    local searchX = PAD + LABEL_W
    local closeY = self.height - PAD - BUTTON_H - RESIZE_BAR_H
    local actionsY = closeY - PAD - BUTTON_H
    local comboY = actionsY - PAD - BUTTON_H
    local selectionY = comboY - BUTTON_H
    local headerY = contentTop + BUTTON_H + PAD
    local listY = headerY + HEADER_H
    local listH = selectionY - PAD - listY
    return {
        contentTop = contentTop,
        searchX = searchX,
        headerY = headerY,
        listY = listY,
        listH = math.max(FONT_HGT_SMALL + 10, listH),
        selectionY = selectionY,
        comboY = comboY,
        actionsY = actionsY,
        closeY = closeY,
    }
end

function CategoryManagerUI:createChildren()
    ISCollapsableWindow.createChildren(self)
    local layout = self:_getLayout()

    self.searchEntry = ISTextEntryBox:new("", layout.searchX, layout.contentTop,
        self.width - layout.searchX - PAD, BUTTON_H)
    self.searchEntry:initialise()
    self.searchEntry:instantiate()
    self.searchEntry:setClearButton(true)
    self:addChild(self.searchEntry)

    local headerWidth = self.width - PAD * 2
    local nameHeaderWidth = math.floor(headerWidth * NAME_COLUMN_RATIO)
    self.nameHeader = ISButton:new(PAD, layout.headerY, nameHeaderWidth, HEADER_H, "", self,
        CategoryManagerUI.onSort)
    self.nameHeader:initialise()
    self.nameHeader.onClickArgs[1] = "name"
    self:addChild(self.nameHeader)

    self.categoryHeader = ISButton:new(self.nameHeader:getRight(), layout.headerY,
        headerWidth - nameHeaderWidth, HEADER_H, "", self, CategoryManagerUI.onSort)
    self.categoryHeader:initialise()
    self.categoryHeader.onClickArgs[1] = "category"
    self:addChild(self.categoryHeader)
    self:_updateSortHeaders()

    self.itemList = ISScrollingListBox:new(PAD, layout.listY, self.width - PAD * 2, layout.listH)
    self.itemList:initialise()
    self.itemList:instantiate()
    self.itemList.itemheight = FONT_HGT_SMALL + 10
    self.itemList.backgroundColor = { r = 0, g = 0, b = 0, a = 0.65 }
    self.itemList.doDrawItem = function(list, y, row, alt) return self:doDrawItem(y, row, alt) end
    self.itemList:setOnMouseDownFunction(self, CategoryManagerUI.onItemSelected)
    self:addChild(self.itemList)

    self.selectionLabel = ISLabel:new(layout.searchX, layout.selectionY, BUTTON_H, "", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.selectionLabel)

    self.categoryCombo = ISComboBox:new(layout.searchX, layout.comboY,
        self.width - layout.searchX - PAD - 210, BUTTON_H, self, nil)
    self.categoryCombo:initialise()
    self:addChild(self.categoryCombo)

    self.assignButton = ISButton:new(self.categoryCombo:getRight() + PAD, layout.comboY, 95, BUTTON_H,
        text("UI_BetterContainers_CategoryManager_Assign", "Assign"), self, CategoryManagerUI.onAssign)
    self.assignButton:initialise()
    self:addChild(self.assignButton)

    self.resetButton = ISButton:new(self.assignButton:getRight() + PAD, layout.comboY, 95, BUTTON_H,
        text("UI_BetterContainers_CategoryManager_Reset", "Reset"), self, CategoryManagerUI.onReset)
    self.resetButton:initialise()
    self:addChild(self.resetButton)

    local actionW = math.floor((self.width - PAD * 4) / 3)
    self.newButton = ISButton:new(PAD, layout.actionsY, actionW, BUTTON_H,
        text("UI_BetterContainers_CategoryManager_New", "New Category"), self, CategoryManagerUI.onCreateCategory)
    self.newButton:initialise()
    self:addChild(self.newButton)

    self.renameButton = ISButton:new(self.newButton:getRight() + PAD, layout.actionsY, actionW, BUTTON_H,
        text("UI_BetterContainers_CategoryManager_Rename", "Rename Category"), self, CategoryManagerUI.onRenameCategory)
    self.renameButton:initialise()
    self:addChild(self.renameButton)

    self.deleteButton = ISButton:new(self.renameButton:getRight() + PAD, layout.actionsY, actionW, BUTTON_H,
        text("UI_BetterContainers_CategoryManager_Delete", "Delete Category"), self, CategoryManagerUI.onDeleteCategory)
    self.deleteButton:initialise()
    self:addChild(self.deleteButton)

    self.doneButton = ISButton:new(PAD, layout.closeY, self.width - PAD * 2, BUTTON_H,
        text("UI_Close", "Close"), self, CategoryManagerUI.close)
    self.doneButton:initialise()
    self:addChild(self.doneButton)

    self:_rebuildData(self.initialFullType, nil)
end

function CategoryManagerUI:render()
    ISCollapsableWindow.render(self)
    local layout = self:_getLayout()
    local labelY = function(y) return y + (BUTTON_H - FONT_HGT_SMALL) / 2 end

    self:drawText(text("UI_BetterContainers_CategoryManager_Search", "Search Item"),
        PAD, labelY(layout.contentTop), 1, 1, 1, 1, UIFont.Small)
    self:drawText(text("UI_BetterContainers_CategoryManager_Selected", "Selected Item"),
        PAD, labelY(layout.selectionY), 1, 1, 1, 1, UIFont.Small)
    self:drawText(text("UI_BetterContainers_CategoryManager_Category", "Category"),
        PAD, labelY(layout.comboY), 1, 1, 1, 1, UIFont.Small)

    self:drawRectBorder(PAD, layout.listY, self.width - PAD * 2, layout.listH, 0.50, 1, 1, 1)
end

function CategoryManagerUI:update()
    ISCollapsableWindow.update(self)
    local search = self.searchEntry and self.searchEntry:getText() or ""
    if search ~= self.lastSearch then
        self.lastSearch = search
        self:_refreshList(self:_selectedEntry() and self:_selectedEntry().fullType)
    end

    local categoryID = self:_selectedCategoryID()
    local custom = categoryID and Store.isCustomCategory(categoryID)
    if self.renameButton then self.renameButton:setEnable(custom == true) end
    if self.deleteButton then self.deleteButton:setEnable(custom == true) end
end

function CategoryManagerUI:onResize()
    ISCollapsableWindow.onResize(self)
    if not self.searchEntry then return end
    local layout = self:_getLayout()
    self.searchEntry:setX(layout.searchX)
    self.searchEntry:setY(layout.contentTop)
    self.searchEntry:setWidth(self.width - layout.searchX - PAD)
    local headerWidth = self.width - PAD * 2
    local nameHeaderWidth = math.floor(headerWidth * NAME_COLUMN_RATIO)
    self.nameHeader:setX(PAD)
    self.nameHeader:setY(layout.headerY)
    self.nameHeader:setWidth(nameHeaderWidth)
    self.categoryHeader:setX(self.nameHeader:getRight())
    self.categoryHeader:setY(layout.headerY)
    self.categoryHeader:setWidth(headerWidth - nameHeaderWidth)
    self.itemList:setY(layout.listY)
    self.itemList:setWidth(self.width - PAD * 2)
    self.itemList:setHeight(layout.listH)
    self.selectionLabel:setX(layout.searchX)
    self.selectionLabel:setY(layout.selectionY)
    self.categoryCombo:setX(layout.searchX)
    self.categoryCombo:setY(layout.comboY)
    self.categoryCombo:setWidth(self.width - layout.searchX - PAD - 210)
    self.assignButton:setX(self.categoryCombo:getRight() + PAD)
    self.assignButton:setY(layout.comboY)
    self.resetButton:setX(self.assignButton:getRight() + PAD)
    self.resetButton:setY(layout.comboY)
    local actionW = math.floor((self.width - PAD * 4) / 3)
    self.newButton:setX(PAD)
    self.newButton:setY(layout.actionsY)
    self.newButton:setWidth(actionW)
    self.renameButton:setX(self.newButton:getRight() + PAD)
    self.renameButton:setY(layout.actionsY)
    self.renameButton:setWidth(actionW)
    self.deleteButton:setX(self.renameButton:getRight() + PAD)
    self.deleteButton:setY(layout.actionsY)
    self.deleteButton:setWidth(actionW)
    self.doneButton:setX(PAD)
    self.doneButton:setY(layout.closeY)
    self.doneButton:setWidth(self.width - PAD * 2)
end

function CategoryManagerUI:close()
    Store.flush()
    self:setVisible(false)
    self:removeFromUIManager()
    CategoryManagerUI._instanceByPlayer[self.playerNum] = nil
end

function CategoryManagerUI.open(playerNum, fullType)
    local pn = playerNum or 0
    local existing = CategoryManagerUI._instanceByPlayer[pn]
    if existing and existing.javaObject then
        if fullType then
            existing.searchEntry:setText("")
            existing.lastSearch = ""
            existing:_refreshList(fullType)
        end
        existing:addToUIManager()
        existing:bringToTop()
        return existing
    end

    local x = math.floor((getCore():getScreenWidth() - W) / 2)
    local y = math.floor((getCore():getScreenHeight() - H) / 2)
    local ui = CategoryManagerUI:new(x, y, pn)
    ui.initialFullType = fullType
    ui:initialise()
    ui:addToUIManager()
    CategoryManagerUI._instanceByPlayer[pn] = ui
    return ui
end

return CategoryManagerUI
