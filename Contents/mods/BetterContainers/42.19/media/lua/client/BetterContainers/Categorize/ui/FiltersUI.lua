require("ISUI/ISPanel")
require("ISUI/ISButton")
require("ISUI/ISLabel")
require("ISUI/ISScrollingListBox")
require("ISUI/ISTickBox")

local IniWriter = require("BetterContainers/_IO/IniWriter")

local MOD = "BetterContainers"
local DEBUG = getCore():getDebug()

local function dlog(msg)
    if not DEBUG then return end
    DebugLog.log(DebugType.General, "[" .. MOD .. "] " .. tostring(msg))
end

local FiltersUI = ISPanel:derive("BetterContainers_FiltersUI")

-- ---------------------------------------------------------
-- INI (FiltersUI feature)
-- ---------------------------------------------------------

local LayoutIni = IniWriter.makeFeature("FiltersUI", false) -- BetterContainers/FiltersUI.ini (global)

local function _clamp(n, lo, hi)
    if n == nil then return lo end
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

function FiltersUI:_computeItemsColW(listW)
    local font = UIFont.Small
    local header = "Item #"

    local maxW = getTextManager():MeasureStringX(font, header)

    if self._entries then
        for i = 1, #self._entries do
            local e = self._entries[i]
            if e and e.count ~= nil then
                local w = getTextManager():MeasureStringX(font, tostring(e.count))
                if w > maxW then
                    maxW = w
                end
            end
        end
    end

    local itemsW = maxW + 12

    local hi = 99999
    if listW then
        hi = listW - (self.minCategoryW or 120)
    end

    return _clamp(itemsW, self.minItemsW or 46, hi)
end

function FiltersUI:_loadLayout()
    local row = LayoutIni.get("Layout") or {}
    self.savedWindowW = tonumber(row.WindowW)
end

function FiltersUI:_saveLayout()
    local w = tonumber(self.width) or 0
    LayoutIni.set("Layout", {
        WindowW = w,
    })
end

-- ---------------------------------------------------------
-- Header (own render + divider drag)
-- ---------------------------------------------------------

local FiltersHeader = ISPanel:derive("BetterContainers_FiltersHeader")

function FiltersHeader:new(x, y, w, h, owner)
    local o = ISPanel.new(self, x, y, w, h)
    o.owner = owner
    o.backgroundColor = { r = 1, g = 1, b = 1, a = 0.1 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.0 }
    o.drawBorder = false

    o._dragging = false
    o._dragStartX = 0
    o._dragStartItemsW = 0

    return o
end

--[[
function FiltersHeader:_dividerX()
    local ui = self.owner
    local itemsW = ui.itemsColW or ui.minItemsW
    return self.width - itemsW
end

function FiltersHeader:_isOnDivider(x)
    local dx = self:_dividerX()
    return math.abs(x - dx) <= 4
end
]]

function FiltersHeader:onMouseDown(x, y)
    --[[
    if self:_isOnDivider(x) then
        self._dragging = true
        self._dragStartX = x
        self._dragStartItemsW = self.owner.itemsColW or self.owner.minItemsW

        if self.setCapture then
            self:setCapture(true)
        end
        return true
    end
    ]]
    return false
end

function FiltersHeader:onMouseMove(dx, dy)
    --[[
    if not self._dragging then return end

    local ui = self.owner

    -- Drag moves divider; we store items column width.
    local newItemsW = (ui.itemsColW or self._dragStartItemsW or ui.minItemsW) - dx

    local listW = ui.list and ui.list.width or (ui.width - ui._pad * 2)
    local minItemsW = ui.minItemsW
    local minCatW = ui.minCategoryW

    newItemsW = _clamp(newItemsW, minItemsW, listW - minCatW)

    ui.itemsColW = newItemsW
    ]]
end

function FiltersHeader:onMouseUp(x, y)
    --[[
    if not self._dragging then return end
    self._dragging = false

    if self.setCapture then
        self:setCapture(false)
    end

    self.owner:_saveLayout()
    ]]
end

