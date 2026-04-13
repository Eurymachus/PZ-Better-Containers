require "ISUI/ISLabel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISPanel"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISContextMenu"

local IniWriter  = require("BetterContainers/_IO/IniWriter")
local INI = IniWriter.makeFeature("CustomizeUI")

local Customizer = require("BetterContainers/Customize/Customizer")
local ModData    = require("BetterContainers/Customize/ModData")

local IconCatalogue = require("BetterContainers/Customize/ui/IconCatalogue")

local Presets    = require("BetterContainers/Customize/SavedPresets")
local PresetManagerUI = require("BetterContainers/Customize/PresetManagerUI")

local Helpers         = require("BetterContainers/Helpers")

local function dlog(msg)
    Helpers.dlog(msg)
end

-- Vanilla crafting-style expand/collapse arrows
local TEX_ARROW_RIGHT = getTexture("media/ui/ArrowRight.png")
local TEX_ARROW_DOWN  = getTexture("media/ui/ArrowDown.png")

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

local function _uiSection(pn) return "player" .. tostring(pn or 0) end

local function loadWindowPos(pn)
    local row = INI.get(_uiSection(pn))
    if type(row) ~= "table" then return nil, nil, nil end

    local view = row.view
    if view ~= "list" and view ~= "grid" then
        view = nil
    end

    return tonumber(row.x), tonumber(row.y), view
end

local function saveWindowPos(pn, x, y, viewMode)
    local row = INI.get(_uiSection(pn)) or {}
    row.x = math.floor(tonumber(x) or 0)
    row.y = math.floor(tonumber(y) or 0)

    if viewMode == "grid" or viewMode == "list" then
        row.view = viewMode
    else
        row.view = nil
    end

    INI.set(_uiSection(pn), row)
end

