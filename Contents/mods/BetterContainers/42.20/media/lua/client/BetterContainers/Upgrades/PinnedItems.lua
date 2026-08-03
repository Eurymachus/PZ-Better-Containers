local PinnedItems = {}

local Helpers = require("BetterContainers/Helpers")
local IniWriter = require("BetterContainers/_IO/IniWriter")
local Options = require("BetterContainers/_Options")

local function dlog(msg)
    Helpers.dlog("PinnedItems " .. tostring(msg))
end

local FEATURE = IniWriter.makeFeature("FavouritedItems", false)
local SECTION = "Favourites"
local PIN_MARKER_TEXTURE = "media/ui/BetterContainers/PinnedItemMarker.png"
local UNPIN_MARKER_TEXTURE = "media/ui/BetterContainers/UnpinnedItemMarker.png"
local PIN_MARKER_DISPLAY_SIZE = 11

-- fullType -> true
PinnedItems.FavouritedItems = PinnedItems.FavouritedItems or {}

local _dirty = false
local _loaded = false

local function _getFullTypeFromContextItems(items)
    if type(items) ~= "table" then return nil end

    -- items can be:
    -- 1) { InventoryItem, InventoryItem, ... }
    -- 2) { { items = {InventoryItem,...} }, ... } (stack entries)
    local first = items[1]
    if type(first) == "table" and first.items and first.items[1] then
        first = first.items[1]
    end

    if first and first.getFullType then
        return first:getFullType()
    end
    return nil
end

