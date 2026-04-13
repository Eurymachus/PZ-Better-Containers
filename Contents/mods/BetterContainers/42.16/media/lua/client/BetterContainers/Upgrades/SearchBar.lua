require "ISUI/ISPanel"
require "ISUI/ISTextEntryBox"

local Helpers = require("BetterContainers/Helpers")
local Options = require("BetterContainers/_Options")

local SearchBar = {}

local _installed = false


local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local SEARCH_H = FONT_HGT_SMALL + 8
local SEARCH_GAP = 1
local SEARCH_PAD_X = 0
local SEARCH_PAD_Y = 2

local ENTRY_LEFT_PAD = 3
local ENTRY_RIGHT_PAD = 0

local function _removeSearchWidgets(pane)
    if not pane then
        return
    end

    if pane.bcSearchEntry then
        if pane.bcSearchStrip and pane.bcSearchStrip.removeChild then
            pane.bcSearchStrip:removeChild(pane.bcSearchEntry)
        end
        if pane.bcSearchEntry.removeFromUIManager then
            pane.bcSearchEntry:removeFromUIManager()
        end
        pane.bcSearchEntry = nil
    end

    if pane.bcSearchStrip then
        if pane.removeChild then
            pane:removeChild(pane.bcSearchStrip)
        end
        if pane.bcSearchStrip.removeFromUIManager then
            pane.bcSearchStrip:removeFromUIManager()
        end
        pane.bcSearchStrip = nil
    end

    pane.bcSearchQuery = nil

    if pane._bcSearchApplied then
        local base = pane._bcBaseHeaderHgt or pane.headerHgt or 0
        pane.headerHgt = base

        local y = 0
        if pane.expandAll then pane.expandAll:setY(y) end
        if pane.collapseAll then pane.collapseAll:setY(y) end
        if pane.filterMenu then pane.filterMenu:setY(y) end
        if pane.nameHeader then pane.nameHeader:setY(y) end
        if pane.typeHeader then pane.typeHeader:setY(y) end

        pane._bcSearchApplied = false
    end
end

local function _ensureSearchWidgets(pane)
    if not pane then
        return
    end

    if not pane.bcSearchStrip then
        local strip = ISPanel:new(0, 0, 10, 10)
        strip:initialise()
        strip:instantiate()
        strip.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
        strip.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 0 }
        pane:addChild(strip)
        pane.bcSearchStrip = strip
    end

    if not pane.bcSearchEntry then
        local entry = ISTextEntryBox:new("", 0, 0, 10, 10)
        entry:initialise()
        entry:instantiate()
        entry:setHasFrame(false)
        entry:setClearButton(true)
        entry:setOnlyNumbers(false)
        entry:setMultipleLine(false)
        entry:setMaxTextLength(256)
        entry.backgroundColor = { r = 0.0, g = 0.0, b = 0.0, a = 0 }
        entry.borderColor = { r = 0.0, g = 0.0, b = 0.0, a = 0 }
        entry.onTextChange = function(selfEntry)
            pane.bcSearchQuery = selfEntry:getInternalText() or ""
            pane.inventory:setDrawDirty(true)
            pane:refreshContainer()
        end
        pane.bcSearchStrip:addChild(entry)
        pane.bcSearchEntry = entry
        pane.bcSearchQuery = pane.bcSearchQuery or ""
    end
end

local function _layoutSearchBar(pane)
    if not pane then
        return
    end

    if not Options or not Options.enableSearchBar then
        _removeSearchWidgets(pane)
        return
    end

    _ensureSearchWidgets(pane)

    local strip = pane.bcSearchStrip
    local entry = pane.bcSearchEntry
    if not (strip and entry) then
        return
    end

    if not pane._bcBaseHeaderHgt then
        pane._bcBaseHeaderHgt = pane.headerHgt or 0
    end

    local baseHeaderHgt = pane._bcBaseHeaderHgt
    pane.headerHgt = baseHeaderHgt + SEARCH_H + SEARCH_GAP
    pane._bcSearchApplied = true

    local scrollbarWidth = (pane.vscroll and pane.vscroll:isVisible()) and pane.vscroll.width or 0

    strip:setX(1)
    strip:setY(0)
    strip:setWidth(pane:getWidth() - scrollbarWidth - 2)
    strip:setHeight(SEARCH_H)

    entry:setX(ENTRY_LEFT_PAD)
    entry:setY(SEARCH_PAD_Y)
    entry:setWidth(strip:getWidth() - ENTRY_LEFT_PAD - ENTRY_RIGHT_PAD)
    entry:setHeight(SEARCH_H - (SEARCH_PAD_Y * 2))

    if entry.setPlaceholderText then
        entry:setPlaceholderText(getTextOrNull("UI_BetterContainers_Search_placeholder") or "Search...")
    end

    local headerY = SEARCH_H + SEARCH_GAP
    if pane.expandAll then pane.expandAll:setY(headerY) end
    if pane.collapseAll then pane.collapseAll:setY(headerY) end
    if pane.filterMenu then pane.filterMenu:setY(headerY) end
    if pane.nameHeader then pane.nameHeader:setY(headerY) end
    if pane.typeHeader then pane.typeHeader:setY(headerY) end