function FiltersHeader:prerender()
    ISPanel.prerender(self)

    local ui = self.owner
    local w = self.width
    local h = self.height

    local font = UIFont.Small
    local fontH = getTextManager():getFontHeight(font)
    local ty = math.floor((h - fontH) / 2)

    -- Divider line under header strip
    -- Background fill
    self:drawRect(0, 0, self.width, self.height, 0.15, 0, 0, 0)

    -- Full border
    self:drawRectBorder(0, 0, self.width, self.height, 0.6, 1, 1, 1)

    -- Column geometry should ignore the list scrollbar width (always assume it exists).
    local scrollbarW = 0
    if ui.list and ui.list.vscroll then
        scrollbarW = ui.list.vscroll.width or 0
    end

    local usableW = w - scrollbarW

    local itemsW = ui.itemsColW or ui.minItemsW
    local dividerX = usableW - itemsW

    -- Divider within usable area (header border remains full width)
    self:drawRect(dividerX, 0, 1, h, 0.35, 1, 1, 1)

    -- Column labels
    local checkboxW = ui._checkboxW
    local nameX = checkboxW
    self:drawText("Category", nameX, ty, 1, 1, 1, 0.85, font)

    local itemsLabel = "Item #"
    local padX = 6
    self:drawText(itemsLabel, dividerX + padX, ty, 1, 1, 1, 0.85, font)
end

-- ---------------------------------------------------------
-- List (own draw + hover + hit-testing)
-- ---------------------------------------------------------

local FiltersListFrame = ISPanel:derive("BetterContainers_FiltersListFrame")

function FiltersListFrame:new(x, y, w, h, owner)
    local o = ISPanel.new(self, x, y, w, h)
    o.owner = owner
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.0 }
    o.drawBorder = false
    return o
end

function FiltersListFrame:prerender()
    ISPanel.prerender(self)

    self:drawRect(0, 0, self.width, self.height, 0.15, 0, 0, 0)
    self:drawRectBorder(0, 0, self.width, self.height, 0.6, 1, 1, 1)
end

local FiltersList = ISScrollingListBox:derive("BetterContainers_FiltersList")

function FiltersList:new(x, y, w, h, owner)
    local o = ISScrollingListBox.new(self, x, y, w, h)
    o.owner = owner
    o.itemheight = 20
    return o
end

function FiltersList:_isRowHovered(y, h)
    if not self:isMouseOver() then return false end
    local my = self:getMouseY()
    return my >= y and my < (y + h)
end

function FiltersList:doDrawItem(y, item, alt)
    local ui = self.owner
    local e = item and item.item
    local h = self.itemheight

    -- Correct scroll culling
    if y + self:getYScroll() + h < 0 or y + self:getYScroll() >= self.height then
        return y + h
    end

    -- Hover highlight (rows only)
    if self:_isRowHovered(y, h) then
        self:drawRect(0, y, self.width, h, 0.12, 1, 1, 1)
    else
        self:drawRect(0, y, self.width, h, 0.00, 1, 1, 1)
    end

    -- Checkbox
    local pad = ui._pad
    local box = ui._box
    local bx = pad
    local by = y + math.floor((h - box) / 2)

    self:drawRectBorder(bx, by, box, box, 0.6, 1, 1, 1)

    if e and e.checked then
        self:drawRect(bx + 3, by + 3, box - 6, box - 6, 0.9, 1, 1, 1)
    end

    -- Text positions
    local font = UIFont.Small
    local fontH = getTextManager():getFontHeight(font)
    local ty = y + math.floor((h - fontH) / 2)

    local tx = ui._checkboxW

    local theLabel = (e and e.label) or "errorCat"
    local translatedLabel = getTextOrNull("IGUI_ItemCat_" .. theLabel) or theLabel

    -- Name column clip width
    local itemsW = ui.itemsColW or ui.minItemsW
    local nameW = self.width - itemsW - tx - 4
    if nameW < 10 then nameW = 10 end

    -- drawTextClipped exists on ISUIElements; if missing, fallback to drawText
    if self.drawTextClipped then
        self:drawTextClipped(translatedLabel, tx, ty, nameW, 1, 1, 1, 0.95, font)
    else
        self:drawText(translatedLabel, tx, ty, 1, 1, 1, 0.95, font)
    end

    -- Count column (right-aligned) - display 0 if explicitly provided, else blank
    if e and e.count ~= nil then
        local countStr = tostring(e.count)
        local tw = getTextManager():MeasureStringX(font, countStr ~= "1" and countStr or "0")
        local usableW = self.width - ((self.vscroll and (self.vscroll.width or 0)) or 0)
        local itemsX = usableW - tw
        self:drawText(countStr, itemsX, ty, 1, 1, 1, 0.75, font)
    end

    return y + h
