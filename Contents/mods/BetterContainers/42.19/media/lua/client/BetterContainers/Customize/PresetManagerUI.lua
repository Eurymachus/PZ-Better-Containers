require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISCollapsableWindow"

local Presets = require("BetterContainers/Customize/SavedPresets")
local EC      = require("BetterContainers/Helpers")

local MOD = EC.MODULE_ID

local function clamp01(v)
    v = tonumber(v)
    if not v then return 0 end
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function safeColor(col)
    if type(col) ~= "table" then return nil end
    return { r = clamp01(col.r), g = clamp01(col.g), b = clamp01(col.b), a = 1 }
end

local function getDeleteTexture()
    return getTexture("media/ui/trashIcon.png")
        or getTexture("media/ui/inventoryPanes/Button_Close.png")
        or getTexture("media/ui/Panel_close.png")
end

local function getCloseTexture()
    return getTexture("media/ui/inventoryPanes/Button_Close.png")
        or getTexture("media/ui/Panel_close.png")
end

local PresetManagerUI = ISCollapsableWindow:derive("PresetManagerUI")
PresetManagerUI._instanceByPlayer = {}

local W = 360
local H = 420

function PresetManagerUI:new(x, y, playerNum, ownerUI)
    local o = ISCollapsableWindow:new(x, y, W, H)
    setmetatable(o, self)
    self.__index = self

    o.playerNum = playerNum or 0
    o.ownerUI = ownerUI -- CustomizeUI instance (optional)

    o.title = getTextOrNull("UI_BetterContainers_Customize_ManagePresets") or "Manage Presets"
    o.resizable = false

    o._texClose  = getCloseTexture()
    o._texDelete = getDeleteTexture()

    return o
end

function PresetManagerUI:initialise()
    ISCollapsableWindow.initialise(self)
end

function PresetManagerUI:createChildren()
    ISCollapsableWindow.createChildren(self)

    local pad = 10
    local top = 30
    local w = self.width - (pad * 2)
    local h = self.height - top - pad

    self.list = ISScrollingListBox:new(pad, top, w, h)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = 30
    self.list.drawBorder = true
    self.list.backgroundColor = { r = 0, g = 0, b = 0, a = 0.25 }
    self.list.borderColor = { r = 1, g = 1, b = 1, a = 0.15 }
    self:addChild(self.list)

    -- custom draw + click
    self.list.doDrawItem = function(list, y, row, alt)
        return self:_doDrawPresetRow(list, y, row, alt)
    end

    local _oldMouseDown = self.list.onMouseDown
    self.list.onMouseDown = function(list, x, y)
        if self:_onListMouseDown(list, x, y) then
            return
        end
        return _oldMouseDown(list, x, y)
    end

    local _oldMouseMove = self.list.onMouseMove
    self.list.onMouseMove = function(list, dx, dy)
        local mx = list:getMouseX()
        local my = list:getMouseY()

        local rowIndex = list:rowAt(mx, my)
        local overDel = false
        if rowIndex and rowIndex >= 1 and rowIndex <= #list.items then
            local row = list.items[rowIndex]
            if row and row.item and not row.item.isEmpty then
                overDel = self:_hitDelete(list, rowIndex, mx, my)
            end
        else
            rowIndex = 0
        end

        self:_setHover(rowIndex, overDel)

        if _oldMouseMove then
            return _oldMouseMove(list, dx, dy)
        end
    end

    local _oldMouseMoveOutside = self.list.onMouseMoveOutside
    self.list.onMouseMoveOutside = function(list, dx, dy)
        self:_setHover(0, false)
        if _oldMouseMoveOutside then
            return _oldMouseMoveOutside(list, dx, dy)
        end
    end

    self.list.onScrolled = function(list)
        local mx = list:getMouseX()
        local my = list:getMouseY()
        local rowIndex = list:rowAt(mx, my)

        local overDel = false
        if rowIndex and rowIndex >= 1 and rowIndex <= #list.items then
            local row = list.items[rowIndex]
            if row and row.item and not row.item.isEmpty then
                overDel = self:_hitDelete(list, rowIndex, mx, my)
            end
        else
            rowIndex = 0
        end

        self:_setHover(rowIndex, overDel)
    end

    self:refreshList()
end

function PresetManagerUI:refreshList()
    if not self.list then return end

    self.list:clear()

    local saved = Presets.loadAll() or {}
    if #saved == 0 then
        self.list:addItem(getTextOrNull("UI_BetterContainers_Customize_NoSavedPresets") or "No saved presets", { isEmpty = true })
        return
    end

    for i = 1, #saved do
        local p = saved[i]
        local payload = p and p.payload or nil
        local name = (p and p.name) or (payload and payload.name) or ("Preset " .. tostring(i))
        local iconDef = payload and payload.icon or nil
        local tex = (iconDef and EC.getIconTexture(iconDef)) or nil
        local col = payload and safeColor(payload.color) or nil

        self.list:addItem(tostring(name), {
            preset = p,
            payload = payload,
            tex = tex,
            tint = col,
        })
    end
end

function PresetManagerUI.dirtyUI()
    for _, instance in pairs(PresetManagerUI._instanceByPlayer) do
        if instance and instance.javaObject and instance:getIsVisible() then
            instance:refreshList()
        end
    end
end

function PresetManagerUI:prerender()
    ISCollapsableWindow.prerender(self)
    if PresetManagerUI.dirty then
        PresetManagerUI.dirtyUI()
        PresetManagerUI.dirty = false
    end
end

