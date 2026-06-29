local PinnedItems = {}

local Helpers = require("BetterContainers/Helpers")
local IniWriter = require("BetterContainers/_IO/IniWriter")
local Options = require("BetterContainers/_Options")

local function dlog(msg)
    Helpers.dlog("PinnedItems " .. tostring(msg))
end

local FEATURE = IniWriter.makeFeature("FavouritedItems", false)
local SECTION = "Favourites"

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

    -- Light-touch UI hint (safe even if panes don't use it yet).
    ISInventoryPage.renderDirty = true

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

    context:addOption(label, nil, function()
        PinnedItems.setFavourite(fullType, not isFav)
    end)
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

PinnedItems.installInventoryPanePatch = function()
    if PinnedItems._panePatched then return end
    PinnedItems._panePatched = true

    require("ISUI/ISInventoryPane")

    local _origSortByType     = ISInventoryPane.sortByType
    local _origSaveLayout     = ISInventoryPane.SaveLayout
    local _origRestoreLayout  = ISInventoryPane.RestoreLayout

    -- Vanilla comparators (static a,b; no self)
    local _origCatInc  = ISInventoryPane.itemSortByCatInc
    local _origCatDesc = ISInventoryPane.itemSortByCatDesc

    local function _isRowFav(v)
        local it = v and v.items and v.items[1]
        if not (it and it.getFullType) then return false end
        return PinnedItems.isFavourite(it:getFullType())
    end

    local function _ensureFavComparators(pane)
        if not pane then return end
        if pane._cfCatInc and pane._cfCatDesc then return end

        -- Per-pane wrappers so we can see pane.inventoryPage / onCharacter.
        pane._cfCatInc = function(a, b)
            if not PinnedItems.displayPinnedItem(pane.inventoryPage) then
                return _origCatInc(a, b)
            end

            -- Keep vanilla equipped ordering.
            if a.equipped and not b.equipped then return false end
            if b.equipped and not a.equipped then return true end

            local aFav = _isRowFav(a)
            local bFav = _isRowFav(b)
            if aFav ~= bFav then
                return aFav -- favourites first
            end

            return _origCatInc(a, b)
        end

        pane._cfCatDesc = function(a, b)
            if not PinnedItems.displayPinnedItem(pane.inventoryPage) then
                return _origCatDesc(a, b)
            end

            -- Keep vanilla equipped ordering.
            if a.equipped and not b.equipped then return false end
            if b.equipped and not a.equipped then return true end

            local aFav = _isRowFav(a)
            local bFav = _isRowFav(b)
            if aFav ~= bFav then
                return aFav -- favourites first (still first even on Z->A)
            end

            return _origCatDesc(a, b)
        end
    end

    local function _isCatIncFunc(func, pane)
        return func == ISInventoryPane.itemSortByCatInc
            or (pane and func == pane._cfCatInc)
    end

    local function _applyCatSorterForPane(pane, wantDesc)
        if not pane then return end

        local allow = PinnedItems.displayPinnedItem(pane.inventoryPage)

        if allow then
            _ensureFavComparators(pane)
            pane.itemSortFunc = wantDesc and pane._cfCatDesc or pane._cfCatInc
        else
            pane.itemSortFunc = wantDesc and ISInventoryPane.itemSortByCatDesc or ISInventoryPane.itemSortByCatInc
        end
    end

    -- Toggle category sort direction, but choose vanilla vs wrappers based on displayPinnedItem().
    ISInventoryPane.sortByType = function(self, button)
        local wantDesc = _isCatIncFunc(self.itemSortFunc, self) -- if currently inc, toggle to desc
        _applyCatSorterForPane(self, wantDesc)
        self:refreshContainer()
    end

    -- Preserve vanilla layout save strings even when our wrappers are active.
    ISInventoryPane.SaveLayout = function(self, name, layout)
        if _origSaveLayout then _origSaveLayout(self, name, layout) end
        if not layout then return end

        _ensureFavComparators(self)

        if self.itemSortFunc == self._cfCatInc then layout.sortBy = "catInc" end
        if self.itemSortFunc == self._cfCatDesc then layout.sortBy = "catDesc" end
    end

    -- Restore: if layout asks for cat sort, pick vanilla vs wrapper based on displayPinnedItem().
    ISInventoryPane.RestoreLayout = function(self, name, layout)
        if _origRestoreLayout then _origRestoreLayout(self, name, layout) end
        if not layout then return end

        if layout.sortBy == "catInc" then
            _applyCatSorterForPane(self, false)
            self:refreshContainer()
        elseif layout.sortBy == "catDesc" then
            _applyCatSorterForPane(self, true)
            self:refreshContainer()
        end
    end

    dlog("installed ISInventoryPane favourites category sort patch")

    PinnedItems._origSortByType     = _origSortByType
    PinnedItems._origSaveLayout     = _origSaveLayout
    PinnedItems._origRestoreLayout  = _origRestoreLayout
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

        -- Prefer an already-provided star texture on the pane; fallback to a shared one if you set it elsewhere.
        local tex = self.favoriteStar
        if not tex then return end

        local texW = tex:getWidth()
        local texH = tex:getHeight()
        local pad  = 2

        -- Vanilla draws category at column3 + 8; we place the icon immediately before it.
        local texX = (self.column3 + 8) - texW - pad

        local y = 0
        for _, v in ipairs(self.itemslist) do
            if _rowIsFav(v) then
                local isDraggingRow = self.dragging ~= nil and self.dragStarted
                    and self.selected and (self.selected[y+1] ~= nil)

                if not isDraggingRow then
                    -- Draw the icon at the bottom of the row.
                    local texY = (y * self.itemHgt) + self.headerHgt + self.itemHgt - texH - 2
                    self:drawTexture(tex, texX, texY, 1, 1, 1, 1)
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
        Events.OnGameBoot.Add(PinnedItems.installInventoryPanePatch)
        Events.OnGameBoot.Add(PinnedItems.installInventoryPaneVisualPatch)

        Events.OnFillInventoryObjectContextMenu.Add(PinnedItems.onFillInventoryContext)
        Events.OnSave.Add(PinnedItems.onSave)
    end
end

return PinnedItems