end

function FiltersList:onMouseDown(x, y)
    local ui = self.owner
    local row = self:rowAt(x, y)
    if row < 1 or row > #self.items then return true end

    local item = self.items[row]
    local e = item and item.item
    if not e or not ui._staged then return true end

    -- Toggle on click anywhere in row (matches current behavior)
    if e.checked then
        e.checked = false
        if ui._staged.map[e.key] then
            ui._staged.map[e.key] = nil
            ui._staged.count = ui._staged.count - 1
        end
    else
        e.checked = true
        if not ui._staged.map[e.key] then
            ui._staged.map[e.key] = true
            ui._staged.count = ui._staged.count + 1
        end
    end

    return true
end

-- ---------------------------------------------------------
-- Footer (buttons)
-- ---------------------------------------------------------

local FiltersFooter = ISPanel:derive("BetterContainers_FiltersFooter")

function FiltersFooter:new(x, y, w, h, owner)
    local o = ISPanel.new(self, x, y, w, h)
    o.owner = owner
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.0 }
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.0 }
    o.drawBorder = false
    return o
end

function FiltersFooter:createChildren()
    ISPanel.createChildren(self)

    local ui = self.owner
    local pad = ui._pad
    local btnH = ui._btnH

    local btnW = math.floor((self.width - pad * 3) / 2)
    local btnY = math.floor((self.height - btnH) / 2)

    ui.btnApply = ISButton:new(pad, btnY, btnW, btnH, "Apply", ui, FiltersUI.onApply)
    ui.btnApply:initialise()
    self:addChild(ui.btnApply)

    ui.btnClear = ISButton:new(pad * 2 + btnW, btnY, btnW, btnH, "Clear", ui, FiltersUI.onClear)
    ui.btnClear:initialise()
    self:addChild(ui.btnClear)
end

-- ---------------------------------------------------------
-- FiltersUI
-- ---------------------------------------------------------

function FiltersUI:new(x, y, w, h, playerNum)
    local o = ISPanel.new(self, x, y, w, h)
    o.playerNum = playerNum or 0
    o.borderColor = { r = 1, g = 1, b = 1, a = 0.2 }
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.85 }
    o.moveWithMouse = false

    o._staged = nil
    o._entries = nil
    o._onApply = nil
    o._onClear = nil
    o._onClose = nil

    -- Layout constants
    o._pad = 8
    o._btnH = 22
    o._titleH = 18
    o._headerH = 24
    o._box = 12
    o._checkboxW = o._pad + o._box + 8

    -- Column mins
    o.minItemsW = 46
    o.minCategoryW = 120

    o:_loadLayout()

    -- Apply default width only when caller didn't specify
    if (w == nil or w <= 0) and o.savedWindowW and o.savedWindowW > 0 then
        o:setWidth(o.savedWindowW)
    end

    return o
end

-- entries = { { key="Food", label="Food", checked=true/false, count=number|nil }, ... }
-- staged = { map = { [key]=true }, count = N }
function FiltersUI:configure(entries, staged, onApply, onClear, onClose, rebuildEntries)
    self._entries = entries or {}
    self._staged = staged
    self._onApply = onApply
    self._onClear = onClear
    self._onClose = onClose
    self._rebuildEntries = rebuildEntries

    if self.showAllTick then
        self.showAllTick:setSelected(1, self.showAll == true)
    end

    if self.list then
        self:_rebuildListItems()
    end
end

function FiltersUI:_ensureStaged()
    if self._staged then return end
    self._staged = { map = {}, count = 0 }
end

function FiltersUI:onShowAllTicked(index, selected)
    self.showAll = selected == true

    -- Do NOT touch staged/applied selection here.
    -- "Show All" is only a visibility toggle (available-only vs all categories).

    if type(self._rebuildEntries) == "function" then
        local newEntries = self._rebuildEntries(self.showAll, self._staged)
        if type(newEntries) == "table" then
            self._entries = newEntries
        end
    end

    if self.list then
        self:_rebuildListItems()
    end
