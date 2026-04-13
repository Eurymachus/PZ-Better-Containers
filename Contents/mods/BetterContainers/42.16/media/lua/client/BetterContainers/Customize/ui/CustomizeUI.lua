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
local Helpers = require("BetterContainers/Helpers")

local function dlog(msg)
    Helpers.dlog(msg)
end

local TEX_ARROW_RIGHT = getTexture("media/ui/ArrowRight.png")
local TEX_ARROW_DOWN  = getTexture("media/ui/ArrowDown.png")

local FONT_HGT_SMALL  = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

local W = 320
local H = 475

local function _uiSection(pn)
    return "player" .. tostring(pn or 0)
end

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
    if type(iconValue) == "string" then
        local v = trim(iconValue)
        if v == "" then return nil end
        return { kind = "item", value = v }
    end

    if type(iconValue) == "table" then
        local kind = type(iconValue.kind) == "string" and trim(iconValue.kind) or ""
        local value = type(iconValue.value) == "string" and trim(iconValue.value) or ""
        if kind ~= "" and value ~= "" then
            return { kind = kind, value = value }
        end
    end

    return nil
end

local function cloneIconRef(iconValue)
    local icon = normalizeIconKey(iconValue)
    if not icon then return nil end
    return {
        kind = icon.kind,
        value = icon.value,
    }
end

local function iconEquals(a, b)
    local na = normalizeIconKey(a)
    local nb = normalizeIconKey(b)
    if not na or not nb then return false end
    return na.kind == nb.kind and na.value == nb.value
end

local function iconKeyString(iconValue)
    local icon = normalizeIconKey(iconValue)
    if not icon then return nil end
    return tostring(icon.kind) .. "|" .. tostring(icon.value)
end

local function _matchContains(hayLower, needleLower)
    if needleLower == "" then return true end
    if hayLower == "" then return false end
    return string.find(hayLower, needleLower, 1, true) ~= nil
end

local function getCatalogueGroupIcon(catalogue, iconValue)
    local key = iconKeyString(iconValue)
    if not key then return nil end

    local map = catalogue and catalogue.iconToGroupIcon or nil
    local resolved = map and map[key] or nil
    if resolved then
        return cloneIconRef(resolved)
    end

    return cloneIconRef(iconValue)
end

local function getCatalogueGroupKey(catalogue, iconValue)
    local key = iconKeyString(iconValue)
    if not key then return nil end

    local map = catalogue and catalogue.iconToGroupKey or nil
    return map and map[key] or nil
end

local function getVisibleTargetForIcon(catalogue, iconValue)
    local key = iconKeyString(iconValue)
    if not key then return nil end

    local map = catalogue and catalogue.visibleTargetByIconKey or nil
    return map and map[key] or nil
end

local function resolveVisibleSelection(catalogue, iconValue, fallbackGroupKey)
    local target = getVisibleTargetForIcon(catalogue, iconValue)

    local targetGroupKey = target and target.groupKey or fallbackGroupKey
    local targetIcon = target and target.icon or iconValue
    local targetKind = target and target.targetKind or nil

    return targetIcon, targetGroupKey, targetKind
end

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

    self:drawRectBorder(0, y, width - 1, itemHeight, 0.25, 1, 1, 1)

    local data = row.item
    local iconSize = self.iconSize
    local iconPad  = self.iconPad
    local textX    = self.textX

    local togglePad = self.togglePad or 2
    local toggleW   = self.toggleW or 12
    local childIndent = (data and data.kind == "child") and (self.childIndent or 12) or 0

    if data and data.kind == "group" and data.canExpand then
        local gk = data.groupKey
        local tex = (data.isExpanded == true) and TEX_ARROW_DOWN or TEX_ARROW_RIGHT
        if tex then
            local arrowY = y + (itemHeight - tex:getHeight()) / 2
            self:drawTexture(tex, togglePad, arrowY, 1, 1, 1, 1)
        end
    end

    local iconX = (togglePad + toggleW + iconPad) + childIndent
    if data and data.tex then
        self:drawTextureScaledAspect(data.tex, iconX, y + (itemHeight - iconSize) / 2, iconSize, iconSize, 1, 1, 1, 1)
    end

    local name = (data and (data.label or data.name)) or row.text or ""
    self:drawText(name, textX + childIndent, y + (itemHeight - FONT_HGT_SMALL) / 2, 1, 1, 1, 0.90, UIFont.Small)

    return y2