local function _sortedKeys(t)
    local keys = {}
    for k, v in pairs(t) do
        if v then
            keys[#keys + 1] = k
        end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function _refreshInventoryPanes()
    if not (getNumActivePlayers and getPlayerInventory and getPlayerLoot) then return end

    for playerNum = 0, getNumActivePlayers() - 1 do
        local inventoryPage = getPlayerInventory(playerNum)
        if inventoryPage and inventoryPage.inventoryPane then
            inventoryPage.inventoryPane:refreshContainer()
        end

        local lootPage = getPlayerLoot(playerNum)
        if lootPage and lootPage.inventoryPane then
            lootPage.inventoryPane:refreshContainer()
        end
    end

    if ISInventoryPage then
        ISInventoryPage.renderDirty = true
        if ISInventoryPage.dirtyUI then
            ISInventoryPage.dirtyUI()
        end
    end
end

PinnedItems.isLoaded = function()
    return _loaded
end

PinnedItems.isDirty = function()
    return _dirty
end

PinnedItems.isFavourite = function(fullType)
    if not fullType then return false end
    return PinnedItems.FavouritedItems[fullType] == true
end

PinnedItems.setFavourite = function(fullType, isFav)
    if not fullType or fullType == "" then return false end

    local cur = PinnedItems.FavouritedItems[fullType] == true
    isFav = isFav == true

    if cur == isFav then
        return false
    end

    if isFav then
        PinnedItems.FavouritedItems[fullType] = true
        dlog("favourite add " .. tostring(fullType))
    else
        PinnedItems.FavouritedItems[fullType] = nil
        dlog("favourite remove " .. tostring(fullType))
    end

    _dirty = true

    _refreshInventoryPanes()

    return true
end

PinnedItems.toggleFavourite = function(fullType)
    return PinnedItems.setFavourite(fullType, not PinnedItems.isFavourite(fullType))
end

PinnedItems.load = function()
    if _loaded then return true end

    local row = FEATURE.get(SECTION) or {}
    PinnedItems.FavouritedItems = {}

    for k, v in pairs(row) do
        if v ~= nil and tostring(v) ~= "0" and tostring(v) ~= "false" then
            PinnedItems.FavouritedItems[tostring(k)] = true
        end
    end

    _dirty = false
    _loaded = true

    dlog("loaded " .. tostring(#_sortedKeys(PinnedItems.FavouritedItems)) .. " favourites")
    return true
end

PinnedItems.saveIfDirty = function()
    if not _dirty then return false end

    local outRow = {}
    for fullType, _ in pairs(PinnedItems.FavouritedItems) do
        outRow[fullType] = "1"
    end

    local order = _sortedKeys(PinnedItems.FavouritedItems)

    -- If empty, delete the section to keep file tidy.
    if #order == 0 then
        FEATURE.delete(SECTION)
    else
        FEATURE.setOrdered(SECTION, outRow, order)
    end

    _dirty = false
    dlog("saved favourites")
    return true
end

PinnedItems.onFillInventoryContext = function(player, context, items, test)
    if test then return end
    if not _loaded then
        PinnedItems.load()
    end

    local fullType = _getFullTypeFromContextItems(items)
    if not fullType then return end

    local isFav = PinnedItems.isFavourite(fullType)
    local label = isFav and (getTextOrNull("ContextMenu_BetterContainers_UnpinItemType") or "Unpin Item Type")
                        or (getTextOrNull("ContextMenu_BetterContainers_PinItemType") or "Pin Item Type")

    local option = context:addOption(label, nil, function()
        PinnedItems.setFavourite(fullType, not isFav)
    end)
    if option then
        option.iconTexture = getTexture(isFav and UNPIN_MARKER_TEXTURE or PIN_MARKER_TEXTURE)
    end
end

PinnedItems.onSave = function()
    PinnedItems.saveIfDirty()
end

PinnedItems.displayPinnedItem = function(inventoryPage)
    if not inventoryPage then return false end

    local onCharacter = inventoryPage.onCharacter
    local displayRule = Options.showFavouritesOnPlayerInventories

    return (onCharacter == true and displayRule == true)
        or (onCharacter == false)
end

PinnedItems.installInventoryPaneSortPatch = function()
    if PinnedItems._panePatched then return end
    PinnedItems._panePatched = true

    require("ISUI/ISInventoryPane")

    local _origRefreshContainer = ISInventoryPane.refreshContainer

    local function _isRowFav(v)
        local it = v and v.items and v.items[1]
        if not (it and it.getFullType) then return false end
        return PinnedItems.isFavourite(it:getFullType())
    end

    ISInventoryPane.refreshContainer = function(self, ...)
        local baseSortFunc = self.itemSortFunc

        if baseSortFunc and PinnedItems.displayPinnedItem(self.inventoryPage) then
            self.itemSortFunc = function(a, b)
                local aFav = _isRowFav(a)
                local bFav = _isRowFav(b)
                if aFav ~= bFav then
                    return aFav
                end

                return baseSortFunc(a, b)
            end
        end

        _origRefreshContainer(self, ...)
        self.itemSortFunc = baseSortFunc
    end

    dlog("installed ISInventoryPane pinned item sort overlay")

    PinnedItems._origRefreshContainer = _origRefreshContainer
end

PinnedItems.installInventoryPaneVisualPatch = function()
    if PinnedItems._paneVisualPatched then return end
    PinnedItems._paneVisualPatched = true

    require("ISUI/ISInventoryPane")

    local _origRenderDetails = ISInventoryPane.renderdetails
    if not _origRenderDetails then
        dlog("ISInventoryPane.renderdetails missing")
        return
    end

    local function _rowIsFav(v)
        local it = v and v.items and v.items[1]
        if not (it and it.getFullType) then return false end
        return PinnedItems.isFavourite(it:getFullType())
    end

    ISInventoryPane.renderdetails = function(self, doDragged)
        _origRenderDetails(self, doDragged)

        if not PinnedItems.displayPinnedItem(self.inventoryPage) then
            return
        end

        -- Vanilla: don't draw category while dragging; follow suit.
        if doDragged then return end

        if not (self and self.itemslist) then return end

        local tex = getTexture(PIN_MARKER_TEXTURE)
        if not tex then return end

        local iconSize = math.min(PIN_MARKER_DISPLAY_SIZE, self.itemHgt)
        if iconSize < 8 then return end

        local itemIconSize = math.min(self.itemHgt - 2, 32)
        local texX = self.column2 - itemIconSize - ((self.itemHgt - itemIconSize) / 2) + 1

        local y = 0
        for _, v in ipairs(self.itemslist) do
            if _rowIsFav(v) then
                local isDraggingRow = self.dragging ~= nil and self.dragStarted
                    and self.selected and (self.selected[y+1] ~= nil)

                if not isDraggingRow then
                    local texY = (y * self.itemHgt) + self.headerHgt
                    self:drawTextureScaled(tex, texX, texY, iconSize, iconSize, 1, 1, 1, 1)
                end
            end

            -- Advance y by the number of rendered rows for this stack.
            local rows = 1
            if v and v.items then
                if self.collapsed and v.name and self.collapsed[v.name] then
                    rows = 1
                else
                    -- Mirrors vanilla stack render cap.
                    rows = math.min(#v.items, ISInventoryPane.MAX_ITEMS_IN_STACK_TO_RENDER + 1)
                    if rows < 1 then rows = 1 end
                end
            end
            y = y + rows
        end
    end

    dlog("installed ISInventoryPane favourites visual marker (category icon)")
end

PinnedItems.install = function()
    if not PinnedItems._installed then
        PinnedItems._installed = true
        -- Install
        Events.OnGameBoot.Add(PinnedItems.load)
        Events.OnGameBoot.Add(PinnedItems.installInventoryPaneSortPatch)
        Events.OnGameBoot.Add(PinnedItems.installInventoryPaneVisualPatch)

        Events.OnFillInventoryObjectContextMenu.Add(PinnedItems.onFillInventoryContext)
        Events.OnSave.Add(PinnedItems.onSave)
    end
end

return PinnedItems