local function trim(s)
    if s == nil then return "" end
    s = tostring(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function clamp01(v)
    v = tonumber(v)
    if not v then return 0 end
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function normalizeIconKey(iconValue)
    if type(iconValue) ~= "string" then
        return nil
    end

    iconValue = trim(iconValue)
    if iconValue == "" then
        return nil
    end

    return iconValue
end

local function _matchContains(hayLower, needleLower)
    if needleLower == "" then return true end
    if hayLower == "" then return false end
    -- plain find (NOT pattern) so user search can't break matches
    return string.find(hayLower, needleLower, 1, true) ~= nil
end

-- ---------------------------------------------------------
-- Icon List draw (with icon + selection tint)
-- ---------------------------------------------------------

local function drawList(self, y, row, alt)
    local yScroll = self:getYScroll()
    local itemHeight = self.itemheight
    local height = self.height
    local width = self:getWidth()

    local y2 = y + itemHeight
    if y2 < -yScroll or y >= height - yScroll then
        return y2
    end

    local parent = self.target
    if parent and parent._hover and parent._hover.mode == "list" then
        if parent._hover.listRow == row.index and self.selected ~= row.index then
            self:drawRect(0, y, width, itemHeight, 0.18, 1, 1, 1)
        end
    end

    if self.selected == row.index then
        self:drawRect(0, y, width, itemHeight, 0.60, 0.70, 0.35, 0.15)
    end

    -- subtle row border
    self:drawRectBorder(
        0,
        y,
        width - 1,
        itemHeight,
        0.25,
        1, 1, 1
    )

    local data = row.item
    local iconSize = self.iconSize
    local iconPad  = self.iconPad
    local textX    = self.textX

    local togglePad = self.togglePad or 2
    local toggleW   = self.toggleW or 12
    local childIndent = (data and data.kind == "child") and (self.childIndent or 12) or 0

    -- Vanilla arrow indicator for groups
    if data and data.kind == "group" and data.canExpand then
        local parent = self.target
        local searching = parent and parent._lastSearchQuery and tostring(parent._lastSearchQuery) ~= "" or false

        local gk = (data.groupKey ~= nil and data.groupKey) or data.key

        local se = false
        local sc = false
        if searching and parent and parent._searchExpandedByKey and gk ~= nil then
            se = (parent._searchExpandedByKey[gk] == true)
        end
        if searching and parent and parent._searchCollapsedByKey and gk ~= nil then
            sc = (parent._searchCollapsedByKey[gk] == true)
        end

        local isOpen = (data.isExpanded == true) or (searching and se and (not sc))
        local tex = isOpen and TEX_ARROW_DOWN or TEX_ARROW_RIGHT
        if tex then
            local arrowY = y + (itemHeight - tex:getHeight()) / 2
            self:drawTexture(tex, togglePad, arrowY, 1, 1, 1, 1)
        end
    end

    -- icon (shifted right for toggle + child indent)
    local iconX = (togglePad + toggleW + iconPad) + childIndent
    if data and data.tex then
        self:drawTextureScaledAspect(data.tex, iconX, y + (itemHeight - iconSize) / 2, iconSize, iconSize, 1, 1, 1, 1)
    end

    local name = (data and (data.label or data.name)) or row.text or ""
    self:drawText(name, textX + childIndent, y + (itemHeight - FONT_HGT_SMALL) / 2, 1, 1, 1, 0.90, UIFont.Small)

    return y2
end

-- ---------------------------------------------------------
-- Grid draw (icon-only, selection tint per cell)
-- ---------------------------------------------------------

local function drawGridRow(self, y, row, alt)
    local yScroll = self:getYScroll()
    local itemHeight = self.itemheight
    local height = self.height
    local width = self:getWidth()

    local y2 = y + itemHeight
    if y2 < -yScroll or y >= height - yScroll then
        return y2
    end

    local item = row and row.item
    local cells = item and item.cells
    if type(cells) ~= "table" then
        return y2
    end

    local parent = self.target
    local selectedKey = (parent and parent._getGridSelectedKey) and parent:_getGridSelectedKey() or (parent and parent._selectedIcon or nil)

    local cell = self.cellSize or self.tileSize
    local icon = self.iconSize or cell
    local pad  = self.tilePad
    local left = self.tileLeftPad
    local top  = math.floor((itemHeight - cell) / 2)
    local inset = math.floor((cell - icon) / 2)

    local cx = left
    for i = 1, #cells do
        local data = cells[i]
        if not data then break end
        if parent and parent._hover and parent._hover.mode == "grid" then
            if parent._hover.gridRow == row.index and parent._hover.gridCol == i then
                -- subtle hover frame/tint (doesn't override selected)
                if not (selectedKey and data and data.key == selectedKey) then
                    self:drawRect(cx - 1, y + top - 1, cell + 2, cell + 2, 0.14, 1, 1, 1)
                end
            end
        end
        -- subtle icon frame (always)
       self:drawRectBorder(
            cx,
            y + top,
            cell,
            cell,
            0.25, 1, 1, 1
        )

        if selectedKey and data.key == selectedKey then
            self:drawRect(
                cx - 2,
                y + top - 2,
                cell + 4,
                cell + 4,
                0.60, 0.70, 0.35, 0.15
            )
        end

        if data.tex then
            self:drawTextureScaledAspect(
                data.tex,
                cx + inset,
                y + top + inset,
                icon,
                icon,
                1, 1, 1, 1
            )
        end

        cx = cx + cell + pad
        if cx > width then
            break
        end
    end

    return y2
end

-- ---------------------------------------------------------
-- Window
-- ---------------------------------------------------------

local CustomizeUI = ISCollapsableWindow:derive("BC_CustomizeUI")
CustomizeUI._instanceByPlayer = CustomizeUI._instanceByPlayer or {}

local W = 320
local H = 475

function CustomizeUI:initialise()
    ISCollapsableWindow.initialise(self)
end

function CustomizeUI:close()
    local pn = self.playerNum or 0
    saveWindowPos(pn, self:getX(), self:getY(), self._viewMode)

    if CustomizeUI._instanceByPlayer[pn] == self then
        CustomizeUI._instanceByPlayer[pn] = nil
    end

    self:removeFromUIManager()
end

function CustomizeUI:_getPlayer()
    return getSpecificPlayer(self.playerNum or 0)
end

function CustomizeUI:_getUsername()
    local pl = self:_getPlayer()
    return pl and pl:getUsername() or nil
end

function CustomizeUI:_getEffective()
    local username = self:_getUsername()
    if not (username and self.owner) then return nil end
    return ModData.getEffective(self.owner, username)
end

function CustomizeUI:_setViewMode(mode)
    if mode ~= "list" and mode ~= "grid" then
        mode = "list"
    end
    self._viewMode = mode

    if self.list then
        self.list:setVisible(mode == "list")
        self.list:setEnabled(mode == "list")
    end
    if self.grid then
        self.grid:setVisible(mode == "grid")
        self.grid:setEnabled(mode == "grid")
    end
    if self.viewToggle then
        if mode == "grid" then
            -- Show "switch to list"
            if self._texList then
                self.viewToggle:setImage(self._texList)
            end
            self.viewToggle.tooltip = getTextOrNull("UI_BetterContainers_Customize_ListView") or "List view"
        else
            -- Show "switch to grid"
            if self._texGrid then
                self.viewToggle:setImage(self._texGrid)
            end
            self.viewToggle.tooltip = getTextOrNull("UI_BetterContainers_Customize_GridView") or "Grid view"
        end
    end
end

-- Resolves the effective payload to display in the UI
function CustomizeUI:_resolvePayloadFromData()
    local username = self:_getUsername()
    local user = (username and self.owner) and ModData.getUser(self.owner, username) or nil
    if user then
        return user
    end

    local eff = self:_getEffective()
    if eff then
        return eff
    end

    -- Fallback (button defaults)
    return {
        name  = (self.button and self.button.name) or "",
        icon  = nil,
        color = nil,
    }
end

function CustomizeUI:fillFromPayload(payload)
    if type(payload) ~= "table" then return end

    -- Name
    local name = payload.name or ""
    if self.nameEntry and self.nameEntry.setText then
        self.nameEntry:setText(tostring(name))
    end

    -- Icon
    local icon = payload.icon or nil
    self._selectedIcon = normalizeIconKey(icon)

    -- If selection is a child, ensure its parent group is expanded in list mode
    local g, isChild = self:_resolveGroupForIcon(self._selectedIcon)
    if isChild and g and g.groupKey then
        self._userExpanded = self._userExpanded or {}
        self._userExpanded[g.groupKey] = true
        g.isExpanded = true

        -- Only rebuild list when we're actually in list mode (avoid disrupting grid open)
        if self._viewMode ~= "grid" and self.generateItemList then
            self:generateItemList()
        end
    end

    self:_selectListRowByIcon(self._selectedIcon)
    self:_selectGridRowByIcon(self._selectedIcon)

    if self._viewMode == "grid" then
        self:_scrollGridToSelected()
    else
        self:_scrollListToSelected()
    end

    -- Color
    local col = payload.color or nil
    if type(col) == "table" then
        self._selectedColor = { r = clamp01(col.r), g = clamp01(col.g), b = clamp01(col.b), a = 1 }
    else
        self._selectedColor = nil
    end

    local bc = self._selectedColor or { r = 0, g = 0, b = 0, a = 1 }
    self.colorBtn.backgroundColor = { r = bc.r, g = bc.g, b = bc.b, a = 1 }
    self.colorBtn.isSelected = (self._selectedColor ~= nil)
end

function CustomizeUI:_fillFromData()
    local payload = self:_resolvePayloadFromData()
    self:fillFromPayload(payload)
end

function CustomizeUI:setTarget(button, page, parent)
    self.button = button
    self.page = page
    self.owner = parent
    if self.nameEntry then
        self:_fillFromData()
    end
end

-- ---------------------------------------------------------
-- Icon list generation (but store iconId)
-- ---------------------------------------------------------

function CustomizeUI:_getGridCols()
    if not self.grid then return 1 end

    local tile = self.grid.cellSize
    local pad  = self.grid.tilePad
    local left = self.grid.tileLeftPad

    local w = self.grid:getWidth()

    -- Account for vertical scrollbar
    if self.grid.vscroll and self.grid.vscroll:isVisible() then
        w = w - self.grid.vscroll:getWidth()
    end

    local usable = w - left
    if usable <= tile then
        return 1
    end

    local cols = math.floor((usable + pad) / (tile + pad))
    if cols < 1 then cols = 1 end
    return cols
end

function CustomizeUI:_populateGridFromList()
    if not self.grid then return end
    self.grid:clear()

    local cols = self:_getGridCols()
    local list = self.list
    if not (list and list.items) then return end

    local idx = 1
    while idx <= #list.items do
        local cells = {}
        for c = 1, cols do
            local data = nil

            -- Skip child rows in the list (grid only shows icon groups)
            while idx <= #list.items do
                local row = list.items[idx]
                local candidate = row and row.item or nil
                idx = idx + 1

                if candidate and candidate.kind ~= "child" then
                    data = candidate
                    break
                end
            end

            cells[#cells + 1] = data

            if idx > #list.items then
                break
            end
        end
        self.grid:addItem("", { cells = cells })
    end
end

function CustomizeUI:generateItemList()
    self.list:clear()

    local cat = IconCatalogue.getCatalogue()
    if not (cat and cat.groupsByKey and cat.groupsSorted) then
        dlog("IconCatalogue missing; icon list empty")
        return
    end

    -- Canonical grouped model comes from catalogue (dedupe by texture)
    self._iconGroups = cat.groupsByKey
    self._iconGroupsSorted = cat.groupsSorted

    -- preserves user expansion state across rebuilds (UI-owned)
    self._userExpanded = self._userExpanded or {}

    -- apply UI-owned expanded flags onto catalogue groups (catalogue never stores UI state)
    for _, g in pairs(self._iconGroups) do
        if g then
            g.isExpanded = (self._userExpanded[g.groupKey] == true)

            if not g.canExpand then
                g.isExpanded = false
                self._userExpanded[g.groupKey] = false
            end
        end
    end

    -- Build list rows from groups (collapsed by default unless user expanded)
    for i = 1, #self._iconGroupsSorted do
        local g = self._iconGroupsSorted[i]
        self.list:addItem(g.label or g.name, g)

        if g.isExpanded and g.canExpand then
            for c = 1, #g.children do
                local child = g.children[c]
                local isHeaderChild = child and child._aliasSet and g.key and child._aliasSet[g.key]
                if child and (not isHeaderChild) then
                    self.list:addItem(child.label or child.name, child)
                end
            end
        end
    end

    local seen = {} -- lower(baseLabel) -> count

    for i = 1, #self.list.items do
        local row = self.list.items[i]
        local data = row and row.item or nil
        if data then
            local base = tostring(data.name or row.text or "")
            local key = base:lower()

            local n = (seen[key] or 0) + 1
            seen[key] = n

            if n > 1 and data.variant and data.variant ~= "" then
                local newLabel = base .. " (" .. tostring(data.variant) .. ")"
                data.label = newLabel
                row.text = newLabel
            else
                data.label = base
                row.text = base
            end
        end
    end

    -- Grid mirrors current list (but skips children via patched _populateGridFromList)
    self:_populateGridFromList()
end

function CustomizeUI:_selectListRowByIcon(iconRef)
    self.list.selected = 0
    if not (iconRef and self.list and self.list.items) then return end
    for i, row in ipairs(self.list.items) do
        if row and row.item and row.item.key == iconRef then
            self.list.selected = i
            return
        end
    end
end

function CustomizeUI:_resolveGroupForIcon(iconRef)
    if not iconRef then return nil, false end

    local groups = self._iconGroupsSorted
    if type(groups) ~= "table" then return nil, false end

    for i = 1, #groups do
        local g = groups[i]
        if g then
            if g.key == iconRef then
                return g, false -- exact group
            end

            local kids = g.children
            if type(kids) == "table" then
                for c = 1, #kids do
                    local child = kids[c]
                    if child then
                        if child.key == iconRef then
                            return g, true
                        end
                        local alias = child._aliasSet
                        if type(alias) == "table" and alias[iconRef] then
                            return g, true
                        end
                    end
                end
            end
        end
    end

    return nil, false
end

function CustomizeUI:_getGridSelectedKey()
    local key = normalizeIconKey(self._selectedIcon)
    if not key then return nil end

    local g, isChild = self:_resolveGroupForIcon(key)
    if isChild and g and g.key then
        return g.key
    end

    return key
end

function CustomizeUI:_selectGridRowByIcon(iconRef)
    if not self.grid then return end
    self.grid.selected = 0
    if not (iconRef and self.grid.items) then return end

    -- 1) Exact match (group key or any cell key)
    for i, row in ipairs(self.grid.items) do
        local item = row and row.item
        local cells = item and item.cells
        if type(cells) == "table" then
            for c = 1, #cells do
                local e = cells[c]
                if e and e.key == iconRef then
                    self.grid.selected = i
                    return
                end
            end
        end
    end

    -- 2) Child selected -> grid cannot show child; select its parent group instead
    local g, isChild = self:_resolveGroupForIcon(iconRef)
    if isChild and g and g.key then
        local groupKey = g.key
        for i, row in ipairs(self.grid.items) do
            local item = row and row.item
            local cells = item and item.cells
            if type(cells) == "table" then
                for c = 1, #cells do
                    local e = cells[c]
                    if e and e.key == groupKey then
                        self.grid.selected = i
                        return
                    end
                end
            end
        end
    end
end

function CustomizeUI:_scrollListToSelected()
    local list = self.list
    if not list then return end

    -- Nothing selected → snap to top
    if not (list.selected and list.selected > 0) then
        list:setYScroll(0)
        return
    end

    local itemH = tonumber(list.itemheight) or 0
    local viewH = tonumber(list.height) or 0
    if itemH <= 0 or viewH <= 0 then return end

    -- Deterministic pixel position of the selected row in the virtual list
    local topY = (list.selected - 1) * itemH
    if topY < 0 then topY = 0 end

    -- Center-ish placement
    local wantTopY = topY - math.floor((viewH - itemH) / 2)
    if wantTopY < 0 then wantTopY = 0 end

    -- ISScrollingListBox uses NEGATIVE scroll values
    list:setYScroll(-wantTopY)
end

function CustomizeUI:_scrollGridToSelected()
    local grid = self.grid
    if not grid then return end

    if not (grid.selected and grid.selected > 0) then
        grid:setYScroll(0)
        return
    end

    if type(grid.topOfItem) ~= "function" then return end

    local itemH = tonumber(grid.itemheight) or 0
    local viewH = tonumber(grid.height) or 0
    if itemH <= 0 or viewH <= 0 then return end

    local topY = grid:topOfItem(grid.selected)
    if topY < 0 then
        grid:setYScroll(0)
        return
    end

    local wantTopY = topY - math.floor((viewH - itemH) / 2)
    if wantTopY < 0 then wantTopY = 0 end

    grid:setYScroll(-wantTopY)
end

function CustomizeUI:onToggleView()
    local nextMode = (self._viewMode == "grid") and "list" or "grid"
    self:_setViewMode(nextMode)

    if nextMode == "grid" then
        -- Select in grid (grid draws selection via _getGridSelectedKey now)
        self:_selectGridRowByIcon(self._selectedIcon)
        self:_scrollGridToSelected()
        return
    end

    -- Switching to LIST:
    -- If selection is a child, ensure its parent group is expanded and list is rebuilt
    local sel = normalizeIconKey(self._selectedIcon)
    if sel then
        local g, isChild = self:_resolveGroupForIcon(sel)
        if isChild and g and g.groupKey then
            self._userExpanded = self._userExpanded or {}
            self._userExpanded[g.groupKey] = true
            g.isExpanded = true

            if self.generateItemList then
                self:generateItemList()
            end
        end
    end

    -- Re-apply selection and scroll now that list is visible and (if needed) rebuilt
    self:_selectListRowByIcon(self._selectedIcon)
    self:_scrollListToSelected()
end

function CustomizeUI:onFilterChange(keepScroll)
    local q = string.lower(self.filter:getInternalText() or "")
    q = trim(q or "")

    local list = self.list
    if not list then return end

    local oldScroll = list:getYScroll()
    local oldSelected = list.selected

    list:clear()

    -- Canonical source is grouped model (built in generateItemList)
    local groups = self._iconGroupsSorted
    if type(groups) ~= "table" then
        -- fallback to old behavior if called too early
        return
    end

    local searching = (q ~= "")

    -- UI-owned search state (never stored on cached catalogue group tables)
    self._searchExpandedByKey = self._searchExpandedByKey or {}
    self._searchCollapsedByKey = self._searchCollapsedByKey or {}

    -- If the query changed, clear per-group search-collapse overrides so new results can expand again
    if searching then
        if self._lastSearchQuery ~= q then
            self._searchCollapsedByKey = {}
        end
    else
        -- Leaving search: clear search-expanded/collapsed state entirely
        if self._lastSearchQuery and self._lastSearchQuery ~= "" then
            self._searchExpandedByKey = {}
            self._searchCollapsedByKey = {}
        end
    end

    self._lastSearchQuery = q

    for i = 1, #groups do
        local g = groups[i]

        local gHay = string.lower(tostring(g.searchText or g.label or g.name or ""))
        local gMatch = _matchContains(gHay, q)

        local childMatches = {}
        local anyChildMatch = false

        for c = 1, #g.children do
            local child = g.children[c]
            local cHay = string.lower(tostring(child.searchText or child.label or child.name or ""))
            local cMatch = _matchContains(cHay, q)
            if cMatch then
                anyChildMatch = true
                childMatches[#childMatches + 1] = child
            end
        end

        if (not searching) then
            -- no filter: show all groups; show children only if expanded
            list:addItem(g.label or g.name, g)
            if g.isExpanded and g.canExpand then
                for c = 1, #g.children do
                    local child = g.children[c]
                    if child and child.key ~= g.key then
                        list:addItem(child.label or child.name, child)
                    end
                end
            end
        else
            -- searching: show group if group matches OR any child matches
            if gMatch or anyChildMatch then
                list:addItem(g.label or g.name, g)

                -- Mark groups as search-expanded when they have matching children
                local gk = (g.groupKey ~= nil and g.groupKey) or g.key

                -- Mark groups as search-expanded when they have matching children (UI-owned)
                if gk ~= nil then
                    self._searchExpandedByKey[gk] = (anyChildMatch == true) and (g.canExpand == true)
                end

                local se = (gk ~= nil) and (self._searchExpandedByKey[gk] == true) or false
                local sc = (gk ~= nil) and (self._searchCollapsedByKey[gk] == true) or false

                -- Effective open state:
                -- - user expanded (persistent) OR
                -- - search expanded (temporary) unless user collapsed it during search
                local isOpen = (g.isExpanded == true) or (se and (not sc))

                if isOpen then
                    if g.isExpanded == true then
                        -- User explicitly expanded during search: show ALL children (lets players browse within a narrowed group set)
                        for c = 1, #g.children do
                            local child = g.children[c]
                            local isHeaderChild = child and child._aliasSet and g.key and child._aliasSet[g.key]
                            if child and (not isHeaderChild) then
                                list:addItem(child.label or child.name, child)
                            end
                        end
                    else
                        -- Search-forced open: show only matching children
                        if anyChildMatch and g.canExpand then
                            for k = 1, #childMatches do
                                local child = childMatches[k]
                                local isHeaderChild = child and child._aliasSet and g.key and child._aliasSet[g.key]
                                if child and (not isHeaderChild) then
                                    list:addItem(child.label or child.name, child)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local seen = {}

    for i = 1, #list.items do
        local row = list.items[i]
        local data = row and row.item or nil
        if data then
            local base = tostring(data.name or row.text or "")
            local key = base:lower()

            local n = (seen[key] or 0) + 1
            seen[key] = n

            if n > 1 and data.variant and data.variant ~= "" then
                local newLabel = base .. " (" .. tostring(data.variant) .. ")"
                data.label = newLabel
                row.text = newLabel
            else
                data.label = base
                row.text = base
            end
        end
    end

    -- Grid mirrors filtered list (skips children)
    self:_populateGridFromList()

    self:_selectListRowByIcon(self._selectedIcon)
    self:_selectGridRowByIcon(self._selectedIcon)

    if keepScroll then
        -- preserve scroll when toggle happens during search
        list:setYScroll(oldScroll)
    else
        if self._viewMode == "grid" then
            self:_scrollGridToSelected()
        else
            self:_scrollListToSelected()
        end
    end
end

function CustomizeUI:onIconSelected()
    local row = (self.list.selected > 0) and self.list.items[self.list.selected] or nil
    local data = row and row.item or nil
    self._selectedIcon = data and data.key or nil

    self:_selectGridRowByIcon(self._selectedIcon)
    if self._viewMode == "grid" then
        self:_scrollGridToSelected()
    end
end

-- ---------------------------------------------------------
-- Color picker (ISColorPickerHSB)
-- ---------------------------------------------------------

function CustomizeUI:onPickedColor(rgb, mouseUp)
    if not rgb then return end

    self._selectedColor = { r = clamp01(rgb.r), g = clamp01(rgb.g), b = clamp01(rgb.b), a = 1 }
    self.colorBtn.backgroundColor = { r = self._selectedColor.r, g = self._selectedColor.g, b = self._selectedColor.b, a = 1 }
    self.colorBtn.isSelected = true

    if self.colorPicker then
        self.colorPicker:removeFromUIManager()
    end
end

function CustomizeUI:onColor(button)
    if not (self.colorPicker and ISColorPickerHSB and ColorInfo) then
        dlog("ISColorPickerHSB missing; cannot open color picker")
        return
    end

    self.colorPicker:setX(button:getAbsoluteX())
    self.colorPicker:setY(button:getAbsoluteY() + button:getHeight())

    -- IMPORTANT: signature is (target, rgb, mouseUp, ...)
    self.colorPicker:setPickedFunc(function(_, rgb, mouseUp)
        self:onPickedColor(rgb, mouseUp)
    end)

    self.colorPicker:addToUIManager()

    -- Populate with current selection (preferred) or button bg
    local c = self._selectedColor or button.backgroundColor or { r = 0, g = 0, b = 0, a = 1 }
    self.colorPicker:setInitialColor(ColorInfo.new(clamp01(c.r), clamp01(c.g), clamp01(c.b), 1))
end

-- ---------------------------------------------------------
-- Save / Apply
-- ---------------------------------------------------------

function CustomizeUI:_readPayload()
    local name = trim(self.nameEntry and self.nameEntry:getText() or "")
    if name == "" then return nil end

    local payload = { name = name }

    if self._selectedIcon and tostring(self._selectedIcon) ~= "" then
        payload.icon = tostring(self._selectedIcon) -- iconRef: "Base.Item" or "Base.Item:idx"
    end

    if type(self._selectedColor) == "table" then
        payload.color = {
            r = clamp01(self._selectedColor.r),
            g = clamp01(self._selectedColor.g),
            b = clamp01(self._selectedColor.b),
            a = 1,
        }
    end

    return payload
end

function CustomizeUI:onSave()
    local payload = self:_readPayload()
    if not payload then return end
    local pl = self:_getPlayer()
    if not (pl and self.owner) then return end
    Presets.saveNew(payload)
    PresetManagerUI.dirty = true
end

function CustomizeUI:onPresetsMenu(button)
    local pn = self.playerNum or 0

    local x = self:getAbsoluteX() + 20
    local y = self:getAbsoluteY() + 20
    if button and button.getAbsoluteX and button.getAbsoluteY and button.getHeight then
        x = button:getAbsoluteX()
        y = button:getAbsoluteY() + button:getHeight()
    end

    local context = ISContextMenu.get(pn, x, y)
    if not context then return end

    -- Save Preset (existing behavior)
    context:addOption(getTextOrNull("UI_BetterContainers_Customize_SavePreset") or "Save Preset", self, CustomizeUI.onSave)

    -- Load Preset (submenu)
    local loadOpt = context:addOption(getTextOrNull("UI_BetterContainers_Customize_LoadPreset") or "Load Preset", nil, nil)
    local loadSub = context:getNew(context)
    context:addSubMenu(loadOpt, loadSub)

    local saved = Presets.loadAll() or {}
    if #saved == 0 then
        local opt = loadSub:addOption(getTextOrNull("UI_BetterContainers_Customize_NoSavedPresets") or "No saved presets", nil, nil)
        opt.notAvailable = true
    else
        for i = 1, #saved do
            local p = saved[i]
            local payload = p and (p.payload or p) or nil
            local name = (p and p.name) or (payload and payload.name) or ("Preset " .. tostring(i))
            local opt = loadSub:addOption(tostring(name), self, CustomizeUI.fillFromPayload, payload)
            if payload and payload.icon then
                local tex = Helpers.getIconTexture(payload.icon)
                if tex then
                    opt.iconTexture = tex
                end
            end
        end
    end

    -- Manage Presets (we'll implement the window next)
    context:addOption(getTextOrNull("UI_BetterContainers_Customize_ManagePresets") or "Manage Presets", self, CustomizeUI.onOpenPresetManager)
end

function CustomizeUI:onOpenPresetManager()
    local pn = self.playerNum or 0
    PresetManagerUI.open(pn, self)
end

function CustomizeUI:onApply()
    local payload = self:_readPayload()
    if not payload then return end
    if not (self.button and self.page and self.owner) then return end
    Customizer.applyPayload(self.button, self.page, self.owner, payload)
    self.page:refreshBackpacks()
    self:close()
end

function CustomizeUI:onCancel()
    self:close()
end

-- ---------------------------------------------------------
-- Children in collapsable window
-- ---------------------------------------------------------

function CustomizeUI:createChildren()
    ISCollapsableWindow.createChildren(self)

    local width = self:getWidth()
    local height = self:getHeight()

    local buttonHeight = math.max(25, FONT_HGT_SMALL + 3 * 2)
    local pad = 10
    local padMore = 20
    local maxWidth = 160

    -- Bottom buttons (Apply / Cancel)
    self.cancelBtn = ISButton:new(pad, height - buttonHeight - pad, (width - pad * 3) / 2, buttonHeight, getText("UI_Cancel"), self, CustomizeUI.onCancel)
    self.cancelBtn:initialise()
    self:addChild(self.cancelBtn)

    self.applyBtn = ISButton:new(width - ((width - pad * 3) / 2) - pad, height - buttonHeight - pad, (width - pad * 3) / 2, buttonHeight,
        getTextOrNull("UI_Apply") or "Apply", self, CustomizeUI.onApply)
    self.applyBtn:initialise()

    self:addChild(self.applyBtn)

    -- Titlebar Save button (next to Close)
    -- Uses a mod texture; ship alongside your lock/unlock/sort icons.
    self._texSave = self._texSave or getTexture("media/ui/BetterContainers/save.png")
    if self._texSave and self.closeButton then
        local bw = self.closeButton:getWidth()
        local bh = self.closeButton:getHeight()
        local bx = self.closeButton.x + bw + 2
        local by = self.closeButton.y
        self.titleSaveBtn = ISButton:new(bx, by, bw, bh, "", self, CustomizeUI.onPresetsMenu)
        self.titleSaveBtn:initialise()
        self.titleSaveBtn.borderColor = { r = 1, g = 1, b = 1, a = 0.0 }
        self.titleSaveBtn.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
        self.titleSaveBtn.backgroundColorMouseOver = { r = 1, g = 1, b = 1, a = 0.08 }
        self.titleSaveBtn:setImage(self._texSave)
        local _tt = getTextOrNull("UI_BetterContainers_Customize_PresetsMenu") or "Presets Menu"
        self.titleSaveBtn.tooltip = _tt
        self:addChild(self.titleSaveBtn)
    end

    -- Name
    self.nameEntry = ISTextEntryBox:new("", width - pad - maxWidth, FONT_HGT_MEDIUM + padMore, maxWidth, buttonHeight)
    self.nameEntry:initialise()
    self.nameEntry:instantiate()
    self:addChild(self.nameEntry)

    -- Color (button)
    self.colorBtn = ISButton:new(width - pad - maxWidth, self.nameEntry.y + self.nameEntry.height + pad, maxWidth, buttonHeight, "", self, CustomizeUI.onColor)
    self.colorBtn:initialise()
    self.colorBtn.backgroundColor = { r = 0, g = 0, b = 0, a = 1 }
    self.colorBtn.isSelected = false
    self:addChild(self.colorBtn)

    -- Color picker instance
    if ISColorPickerHSB and ColorInfo then
        self.colorPicker = ISColorPickerHSB:new(0, 0, ColorInfo.new())
        self.colorPicker:initialise()
        self.colorPicker.keepOnScreen = true
        self.colorPicker.pickedTarget = self
        self.colorPicker.resetFocusTo = self
    end

    -- Icon filter
    self.filter = ISTextEntryBox:new("", width - pad - maxWidth, self.colorBtn.y + self.colorBtn.height + pad, (maxWidth - buttonHeight - 6), buttonHeight)
    self.filter:initialise()
    self.filter:instantiate()
    self.filter.onTextChange = function() self:onFilterChange() end

    self:addChild(self.filter)

    -- View toggle (to the right of the Icon search)
    self._texList = self._texList or getTexture("media/ui/craftingMenus/Icon_List.png")
    self._texGrid = self._texGrid or getTexture("media/ui/craftingMenus/Icon_Grid.png")

    local toggleSize = buttonHeight
    self.viewToggle = ISButton:new(self.filter.x + self.filter.width + 6, self.filter.y, toggleSize, toggleSize, "", self, CustomizeUI.onToggleView)
    self.viewToggle:initialise()
    self.viewToggle.borderColor = { r = 1, g = 1, b = 1, a = 0.25 }
    self.viewToggle.backgroundColor = { r = 0, g = 0, b = 0, a = 0.10 }
    self.viewToggle.backgroundColorMouseOver = { r = 1, g = 1, b = 1, a = 0.08 }
    self:addChild(self.viewToggle)

    -- Shared geometry for list/grid + controls
    local listX = pad
    local listY = self.filter.y + self.filter.height + pad
    local listW = width - padMore
    self._iconBoxX = listX
    self._iconBoxY = listY
    self._iconBoxW = listW

    local gap = 6

    local bottomEdge = self.cancelBtn.y - pad

    -- Let the icon box run almost to the bottom buttons
    local listH = bottomEdge - listY - gap
    if listH < (FONT_HGT_SMALL + 10) then
        listH = FONT_HGT_SMALL + 10
    end

    self._iconBoxH = listH

    -- Icon list (LIST VIEW)
    self.list = ISScrollingListBox:new(listX, listY, listW, listH)
    self.list:initialise()
    self.list:setFont(UIFont.Small, 2)
    self.list.selected = 0
    self.list.target = self
    self.list.onmousedown = function()
        local list = self.list
        if not (list and list.items) then return end

        local mx = list:getMouseX()
        local my = list:getMouseY()
        if list.vscroll and list.vscroll:isVisible() then
            local sbW = list.vscroll:getWidth()
            if mx >= (list:getWidth() - sbW) then
                return
            end
        end
        local rowIndex = list:rowAt(mx, my) or 0
        if rowIndex < 1 or rowIndex > #list.items then return end

        local row = list.items[rowIndex]
        local data = row and row.item or nil
        if not data then return end

        -- Toggle hitbox for group rows only
        if data.kind == "group" and data.canExpand then
            local togglePad = list.togglePad or 2
            local toggleW = list.toggleW or 12

            if mx >= togglePad and mx <= (togglePad + toggleW) then
                -- determine if we're searching BEFORE changing any expansion state
                local q = ""
                if self.filter and self.filter.getInternalText then
                    q = trim(string.lower(self.filter:getInternalText() or ""))
                end

                if q ~= "" then
                    -- Search mode (UI-owned search collapse)
                    self._searchExpandedByKey = self._searchExpandedByKey or {}
                    self._searchCollapsedByKey = self._searchCollapsedByKey or {}

                    local gk = (data.groupKey ~= nil and data.groupKey) or data.key
                    local se = (gk ~= nil) and (self._searchExpandedByKey[gk] == true) or false

                    -- If this group is only open because of searchExpanded, toggle searchCollapsed.
                    -- Otherwise toggle the user's persistent expansion.
                    if se and data.isExpanded ~= true then
                        if gk ~= nil then
                            self._searchCollapsedByKey[gk] = not (self._searchCollapsedByKey[gk] == true)
                        end
                    else
                        data.isExpanded = not (data.isExpanded == true)
                        self._userExpanded = self._userExpanded or {}
                        self._userExpanded[data.groupKey] = data.isExpanded == true

                        -- If user explicitly expands during search, clear any search-collapse override
                        if data.isExpanded == true and gk ~= nil then
                            self._searchCollapsedByKey[gk] = nil
                        end
                    end

                    self:onFilterChange(true)
                    return
                end

                -- No search: toggle persistent expansion and update list incrementally
                data.isExpanded = not (data.isExpanded == true)
                self._userExpanded = self._userExpanded or {}
                self._userExpanded[data.groupKey] = data.isExpanded == true

                -- No search: update list incrementally to avoid scroll/selection jump and hitch
                local oldSelected = list.selected or 0

                if data.isExpanded then
                    -- EXPAND: insert visible child rows after this group row
                    local insertPos = rowIndex + 1
                    local inserted = 0

                    for i = 1, #(data.children or {}) do
                        local child = data.children[i]
                        -- Skip header-child: any child that contains the group representative fullType
                        local isHeaderChild = child and child._aliasSet and data.key and child._aliasSet[data.key]
                        if child and (not isHeaderChild) then
                            table.insert(list.items, insertPos, { text = (child.label or child.name or ""), item = child })
                            insertPos = insertPos + 1
                            inserted = inserted + 1
                        end
                    end

                    -- keep selection stable if it was below the insertion point
                    if oldSelected > rowIndex then
                        list.selected = oldSelected + inserted
                    else
                        list.selected = oldSelected
                    end
                else
                    -- COLLAPSE: remove consecutive child rows belonging to this group
                    local removed = 0
                    local j = rowIndex + 1

                    while j <= #list.items do
                        local r = list.items[j]
                        local it = r and r.item or nil
                        if it and it.kind == "child" and it.parentKey == data.groupKey then
                            table.remove(list.items, j)
                            removed = removed + 1
                        else
                            break
                        end
                    end

                    if oldSelected > rowIndex then
                        local newSel = oldSelected - removed
                        if newSel < rowIndex then newSel = rowIndex end
                        list.selected = newSel
                    else
                        list.selected = oldSelected
                    end
                end

                -- refresh grid icons (grid skips children, but needs list state)
                self:_populateGridFromList()

                return
            end
        end

        -- normal selection
        list.selected = rowIndex
        self:onIconSelected()
    end
    self.list.doDrawItem = drawList

    function self.list:onMouseMove(dx, dy)
        ISScrollingListBox.onMouseMove(self, dx, dy)

        local parent = self.target
        if not parent or parent._viewMode ~= "list" then return end

        local mx = self:getMouseX()
        local my = self:getMouseY()

        local rowIndex = self:rowAt(mx, my) or 0
        if rowIndex < 1 or not self.items or rowIndex > #self.items then
            rowIndex = 0
        end

        if parent._hover.listRow ~= rowIndex then
            parent._hover.mode = "list"
            parent._hover.listRow = rowIndex
        end
    end

    function self.list:onMouseMoveOutside(x, y)
        ISScrollingListBox.onMouseMoveOutside(self, x, y)
        local parent = self.target
        if not parent then return end

        if parent._hover.listRow ~= 0 then
            parent._hover.listRow = 0
            if parent._hover.mode == "list" then
                parent._hover.mode = nil
            end
        end
    end

    self.list.itemheight = FONT_HGT_SMALL + 10
    self.list.iconSize   = FONT_HGT_SMALL + 5
    self.list.iconPad    = 5

    self.list.togglePad  = 2
    self.list.toggleW    = 12
    self.list.childIndent = 12

    -- text starts after toggle + icon + padding
    local iconX = self.list.togglePad + self.list.toggleW + self.list.iconPad
    self.list.textX = iconX + self.list.iconSize + (self.list.iconPad * 2)

    self:addChild(self.list)

    -- Icon grid (GRID VIEW)
    self.grid = ISScrollingListBox:new(listX, listY, listW, listH)
    self.grid:initialise()
    self.grid:setFont(UIFont.Small, 2)
    self.grid.selected = 0
    self.grid.target = self
    self.grid.doDrawItem = drawGridRow

    self.grid.iconSize     = 32      -- actual icon draw size
    self.grid.cellSize     = 38      -- visual/button size (border)
    self.grid.tilePad      = 2       -- spacing between cells
    self.grid.tileLeftPad  = 2
    self.grid.itemheight   = self.grid.cellSize + 2

    function self.grid:onMouseDown(x, y)
        if not self.items or #self.items == 0 then return end

        local rowIndex = self:rowAt(x, y)
        if rowIndex < 1 then return end
        if rowIndex > #self.items then rowIndex = #self.items end

        getSoundManager():playUISound("UISelectListItem")
        self.selected = rowIndex

        local parent = self.target
        if not parent then return end

        local row = self.items[rowIndex]
        local cells = row and row.item and row.item.cells
        if type(cells) ~= "table" then return end

        local col = math.floor((x - self.tileLeftPad) / (self.cellSize + self.tilePad)) + 1
        local e = cells[col]
        if e then
            parent._selectedIcon = e.key
        else
            parent._selectedIcon = nil
        end

        parent:_selectListRowByIcon(parent._selectedIcon)
        parent:_selectGridRowByIcon(parent._selectedIcon)
    end

    function self.grid:onMouseMove(dx, dy)
        ISScrollingListBox.onMouseMove(self, dx, dy)

        local parent = self.target
        if not parent or parent._viewMode ~= "grid" then return end

        local mx = self:getMouseX()
        local my = self:getMouseY()

        local rowIndex = self:rowAt(mx, my) or 0
        if rowIndex < 1 or not self.items or rowIndex > #self.items then
            rowIndex = 0
        end

        local text = ""
        local key  = nil
        local colIndex = 0

        if rowIndex > 0 then
            local row = self.items[rowIndex]
            local cells = row and row.item and row.item.cells
            if type(cells) == "table" then
                local cell = self.cellSize or 38
                local pad  = self.tilePad or 6
                local left = self.tileLeftPad or 6
                colIndex = math.floor((mx - left) / (cell + pad)) + 1
                local e = cells[colIndex]
                if e and (e.label or e.name) then
                    text = e.label or e.name
                    key  = e.key
                else
                    colIndex = 0
                end
            end
        end

        -- Update parent hover state (used for highlight + tooltip)
        parent._hover.mode = "grid"
        parent._hover.gridRow = rowIndex
        parent._hover.gridCol = colIndex
        parent._hover.key = key
        parent._hover.text = text

        -- Tooltip: clear previous row tooltips to avoid "stuck" tooltips
        if self._lastTooltipRow and self.items[self._lastTooltipRow] then
            self.items[self._lastTooltipRow].tooltip = nil
        end

        if rowIndex > 0 and text ~= "" and self.items[rowIndex] then
            self.items[rowIndex].tooltip = text
            self._lastTooltipRow = rowIndex
        else
            self._lastTooltipRow = nil
        end
    end

    function self.grid:onMouseMoveOutside(x, y)
        ISScrollingListBox.onMouseMoveOutside(self, x, y)

        if self._lastTooltipRow and self.items and self.items[self._lastTooltipRow] then
            self.items[self._lastTooltipRow].tooltip = nil
        end
        self._lastTooltipRow = nil

        local parent = self.target
        if not parent then return end

        if parent._hover then
            parent._hover.gridRow = 0
            parent._hover.gridCol = 0
            parent._hover.key = nil
            parent._hover.text = ""
            if parent._hover.mode == "grid" then
                parent._hover.mode = nil
            end
        end
    end

    self:addChild(self.grid)

    self._hover = {
        mode = nil,          -- "list" | "grid"
        listRow = 0,         -- list.items index
        gridRow = 0,         -- grid.items index
        gridCol = 0,         -- 1..N within row.cells
        key = nil,           -- hovered icon key (iconId or fullType for Movables)
        text = "",           -- hovered display name
    }

    -- Default mode
    self._viewMode = self._viewMode or "list"
    self:_setViewMode(self._viewMode)

    -- Populate list + grid + fill fields
    self:generateItemList()
    self:_populateGridFromList()
    self:_fillFromData()
end

function CustomizeUI:render()
    ISCollapsableWindow.render(self)

    local pad = 10

    local labels = {
        { text = getTextOrNull("UI_BetterContainers_Customize_Name") or "Name",  y = self.nameEntry.y + (self.nameEntry.height - FONT_HGT_SMALL) / 2 },
        { text = getTextOrNull("UI_BetterContainers_Customize_Color") or "Color", y = self.colorBtn.y + (self.colorBtn.height - FONT_HGT_SMALL) / 2 },
        { text = getTextOrNull("UI_BetterContainers_Customize_IconFilter") or "Search Icon",  y = self.filter.y + (self.filter.height - FONT_HGT_SMALL) / 2 },
    }

    for _, l in ipairs(labels) do
        self:drawText(l.text, pad, l.y, 1, 1, 1, 1, UIFont.Small)
    end

    if self._iconBoxX and self._iconBoxY and self._iconBoxW and self._iconBoxH then
        local x = self._iconBoxX
        local y = self._iconBoxY
        local w = self._iconBoxW
        local h = self._iconBoxH

        -- 1px solid border
        self:drawRectBorder(x, y, w, h, 0.50, 1, 1, 1)

        -- optional: make it visually "solid" / thicker by doubling the stroke
        -- (comment out if you prefer single-line)
        --self:drawRectBorder(x + 1, y + 1, w - 2, h - 2, 0.45, 1, 1, 1)
    end
end

function CustomizeUI:prerender()
    if self.dirty then
        self.dirty = false
        self:generateItemList()
        self:_fillFromData()
    end
    ISCollapsableWindow.prerender(self)
end

function CustomizeUI:new(x, y, button, page, parent)
    local o = ISCollapsableWindow:new(x, y, W, H)
    setmetatable(o, self)
    self.__index = self

    o.title = getTextOrNull("UI_BetterContainers_Customize_Title") or "Customize"
    o.resizable = false

    o.playerNum = (page and page.player) or 0
    o.button = button
    o.page = page
    o.owner = parent

    o._viewMode = "list"

    -- UI-owned search state (never persisted into cached catalogue groups)
    o._searchExpandedByKey = {}
    o._searchCollapsedByKey = {}

    return o
end

CustomizeUI.open = function(button, page, parent)
    if not (button and page and parent) then return end

    local pn = page.player or 0
    local inst = CustomizeUI._instanceByPlayer[pn]

    if inst and inst.javaObject and inst:getIsVisible() then
        inst:setTarget(button, page, parent)
        inst:addToUIManager()
        inst:bringToTop()
        return
    end

    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()

    local x, y, view = loadWindowPos(pn)
    if not x or not y then
        x = math.floor((sw - W) / 2)
        y = math.floor((sh - H) / 2)
    end

    inst = CustomizeUI:new(x, y, button, page, parent)
    if view then
        inst._viewMode = view
    end
    inst:initialise()
    inst:addToUIManager()
    inst:bringToTop()

    CustomizeUI._instanceByPlayer[pn] = inst
end

CustomizeUI.setDirty = function()
    IconCatalogue.invalidate()
    for _, inst in pairs(CustomizeUI._instanceByPlayer) do
        inst.dirty = true
    end
end

Events[Helpers.OPTIONS_APPLIED].Add(function()
    CustomizeUI.setDirty()
end)

return CustomizeUI