end

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
    local selectedKey = parent and parent._gridSelectedIconKey or nil

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
                if not (selectedKey and data and data.icon and iconKeyString(data.icon) == selectedKey) then
                    self:drawRect(cx - 1, y + top - 1, cell + 2, cell + 2, 0.14, 1, 1, 1)
                end
            end
        end

        self:drawRectBorder(cx, y + top, cell, cell, 0.25, 1, 1, 1)

        if selectedKey and data and data.icon and iconKeyString(data.icon) == selectedKey then
            self:drawRect(cx - 2, y + top - 2, cell + 4, cell + 4, 0.60, 0.70, 0.35, 0.15)
        end

        if data.tex then
            self:drawTextureScaledAspect(data.tex, cx + inset, y + top + inset, icon, icon, 1, 1, 1, 1)
        end

        cx = cx + cell + pad
        if cx > width then break end
    end

    return y2
end

local CustomizeUI = ISCollapsableWindow:derive("BC_CustomizeUI")
CustomizeUI._instanceByPlayer = CustomizeUI._instanceByPlayer or {}

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
    return ModData.getEffective(self.owner, username, self.containerIndex or 0)
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
            if self._texList then
                self.viewToggle:setImage(self._texList)
            end
            self.viewToggle.tooltip = getTextOrNull("UI_BetterContainers_Customize_ListView") or "List view"
        else
            if self._texGrid then
                self.viewToggle:setImage(self._texGrid)
            end
            self.viewToggle.tooltip = getTextOrNull("UI_BetterContainers_Customize_GridView") or "Grid view"
        end
    end
end

function CustomizeUI:_getDefaultButtonIconSelection()
    local button = self.button
    local inv = button and button.inventory or nil
    if not inv then
        return nil
    end

    -- ContainerButtonIcons path (unchanged)
    local ctype = inv.getType and inv:getType() or nil
    if ctype and type(ContainerButtonIcons) == "table" and ContainerButtonIcons[ctype] then
        return {
            kind = "container",
            value = tostring(ctype),
        }
    end

    -- Item-backed containers
    local owner = self.owner
    if owner and instanceof(owner, "InventoryItem") then
        local fullType = owner.getFullType and owner:getFullType() or nil
        if not fullType or fullType == "" then
            return nil
        end

        local currentTex = owner.getTexture and owner:getTexture() or nil
        local currentName = currentTex and currentTex.getName and currentTex:getName() or nil
        if not currentName or currentName == "" then
            return nil
        end

        local sm = ScriptManager and ScriptManager.instance or nil
        local scriptItem = sm and sm.getItem and sm:getItem(fullType) or nil

        if scriptItem and scriptItem.getIconsForTexture then
            local icons = scriptItem:getIconsForTexture()
            if icons and icons.size and icons:size() > 0 then
                for i = 0, icons:size() - 1 do
                    local candidate = {
                        kind = "item",
                        value = tostring(fullType) .. ":" .. tostring(i),
                    }

                    local tex = Helpers.getIconTexture(candidate)
                    local texName = tex and tex.getName and tex:getName() or nil

                    if texName == currentName then
                        return candidate
                    end
                end
            end
        end

        local baseCandidate = {
            kind = "item",
            value = tostring(fullType),
        }

        local baseTex = Helpers.getIconTexture(baseCandidate)
        local baseTexName = baseTex and baseTex.getName and baseTex:getName() or nil

        if baseTexName == currentName then
            return baseCandidate
        end

        return baseCandidate
    end

    return nil
end

function CustomizeUI:_resolvePayloadFromData()
    local username = self:_getUsername()
    local user = (username and self.owner) and ModData.getUser(self.owner, username, self.containerIndex or 0) or nil
    if user then
        return user
    end

    local eff = self:_getEffective()
    if eff then
        return eff
    end

    return {
        name  = (self.button and self.button.name) or "",
        icon  = self:_getDefaultButtonIconSelection(),
        color = nil,
    }