end

local function _normalizeSearch(text)
    if not text then
        return ""
    end

    local s = string.lower(tostring(text))

    -- Treat separators/punctuation as spaces.
    s = string.gsub(s, "[_%-%./\\%(%),:;'%[%]{}]+", " ")

    -- Collapse whitespace.
    s = string.gsub(s, "%s+", " ")

    -- Trim ends.
    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")

    return s
end

local function _splitTokens(text)
    local tokens = {}
    if text == "" then
        return tokens
    end

    for token in string.gmatch(text, "%S+") do
        tokens[#tokens + 1] = token
    end

    return tokens
end

local function _startsWith(haystack, needle)
    return string.sub(haystack, 1, string.len(needle)) == needle
end

local function _tokenPrefixMatch(candidate, query)
    if query == "" then
        return true
    end

    if candidate == "" then
        return false
    end

    -- Fast path: normal substring still works.
    if string.contains(candidate, query) then
        return true
    end

    local candidateTokens = _splitTokens(candidate)
    local queryTokens = _splitTokens(query)

    if #queryTokens == 0 then
        return true
    end

    for i = 1, #queryTokens do
        local q = queryTokens[i]
        local matched = false

        for j = 1, #candidateTokens do
            if _startsWith(candidateTokens[j], q) then
                matched = true
                break
            end
        end

        if not matched then
            return false
        end
    end

    return true
end

local function _stackMatchesQuery(pane, stack, query)
    if not stack or not stack.items or not stack.items[1] then
        return false
    end

    if query == "" then
        return true
    end

    local playerObj = getSpecificPlayer(pane.player)
    local item = stack.items[1]

    local name = _normalizeSearch(item:getName(playerObj))
    local rawCat = _normalizeSearch(stack.cat or item:getDisplayCategory() or item:getCategory())

    local catKey = item:getDisplayCategory() or item:getCategory()
    local locCat = catKey and getTextOrNull("IGUI_ItemCat_" .. catKey) or nil
    locCat = _normalizeSearch(locCat or catKey)

    return _tokenPrefixMatch(name, query)
        or _tokenPrefixMatch(rawCat, query)
        or _tokenPrefixMatch(locCat, query)
end

local function _applySearchFilter(pane)
    if not pane or not pane.itemslist then
        return
    end

    local query = _normalizeSearch(pane.bcSearchQuery)
    if query == "" then
        return
    end

    local filtered = {}
    for i = 1, #pane.itemslist do
        local stack = pane.itemslist[i]
        if _stackMatchesQuery(pane, stack, query) then
            filtered[#filtered + 1] = stack
        end
    end

    pane.itemslist = filtered
    pane:updateScrollbars()
    pane.inventory:setDrawDirty(false)
end

local function _applyToExistingPanes()
    for playerNum = 0, getNumActivePlayers() - 1 do
        local invPage = getPlayerInventory(playerNum)
        if invPage and invPage.inventoryPane then
            Helpers.dlog("Applying SearchBar to existing player pane")
            _layoutSearchBar(invPage.inventoryPane)
        end

        local lootPage = getPlayerLoot(playerNum)
        if lootPage and lootPage.inventoryPane then
            Helpers.dlog("Applying SearchBar to existing loot pane")
            _layoutSearchBar(lootPage.inventoryPane)
        end
    end
end

SearchBar.install = function()
    Helpers.dlog("SearchBar.install entered.")
    require "ISUI/ISInventoryPane"
    require "ISUI/ISInventoryPage"

    if Helpers.isCleanUIActive() then
        Helpers.dlog("Clean UI active - SearchBar install skipped.")
        return
    end

    if not ISInventoryPane._BetterContainers_SearchBar_installed then
        local _old_createChildren = ISInventoryPane.createChildren
        ISInventoryPane.createChildren = function(self)
            _old_createChildren(self)
            _layoutSearchBar(self)
        end

        local _old_refreshContainer = ISInventoryPane.refreshContainer
        ISInventoryPane.refreshContainer = function(self)
            _old_refreshContainer(self)
            _applySearchFilter(self)
        end

        local _old_onResize = ISInventoryPane.onResize
        ISInventoryPane.onResize = function(self)
            _old_onResize(self)
            _layoutSearchBar(self)
        end

        ISInventoryPane._BetterContainers_SearchBar_installed = true

        Events[Helpers.OPTIONS_APPLIED].Add(_applyToExistingPanes)
    end

    Helpers.dlog("SearchBar pane wrappers installed.")
end

return SearchBar