function PresetManagerUI:_doDrawPresetRow(list, y, row, alt)
    if not row.height then row.height = list.itemheight end
    if row.height <= 0 then return y + row.height end

    if (y + list:getYScroll() + list.itemheight < 0) or (y + list:getYScroll() >= list.height) then
        return y + row.height
    end

    local w = list:getWidth()
    local h = row.height

    local data = row.item
    local isEmpty = data and data.isEmpty

    -- selection highlight handled by listbox
    if isEmpty then
        list:drawText(tostring(row.text or ""), 10, y + (h - getTextManager():getFontHeight(UIFont.Small)) / 2, 1, 1, 1, 0.75, UIFont.Small)
        return y + h
    end

    -- background tint from payload color
    if data and data.tint then
        local t = data.tint
        list:drawRect(0, y, w, h, 0.22, t.r, t.g, t.b)
    end

    -- subtle row border
    list:drawRectBorder(0, y, w - 1, h, 0.12, 1, 1, 1)

    local iconSize = 22
    local iconX = 8
    local iconY = y + (h - iconSize) / 2

    if data and data.tex then
        list:drawTextureScaledAspect(data.tex, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
    end

    local textX = iconX + iconSize + 8
    list:drawText(tostring(row.text or ""), textX, y + (h - getTextManager():getFontHeight(UIFont.Small)) / 2, 1, 1, 1, 0.90, UIFont.Small)

    -- delete "X" icon area
    local isHoverRow = false
    if self._hoverRow and self._hoverRow >= 1 then
        local hoverTopY = list:topOfItem(self._hoverRow) -- content-space
        if hoverTopY >= 0 and math.abs(hoverTopY - y) < 0.5 then
            isHoverRow = true
        end
    end
    local isHoverDelete = (isHoverRow and self._hoverOverDelete == true)

    local x1, y1, x2, y2, bx, by, size = self:_getDeleteBoundsAtY(list, y)

    if isHoverDelete then
        list:drawRect(x1, y1, (x2 - x1), (y2 - y1), 0.20, 1, 1, 1)
    end

    local tex = self._texDelete or self._texClose
    local a = isHoverDelete and 1.0 or 0.85
    if tex then
        list:drawTextureScaledAspect(tex, bx, by, size, size, a, 1, 1, 1)
    else
        list:drawText("X", bx + 5, y + (h - getTextManager():getFontHeight(UIFont.Small)) / 2, 1, 0.2, 0.2, a, UIFont.Small)
    end

    return y + h
end

function PresetManagerUI:_onListMouseDown(list, x, y)
    if not (list and list.items and #list.items > 0) then return false end

    -- Use the same coordinate space as hover logic
    local mx = list:getMouseX()
    local my = list:getMouseY()

    local rowIndex = list:rowAt(mx, my)
    if rowIndex < 1 or rowIndex > #list.items then return false end

    local row = list.items[rowIndex]
    if not row or not row.item then return false end
    if row.item.isEmpty then return false end

    if self:_hitDelete(list, rowIndex, mx, my) then
        local preset = row.item.preset
        if preset and preset.id then
            Presets.deleteById(preset.id)
            self:refreshList()
            return true
        end
    end

    return false
end

function PresetManagerUI:_getDeleteBoundsAtY(list, rowTopY)
    local h = list.itemheight or 30

    local w = list:getWidth()
    local sbw = (list.vscroll and list.vscroll.width) or 0
    local contentW = w - sbw

    local size = 20
    local padRight = 10
    local pad = 2

    local bx = contentW - padRight - size
    local by = rowTopY + (h - size) / 2

    local x1, y1 = bx - pad, by - pad
    local x2, y2 = bx + size + pad, by + size + pad

    return x1, y1, x2, y2, bx, by, size
end

function PresetManagerUI:_getRowTopY(list, rowIndex)
    if not (list and list.topOfItem) then return 0 end
    local y = list:topOfItem(rowIndex)
    if y < 0 then return 0 end
    return y
end

function PresetManagerUI:_hitDelete(list, rowIndex, x, y)
    local rowTopY = self:_getRowTopY(list, rowIndex) -- content-space
    local x1, y1, x2, y2 = self:_getDeleteBoundsAtY(list, rowTopY)
    return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

function PresetManagerUI:_setHover(rowIndex, overDelete)
    self._hoverRow = rowIndex
    self._hoverOverDelete = overDelete == true

    if self.list then
        if self._hoverOverDelete and rowIndex and rowIndex > 0 then
            self.list.tooltip = getTextOrNull("UI_BetterContainers_Delete") or "Delete"
        else
            self.list.tooltip = nil
        end
    end
end

function PresetManagerUI:onResize()
    ISCollapsableWindow.onResize(self)
    -- not resizable, but keep safe
end

function PresetManagerUI:close()
    ISCollapsableWindow.close(self)
end

PresetManagerUI.open = function(playerNum, ownerUI)
    local pn = playerNum or 0
    local inst = PresetManagerUI._instanceByPlayer[pn]

    if inst and inst.javaObject and inst:getIsVisible() then
        inst.ownerUI = ownerUI
        inst:refreshList()
        inst:addToUIManager()
        inst:bringToTop()
        return
    end

    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()

    local x = math.floor((sw - W) / 2)
    local y = math.floor((sh - H) / 2)

    inst = PresetManagerUI:new(x, y, pn, ownerUI)
    inst:initialise()
    inst:addToUIManager()

    PresetManagerUI._instanceByPlayer[pn] = inst
end

return PresetManagerUI