end

function CustomizeUI:_getCurrentSearch()
    local q = self.filter and self.filter.getInternalText and self.filter:getInternalText() or ""
    return string.lower(trim(q or ""))
end

function CustomizeUI:_buildVisibleEntries()
    local cat = IconCatalogue.getCatalogue()
    if not (cat and cat.groupsByKey and cat.groupsSorted) then
        self._iconGroups = {}
        self._iconGroupsSorted = {}
        self._visibleEntries = {}
        self._visibleGroups = {}
        self._listRowByIconKey = {}
        self._listRowByGroupKey = {}
        self._gridRowByGroupKey = {}
        return
    end

    self._iconGroups = cat.groupsByKey
    self._iconGroupsSorted = cat.groupsSorted

    self._visibleEntries = {}
    self._visibleGroups = {}
    self._listRowByIconKey = {}
    self._listRowByGroupKey = {}
    self._gridRowByGroupKey = {}

    self._userExpanded = self._userExpanded or {}
    self._searchExpandedByKey = self._searchExpandedByKey or {}
    self._searchCollapsedByKey = self._searchCollapsedByKey or {}

    local q = self:_getCurrentSearch()
    local searching = (q ~= "")
    self._lastSearchQuery = q

    for _, g in pairs(self._iconGroups) do
        if g then
            g.isExpanded = (self._userExpanded[g.groupKey] == true)
            if not g.canExpand then
                g.isExpanded = false
                self._userExpanded[g.groupKey] = false
            end
        end
    end

    local rowIndex = 0
    for i = 1, #self._iconGroupsSorted do
        local g = self._iconGroupsSorted[i]

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

        local includeGroup = (not searching) or gMatch or anyChildMatch
        if includeGroup then
            rowIndex = rowIndex + 1
            self._visibleEntries[#self._visibleEntries + 1] = g
            self._visibleGroups[#self._visibleGroups + 1] = g

            local gIconKey = iconKeyString(g.icon)
            if gIconKey and self._listRowByIconKey[gIconKey] == nil then
                self._listRowByIconKey[gIconKey] = rowIndex
            end
            self._listRowByGroupKey[g.groupKey] = rowIndex

            local showChildren = false
            if not searching then
                showChildren = (g.isExpanded == true and g.canExpand)
            else
                local se = (self._searchExpandedByKey[g.groupKey] == true)
                local sc = (self._searchCollapsedByKey[g.groupKey] == true)
                showChildren = (g.isExpanded == true) or (g.canExpand and anyChildMatch and se and (not sc))
                if g.canExpand and anyChildMatch and not se and not sc then
                    self._searchExpandedByKey[g.groupKey] = true
                    showChildren = true
                end
            end

            if showChildren then
                local kids = (searching and g.isExpanded ~= true) and childMatches or g.children
                for c = 1, #kids do
                    local child = kids[c]
                    local isHeaderChild = child and child._aliasSet and g.key and child._aliasSet[g.key]
                    if child and (not isHeaderChild) then
                        rowIndex = rowIndex + 1
                        self._visibleEntries[#self._visibleEntries + 1] = child

                        local cIconKey = iconKeyString(child.icon)
                        if cIconKey and self._listRowByIconKey[cIconKey] == nil then
                            self._listRowByIconKey[cIconKey] = rowIndex
                        end
                    end
                end
            end
        end
    end
end

function CustomizeUI:_rebindList()
    self.list:clear()

    local seen = {}
    for i = 1, #self._visibleEntries do
        local data = self._visibleEntries[i]
        self.list:addItem(data.label or data.name or "", data)

        local row = self.list.items[#self.list.items]
        if row and data then
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
end

function CustomizeUI:_getGridCols()
    if not self.grid then return 1 end

    local tile = self.grid.cellSize
    local pad  = self.grid.tilePad
    local left = self.grid.tileLeftPad

    local w = self.grid:getWidth()
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

function CustomizeUI:_rebindGrid()
    self.grid:clear()
    self._gridRowByGroupKey = {}

    local cols = self:_getGridCols()
    local idx = 1
    local gridRowIndex = 0

    while idx <= #self._visibleGroups do
        local cells = {}
        local addedAny = false

        for c = 1, cols do
            local data = self._visibleGroups[idx]
            idx = idx + 1

            cells[#cells + 1] = data
            if data then
                addedAny = true
            end

            if idx > (#self._visibleGroups + 1) then
                break
            end
        end

        if addedAny then
            self.grid:addItem("", { cells = cells })
            gridRowIndex = gridRowIndex + 1

            for c = 1, #cells do
                local data = cells[c]
                if data and data.groupKey and self._gridRowByGroupKey[data.groupKey] == nil then
                    self._gridRowByGroupKey[data.groupKey] = gridRowIndex
                end
            end
        end
    end
end

function CustomizeUI:rebuildVisibleModel()
    self:_buildVisibleEntries()
    self:_rebindList()
    self:_rebindGrid()
    self:_refreshGridSelectionCache()
end

function CustomizeUI:_refreshGridSelectionCache()
    self._gridSelectedIcon = nil
    self._gridSelectedIconKey = nil
    self._selectedGroupKey = nil

    local icon = normalizeIconKey(self._selectedIcon)
    if not icon then return end

    local cat = IconCatalogue.getCatalogue()
    self._selectedGroupKey = getCatalogueGroupKey(cat, icon)
    self._gridSelectedIcon = getCatalogueGroupIcon(cat, icon)
    self._gridSelectedIconKey = iconKeyString(self._gridSelectedIcon)
end

function CustomizeUI:_selectListRowByIcon(iconRef)
    self.list.selected = 0
    local iconKey = iconKeyString(iconRef)
    if iconKey and self._listRowByIconKey and self._listRowByIconKey[iconKey] then
        self.list.selected = self._listRowByIconKey[iconKey]
        return true
    end
    return false
end

function CustomizeUI:_selectListRowByGroupKey(groupKey)
    self.list.selected = 0
    if groupKey and self._listRowByGroupKey and self._listRowByGroupKey[groupKey] then
        self.list.selected = self._listRowByGroupKey[groupKey]
        return true
    end
    return false
end

function CustomizeUI:_selectGridRowByGroupKey(groupKey)
    self.grid.selected = 0
    if groupKey and self._gridRowByGroupKey and self._gridRowByGroupKey[groupKey] then
        self.grid.selected = self._gridRowByGroupKey[groupKey]
        return true
    end
    return false
end

function CustomizeUI:_scrollListToSelected()
    local list = self.list
    if not list then return end

    if not (list.selected and list.selected > 0) then
        list:setYScroll(0)
        return
    end

    local itemH = tonumber(list.itemheight) or 0
    local viewH = tonumber(list.height) or 0
    if itemH <= 0 or viewH <= 0 then return end

    local topY = (list.selected - 1) * itemH
    local wantTopY = topY - math.floor((viewH - itemH) / 2)
    if wantTopY < 0 then wantTopY = 0 end

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

function CustomizeUI:fillFromPayload(payload)
    if type(payload) ~= "table" then return end

    local name = payload.name or ""
    if self.nameEntry and self.nameEntry.setText then
        self.nameEntry:setText(tostring(name))
    end

    local icon = payload.icon or nil
    self._selectedIcon = normalizeIconKey(icon)
    self:_refreshGridSelectionCache()

    local cat = IconCatalogue.getCatalogue()
    local target = getVisibleTargetForIcon(cat, self._selectedIcon)

    local targetGroupKey = target and target.groupKey or self._selectedGroupKey
    local targetIcon = target and target.icon or self._selectedIcon
    local targetKind = target and target.targetKind or nil

    -- If the visible target is a child row, ensure its group is expanded in list view.
    if targetKind == "child" and targetGroupKey and self._iconGroups and self._iconGroups[targetGroupKey] then
        local g = self._iconGroups[targetGroupKey]
        self._userExpanded = self._userExpanded or {}
        self._userExpanded[g.groupKey] = true
        g.isExpanded = true

        if self._viewMode ~= "grid" then
            self:rebuildVisibleModel()
            -- Re-fetch after rebuild in case references changed.
            cat = IconCatalogue.getCatalogue()
            target = getVisibleTargetForIcon(cat, self._selectedIcon)
            targetGroupKey = target and target.groupKey or self._selectedGroupKey
            targetIcon = target and target.icon or self._selectedIcon
            targetKind = target and target.targetKind or nil
        end
    end

    local selectedList = false

    -- If the visible target is a child, prefer selecting that exact visible child row.
    if targetKind == "child" and targetIcon then
        selectedList = self:_selectListRowByIcon(targetIcon)
    end

    -- Otherwise fall back to the visible group row.
    if (not selectedList) and targetGroupKey then
        selectedList = self:_selectListRowByGroupKey(targetGroupKey)
    end

    if targetGroupKey then
        self:_selectGridRowByGroupKey(targetGroupKey)
    else
        self.grid.selected = 0
    end

    if self._viewMode == "grid" then
        self:_scrollGridToSelected()
    else
        self:_scrollListToSelected()
    end

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
    self.containerIndex = ModData.getContainerIndex(button and button.inventory or nil, parent)
    if self.nameEntry then
        self:rebuildVisibleModel()
        self:_fillFromData()
    end
end

function CustomizeUI:onFilterChange(keepScroll)
    local oldListScroll = self.list and self.list:getYScroll() or 0
    local oldGridScroll = self.grid and self.grid:getYScroll() or 0

    self:rebuildVisibleModel()

    local cat = IconCatalogue.getCatalogue()
    local targetIcon, targetGroupKey, targetKind =
        resolveVisibleSelection(cat, self._selectedIcon, self._selectedGroupKey)

    local selectedList = false
    if targetKind == "child" and targetIcon then
        selectedList = self:_selectListRowByIcon(targetIcon)
    end
    if (not selectedList) and targetGroupKey then
        self:_selectListRowByGroupKey(targetGroupKey)
    end

    if targetGroupKey then
        self:_selectGridRowByGroupKey(targetGroupKey)
    end

    if keepScroll then
        if self.list then self.list:setYScroll(oldListScroll) end
        if self.grid then self.grid:setYScroll(oldGridScroll) end
    else
        if self._viewMode == "grid" then
            self:_scrollGridToSelected()
        else
            self:_scrollListToSelected()
        end
    end
end

function CustomizeUI:onToggleView()
    local nextMode = (self._viewMode == "grid") and "list" or "grid"
    self:_setViewMode(nextMode)

    if nextMode == "list" then
        local cat = IconCatalogue.getCatalogue()
        local targetIcon, targetGroupKey, targetKind =
            resolveVisibleSelection(cat, self._selectedIcon, self._selectedGroupKey)

        local selectedList = false
        if targetKind == "child" and targetIcon then
            selectedList = self:_selectListRowByIcon(targetIcon)
        end
        if (not selectedList) and targetGroupKey then
            self:_selectListRowByGroupKey(targetGroupKey)
        end
        self:_scrollListToSelected()
    else
        local cat = IconCatalogue.getCatalogue()
        local _, targetGroupKey, _ =
            resolveVisibleSelection(cat, self._selectedIcon, self._selectedGroupKey)

        if targetGroupKey then
            self:_selectGridRowByGroupKey(targetGroupKey)
        end
        self:_scrollGridToSelected()
    end
end

function CustomizeUI:onIconSelected()
    local row = (self.list.selected > 0) and self.list.items[self.list.selected] or nil
    local data = row and row.item or nil
    self._selectedIcon = data and cloneIconRef(data.icon) or nil
    self:_refreshGridSelectionCache()

    if self._selectedGroupKey then
        self:_selectGridRowByGroupKey(self._selectedGroupKey)
    end
end

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

    self.colorPicker:setPickedFunc(function(_, rgb, mouseUp)
        self:onPickedColor(rgb, mouseUp)
    end)

    self.colorPicker:addToUIManager()

    local c = self._selectedColor or button.backgroundColor or { r = 0, g = 0, b = 0, a = 1 }
    self.colorPicker:setInitialColor(ColorInfo.new(clamp01(c.r), clamp01(c.g), clamp01(c.b), 1))
end

function CustomizeUI:_readPayload()
    local name = trim(self.nameEntry and self.nameEntry:getText() or "")
    if name == "" then return nil end

    local payload = { name = name }

    local icon = normalizeIconKey(self._selectedIcon)
    if icon then
        payload.icon = {
            kind = icon.kind,
            value = icon.value,
        }
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

    context:addOption(getTextOrNull("UI_BetterContainers_Customize_SavePreset") or "Save Preset", self, CustomizeUI.onSave)

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

function CustomizeUI:createChildren()
    ISCollapsableWindow.createChildren(self)

    local width = self:getWidth()
    local height = self:getHeight()

    local buttonHeight = math.max(25, FONT_HGT_SMALL + 3 * 2)
    local pad = 10
    local padMore = 20
    local maxWidth = 160

    self.cancelBtn = ISButton:new(pad, height - buttonHeight - pad, (width - pad * 3) / 2, buttonHeight, getText("UI_Cancel"), self, CustomizeUI.onCancel)
    self.cancelBtn:initialise()
    self:addChild(self.cancelBtn)

    self.applyBtn = ISButton:new(width - ((width - pad * 3) / 2) - pad, height - buttonHeight - pad, (width - pad * 3) / 2, buttonHeight,
        getTextOrNull("UI_Apply") or "Apply", self, CustomizeUI.onApply)
    self.applyBtn:initialise()
    self:addChild(self.applyBtn)

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
        self.titleSaveBtn.tooltip = getTextOrNull("UI_BetterContainers_Customize_PresetsMenu") or "Presets Menu"
        self:addChild(self.titleSaveBtn)
    end

    self.nameEntry = ISTextEntryBox:new("", width - pad - maxWidth, FONT_HGT_MEDIUM + padMore, maxWidth, buttonHeight)
    self.nameEntry:initialise()
    self.nameEntry:instantiate()
    self:addChild(self.nameEntry)

    self.colorBtn = ISButton:new(width - pad - maxWidth, self.nameEntry.y + self.nameEntry.height + pad, maxWidth, buttonHeight, "", self, CustomizeUI.onColor)
    self.colorBtn:initialise()
    self.colorBtn.backgroundColor = { r = 0, g = 0, b = 0, a = 1 }
    self.colorBtn.isSelected = false
    self:addChild(self.colorBtn)

    if ISColorPickerHSB and ColorInfo then
        self.colorPicker = ISColorPickerHSB:new(0, 0, ColorInfo.new())
        self.colorPicker:initialise()
        self.colorPicker.keepOnScreen = true
        self.colorPicker.pickedTarget = self
        self.colorPicker.resetFocusTo = self
    end

    self.filter = ISTextEntryBox:new("", width - pad - maxWidth, self.colorBtn.y + self.colorBtn.height + pad, (maxWidth - buttonHeight - 6), buttonHeight)
    self.filter:initialise()
    self.filter:instantiate()
    self.filter.onTextChange = function() self:onFilterChange() end
    self:addChild(self.filter)

    self._texList = self._texList or getTexture("media/ui/craftingMenus/Icon_List.png")
    self._texGrid = self._texGrid or getTexture("media/ui/craftingMenus/Icon_Grid.png")

    local toggleSize = buttonHeight
    self.viewToggle = ISButton:new(self.filter.x + self.filter.width + 6, self.filter.y, toggleSize, toggleSize, "", self, CustomizeUI.onToggleView)
    self.viewToggle:initialise()
    self.viewToggle.borderColor = { r = 1, g = 1, b = 1, a = 0.25 }
    self.viewToggle.backgroundColor = { r = 0, g = 0, b = 0, a = 0.10 }
    self.viewToggle.backgroundColorMouseOver = { r = 1, g = 1, b = 1, a = 0.08 }
    self:addChild(self.viewToggle)

    local listX = pad
    local listY = self.filter.y + self.filter.height + pad
    local listW = width - padMore
    self._iconBoxX = listX
    self._iconBoxY = listY
    self._iconBoxW = listW

    local gap = 6
    local bottomEdge = self.cancelBtn.y - pad

    local listH = bottomEdge - listY - gap
    if listH < (FONT_HGT_SMALL + 10) then
        listH = FONT_HGT_SMALL + 10
    end

    self._iconBoxH = listH

    self.list = ISScrollingListBox:new(listX, listY, listW, listH)
    self.list:initialise()
    self.list:setFont(UIFont.Small, 2)
    self.list.selected = 0
    self.list.target = self
    self.list.itemheight = FONT_HGT_SMALL + 10
    self.list.iconSize   = FONT_HGT_SMALL + 5
    self.list.iconPad    = 5
    self.list.togglePad  = 2
    self.list.toggleW    = 12
    self.list.childIndent = 12
    local iconX = self.list.togglePad + self.list.toggleW + self.list.iconPad
    self.list.textX = iconX + self.list.iconSize + (self.list.iconPad * 2)
    self.list.doDrawItem = drawList

    function self.list:onMouseDown(x, y)
        local parent = self.target
        if not parent then return end

        local mx = self:getMouseX()
        local my = self:getMouseY()

        if self.vscroll and self.vscroll:isVisible() then
            local sbW = self.vscroll:getWidth()
            if mx >= (self:getWidth() - sbW) then
                ISScrollingListBox.onMouseDown(self, x, y)
                return
            end
        end

        local rowIndex = self:rowAt(mx, my) or 0
        if rowIndex < 1 or not self.items or rowIndex > #self.items then
            ISScrollingListBox.onMouseDown(self, x, y)
            return
        end

        local row = self.items[rowIndex]
        local data = row and row.item or nil
        if not data then
            ISScrollingListBox.onMouseDown(self, x, y)
            return
        end

        if data.kind == "group" and data.canExpand then
            local togglePad = self.togglePad or 2
            local toggleW = self.toggleW or 12
            if mx >= togglePad and mx <= (togglePad + toggleW) then
                local q = parent:_getCurrentSearch()
                if q ~= "" then
                    parent._searchExpandedByKey = parent._searchExpandedByKey or {}
                    parent._searchCollapsedByKey = parent._searchCollapsedByKey or {}

                    local se = (parent._searchExpandedByKey[data.groupKey] == true)
                    if se and data.isExpanded ~= true then
                        parent._searchCollapsedByKey[data.groupKey] = not (parent._searchCollapsedByKey[data.groupKey] == true)
                    else
                        data.isExpanded = not (data.isExpanded == true)
                        parent._userExpanded[data.groupKey] = (data.isExpanded == true)
                        if data.isExpanded == true then
                            parent._searchCollapsedByKey[data.groupKey] = nil
                        end
                    end
                else
                    data.isExpanded = not (data.isExpanded == true)
                    parent._userExpanded[data.groupKey] = (data.isExpanded == true)
                end

                parent:rebuildVisibleModel()

                local cat = IconCatalogue.getCatalogue()
                local targetIcon, targetGroupKey, targetKind =
                    resolveVisibleSelection(cat, parent._selectedIcon, parent._selectedGroupKey)

                local selectedList = false
                if targetKind == "child" and targetIcon then
                    selectedList = parent:_selectListRowByIcon(targetIcon)
                end
                if (not selectedList) and targetGroupKey then
                    parent:_selectListRowByGroupKey(targetGroupKey)
                end
                if targetGroupKey then
                    parent:_selectGridRowByGroupKey(targetGroupKey)
                end

                return
            end
        end

        self.selected = rowIndex
        parent:onIconSelected()
    end

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

        parent._hover.mode = "list"
        parent._hover.listRow = rowIndex
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

    self:addChild(self.list)

    self.grid = ISScrollingListBox:new(listX, listY, listW, listH)
    self.grid:initialise()
    self.grid:setFont(UIFont.Small, 2)
    self.grid.selected = 0
    self.grid.target = self
    self.grid.doDrawItem = drawGridRow
    self.grid.iconSize     = 32
    self.grid.cellSize     = 38
    self.grid.tilePad      = 2
    self.grid.tileLeftPad  = 2
    self.grid.itemheight   = self.grid.cellSize + 2

    function self.grid:onMouseDown(x, y)
        local parent = self.target
        if not parent or not self.items or #self.items == 0 then return end

        local rowIndex = self:rowAt(x, y)
        if rowIndex < 1 then return end
        if rowIndex > #self.items then rowIndex = #self.items end

        getSoundManager():playUISound("UISelectListItem")
        self.selected = rowIndex

        local row = self.items[rowIndex]
        local cells = row and row.item and row.item.cells
        if type(cells) ~= "table" then return end

        local col = math.floor((x - self.tileLeftPad) / (self.cellSize + self.tilePad)) + 1
        local e = cells[col]
        if not e then return end

        parent._selectedIcon = cloneIconRef(e.icon)
        parent:_refreshGridSelectionCache()
        parent:_selectListRowByGroupKey(e.groupKey)
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
        local key = nil
        local colIndex = 0

        if rowIndex > 0 then
            local row = self.items[rowIndex]
            local cells = row and row.item and row.item.cells
            if type(cells) == "table" then
                local cell = self.cellSize or 38
                local pad = self.tilePad or 2
                local left = self.tileLeftPad or 2
                colIndex = math.floor((mx - left) / (cell + pad)) + 1
                local e = cells[colIndex]
                if e and (e.label or e.name) then
                    text = e.label or e.name
                    key = e.icon
                else
                    colIndex = 0
                end
            end
        end

        parent._hover.mode = "grid"
        parent._hover.gridRow = rowIndex
        parent._hover.gridCol = colIndex
        parent._hover.key = key
        parent._hover.text = text

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

        parent._hover.gridRow = 0
        parent._hover.gridCol = 0
        parent._hover.key = nil
        parent._hover.text = ""
        if parent._hover.mode == "grid" then
            parent._hover.mode = nil
        end
    end

    self:addChild(self.grid)

    self._hover = {
        mode = nil,
        listRow = 0,
        gridRow = 0,
        gridCol = 0,
        key = nil,
        text = "",
    }

    self._viewMode = self._viewMode or "list"
    self:_setViewMode(self._viewMode)

    self:rebuildVisibleModel()
    self:_fillFromData()
end

function CustomizeUI:render()
    ISCollapsableWindow.render(self)

    local pad = 10

    local labels = {
        { text = getTextOrNull("UI_BetterContainers_Customize_Name") or "Name",  y = self.nameEntry.y + (self.nameEntry.height - FONT_HGT_SMALL) / 2 },
        { text = getTextOrNull("UI_BetterContainers_Customize_Color") or "Color", y = self.colorBtn.y + (self.colorBtn.height - FONT_HGT_SMALL) / 2 },
        { text = getTextOrNull("UI_BetterContainers_Customize_IconFilter") or "Search Icon", y = self.filter.y + (self.filter.height - FONT_HGT_SMALL) / 2 },
    }

    for _, l in ipairs(labels) do
        self:drawText(l.text, pad, l.y, 1, 1, 1, 1, UIFont.Small)
    end

    if self._iconBoxX and self._iconBoxY and self._iconBoxW and self._iconBoxH then
        self:drawRectBorder(self._iconBoxX, self._iconBoxY, self._iconBoxW, self._iconBoxH, 0.50, 1, 1, 1)
    end
end

function CustomizeUI:prerender()
    if self.dirty then
        self.dirty = false
        self:rebuildVisibleModel()
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
    o.containerIndex = ModData.getContainerIndex(button and button.inventory or nil, parent)

    o._viewMode = "list"
    o._searchExpandedByKey = {}
    o._searchCollapsedByKey = {}
    o._userExpanded = {}
    o._visibleEntries = {}
    o._visibleGroups = {}
    o._selectedIcon = nil
    o._selectedGroupKey = nil
    o._gridSelectedIcon = nil
    o._gridSelectedIconKey = nil

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