end

function FiltersUI:_rebuildListItems()
    if not self.list then return end

    self.itemsColW = self:_computeItemsColW(self.list.width)
    self.list:clear()
    for i = 1, #self._entries do
        local e = self._entries[i]
        self.list:addItem(e.label, e)
    end
end

function FiltersUI:prerender()
    ISPanel.prerender(self)
    self:bringToTop()
end

local function _isMouseOutside(ui)
    local mx = getMouseX()
    local my = getMouseY()

    local ax = ui:getAbsoluteX()
    local ay = ui:getAbsoluteY()
    local aw = ui:getWidth()
    local ah = ui:getHeight()

    return mx < ax or mx > (ax + aw) or my < ay or my > (ay + ah)
end

function FiltersUI:onMouseDown(x, y)
    if _isMouseOutside(self) then
        self:close()
        return true
    end
    return ISPanel.onMouseDown(self, x, y)
end

function FiltersUI:onRightMouseDown(x, y)
    if _isMouseOutside(self) then
        self:close()
        return true
    end
    return ISPanel.onRightMouseDown(self, x, y)
end

function FiltersUI:createChildren()
    ISPanel.createChildren(self)
    if self.setCapture then
        self:setCapture(true)
    end

    local pad = self._pad
    local btnH = self._btnH
    local titleH = self._titleH
    local headerH = self._headerH
    local footerH = btnH + pad * 2

    -- Title
    self.title = ISLabel:new(pad, pad, titleH, "Filter Categories", 1, 1, 1, 1, UIFont.Small, true)
    self:addChild(self.title)

    -- Show All (title-row checkbox, right-aligned)
    self.showAll = false
    self.showAllTick = ISTickBox:new(0, pad - 1, 100, titleH + 2, "", self, FiltersUI.onShowAllTicked)
    self.showAllTick:initialise()
    self.showAllTick:addOption("Show All")
    self.showAllTick:setSelected(1, self.showAll == true)
    self:addChild(self.showAllTick)

    -- Position after layout exists
    local tickW = 100
    if self.showAllTick.getWidth then
        tickW = self.showAllTick:getWidth()
    elseif self.showAllTick.width then
        tickW = self.showAllTick.width
    end
    self.showAllTick:setX(self.width - pad - tickW)

    -- Header
    local headerY = pad + titleH + 8
    self.header = FiltersHeader:new(pad, headerY, self.width - pad * 2, headerH, self)
    self.header:initialise()
    self:addChild(self.header)

    -- Footer
    local footerY = self.height - footerH
    self.footer = FiltersFooter:new(0, footerY, self.width, footerH, self)
    self.footer:initialise()
    self:addChild(self.footer)

    -- Scroll list between header and footer
    local listY = headerY + headerH - 1
    local listH = footerY - listY

    self.listFrame = FiltersListFrame:new(pad, listY, self.width - pad * 2, listH, self)
    self.listFrame:initialise()
    self:addChild(self.listFrame)

    self.list = FiltersList:new(1, 1, self.listFrame.width - 2, self.listFrame.height - 2, self)
    self.list:initialise()
    self.list:instantiate()
    self.listFrame:addChild(self.list)

    -- Clamp items column to current width
    local listW = self.list.width
    self.itemsColW = self:_computeItemsColW(self.list.width)

    -- Populate
    if self._entries then
        self:_rebuildListItems()
    end

    -- Save current width as last-used (default width)
    self:_saveLayout()
end

function FiltersUI:onApply()
    if self._onApply then
        self._onApply(self._staged)
    end
    self:close()
end

function FiltersUI:onClear()
    if self._staged then
        self._staged.map = {}
        self._staged.count = 0
    end

    if self._entries then
        for i = 1, #self._entries do
            self._entries[i].checked = false
        end
    end

    if self._onClear then
        self._onClear()
    end

    if self.list then
        -- ensure redraw reflects unchecked state
        -- (items are shared tables, so list already has the updated refs)
    end
end

function FiltersUI:close()
    -- persist on close too (covers non-drag changes like window width)
    self:_saveLayout()

    if self._onClose then
        self._onClose()
    end
    self:setVisible(false)
    self:removeFromUIManager()
end

return FiltersUI