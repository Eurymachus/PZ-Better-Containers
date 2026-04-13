require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISInventoryPage"

local Constants = require("BetterContainers/Constants")
local Helpers = require("BetterContainers/Helpers")
local Options = require("BetterContainers/_Options")
local IniWriter = require("BetterContainers/_IO/IniWriter")

local STATE_INI = IniWriter.makeFeature("UtilityPanel", false)
local STATE_SECTION = "state"

local UtilityPanel = {}

local _stateLoaded = false
local _stateRow = {
    inventoryLock = false,
    lootLock = false,
    sortLootWindow = false,
}

local function normalizeStateRow(row)
    row = type(row) == "table" and row or {}

    return {
        inventoryLock = row.inventoryLock == true,
        lootLock = row.lootLock == true,
        sortLootWindow = row.sortLootWindow == true,
    }
end

local function ensureStateLoaded()
    if _stateLoaded then
        return _stateRow
    end

    _stateRow = normalizeStateRow(STATE_INI.get(STATE_SECTION))
    _stateLoaded = true
    return _stateRow
end

local function saveStateRow()
    ensureStateLoaded()
    return STATE_INI.set(STATE_SECTION, _stateRow)
end

local function getLockField(page)
    if page and page.onCharacter then
        return "inventoryLock"
    end
    return "lootLock"
end

local function getLocked(page)
    local row = ensureStateLoaded()
    return row[getLockField(page)] == true
end

local function setLocked(page, value)
    local row = ensureStateLoaded()
    local field = getLockField(page)
    local nextValue = value == true

    if row[field] == nextValue then
        return nextValue
    end

    row[field] = nextValue
    saveStateRow()
    return nextValue
end

local function toggleLocked(page)
    return setLocked(page, not getLocked(page))
end

local function getSortLootWindow()
    local row = ensureStateLoaded()
    return row.sortLootWindow == true
end

local function setSortLootWindow(value)
    local row = ensureStateLoaded()
    local nextValue = value == true

    if row.sortLootWindow == nextValue then
        return nextValue
    end

    row.sortLootWindow = nextValue
    saveStateRow()
    return nextValue
end

local function isButtonValid(invPage, button)
    local panel = invPage and invPage.containerButtonPanel
    return button:getIsVisible() and panel and panel.children and panel.children[button.ID] ~= nil
end

local function getUtilityButtonSize(page)
    return math.floor((page.buttonSize or 0) / 2)
end

local function getUtilityPanelHeight(page)
    return (page.buttonSize or 0) / 2
end

local function isFooterUtilityMode(page)
    return Helpers.isCleanUIActive() or Options.enableUtilityPanelFooter
end

local function needsFooterUtilityReserve(page)
    if not isFooterUtilityMode(page) then
        return false
    end

    if Helpers.isCleanUIActive() then
        return false
    end

    return true
end

local function resizeTopPanelButtons(page)
    if not page then
        return
    end

    local size = getUtilityButtonSize(page)

    if page.sortPriorityButton then
        page.sortPriorityButton:setWidth(size)
        page.sortPriorityButton:setHeight(size)
    end

    if page.containersLockButton then
        page.containersLockButton:setWidth(size)
        page.containersLockButton:setHeight(size)
    end
end

local function ensureUtilityPanel(page)
    if not page then
        return nil
    end

    if page.bcUtilityPanel then
        return page.bcUtilityPanel
    end

    local panel = ISPanel:new(0, 0, page.buttonSize or 0, getUtilityPanelHeight(page))
    panel:initialise()
    panel:instantiate()
    panel:noBackground()
    page:addChild(panel)

    page.bcUtilityPanel = panel
    return panel
end

local function setAnchorLeftRight(ui, left, right)
    if not ui then
        return
    end

    if ui.setAnchorLeft then
        ui:setAnchorLeft(left)
    else
        ui.anchorLeft = left
    end

    if ui.setAnchorRight then
        ui:setAnchorRight(right)
    else
        ui.anchorRight = right
    end
end

local function layoutUtilityPanel(page)
    if not page or not page.containerButtonPanel then
        return
    end

    local panel = ensureUtilityPanel(page)
    if not panel then
        return
    end

    local utilityH = getUtilityPanelHeight(page)
    local buttonSize = page.buttonSize or 0
    local onLeft = Helpers.isPageLeft(page)
    local footerMode = isFooterUtilityMode(page)

    panel:setWidth(buttonSize)
    panel:setHeight(utilityH)

    if footerMode and page.containerButtonPanel then
        local railX = page.containerButtonPanel:getX()
        local railW = page.containerButtonPanel:getWidth()
        local centeredX = railX + math.floor((railW - buttonSize) / 2)

        panel:setY(page:getHeight() - utilityH)
        panel:setX(centeredX)

        if onLeft then
            setAnchorLeftRight(panel, true, false)
        else
            setAnchorLeftRight(panel, false, true)
        end

        if panel.setAnchorTop then
            panel:setAnchorTop(false)
        else
            panel.anchorTop = false
        end

        if panel.setAnchorBottom then
            panel:setAnchorBottom(true)
        else
            panel.anchorBottom = true
        end

        return
    end

    panel:setY(page.containerButtonPanel:getY())

    if onLeft then
        setAnchorLeftRight(panel, true, false)
        panel:setX(0)
    else
        setAnchorLeftRight(panel, false, true)
        panel:setX(page:getWidth() - buttonSize)
    end

    if panel.setAnchorTop then
        panel:setAnchorTop(true)
    else
        panel.anchorTop = true
    end

    if panel.setAnchorBottom then
        panel:setAnchorBottom(false)
    else
        panel.anchorBottom = false
    end
end

local function layoutUtilityButton(page, btn, slot)
    if not page or not btn or not page.bcUtilityPanel then
        return
    end

    local size = getUtilityButtonSize(page)
    local x = (slot == 1) and 0 or size

    btn:setX(x)
    btn:setY(0)

    setAnchorLeftRight(btn, true, false)

    if btn.setAnchorTop then
        btn:setAnchorTop(true)
    else
        btn.anchorTop = true
    end

    if btn.setAnchorBottom then
        btn:setAnchorBottom(false)
    else
        btn.anchorBottom = false
    end
end

local function layoutUtilityButtons(page)
    if not page or not page.containerButtonPanel then
        return
    end

    layoutUtilityPanel(page)
    resizeTopPanelButtons(page)

    layoutUtilityButton(page, page.sortPriorityButton, 1)
    layoutUtilityButton(page, page.containersLockButton, 2)
end

local function layoutUtilityFooterReserve(page)
    if not page or not page.inventoryPane then
        return
    end

    if not needsFooterUtilityReserve(page) then
        return
    end

    local utilityH = getUtilityPanelHeight(page)
    local inventoryY = page.inventoryPane:getY()
    local availableH = page:getHeight() - inventoryY - utilityH

    if availableH < 1 then
        availableH = 1
    end

    page.inventoryPane:setHeight(availableH)
end

local function applyTopButtonsOffset(page)
    if not page or not page.containerButtonPanel then
        return
    end

    if isFooterUtilityMode(page) then
        return
    end

    local offset = getUtilityPanelHeight(page)
    local buttonSize = page.buttonSize or 0

    local ordered = {}
    for _, button in ipairs(page.backpacks or {}) do
        if isButtonValid(page, button) then
            table.insert(ordered, button)
        end
    end

    table.sort(ordered, function(a, b)
        return a:getY() < b:getY()
    end)

    for index, button in ipairs(ordered) do
        button:setY(offset + ((index - 1) * buttonSize))
    end
end

local function wirePinnedTooltip(btn, getTextFn)
    btn.onMouseMove = function(selfBtn, dx, dy)
        if not selfBtn._tooltipWnd then
            local t = ISToolTip:new()
            t:initialise()
            t:addToUIManager()
            t:setOwner(selfBtn)
            t.maxLineWidth = 250
            if type(t.setAlwaysOnTop) == "function" then
                t:setAlwaysOnTop(true)
            end
            selfBtn._tooltipWnd = t
        end

        local text = ""
        if type(getTextFn) == "function" then
            text = tostring(getTextFn() or "")
        elseif type(selfBtn._tooltipText) == "string" then
            text = selfBtn._tooltipText
        end

        selfBtn._tooltipWnd.description = text
        selfBtn._tooltipWnd:setDesiredPosition(
            selfBtn:getAbsoluteX(),
            selfBtn:getAbsoluteY() + selfBtn:getHeight() + 8
        )

        if type(selfBtn._tooltipWnd.bringToTop) == "function" then
            selfBtn._tooltipWnd:bringToTop()
        end
    end

    local function killTip(selfBtn)
        if selfBtn._tooltipWnd then
            selfBtn._tooltipWnd:removeFromUIManager()
            selfBtn._tooltipWnd = nil
        end
    end

    btn.onMouseMoveOutside = killTip
    btn.onRightMouseUpOutside = killTip
end

local function makeIconButton(page, opt)
    local size = assert(opt.size, "size required")
    local slot = opt.utilitySlot or 1

    ensureUtilityPanel(page)

    local btn = ISButton:new(0, 0, size, size, "", page)
    btn._bcUtilitySlot = slot

    if type(opt.applyVisualState) == "function" then
        btn.applyVisualState = opt.applyVisualState
    end

    if btn.applyVisualState then
        btn:applyVisualState()
    end

    if type(opt.onClick) == "function" then
        btn:setOnClick(function()
            opt.onClick(btn)
            if btn.applyVisualState then
                btn:applyVisualState()
            end
        end)
    end

    if type(opt.onMouseDown) == "function" then
        btn.onMouseDown = opt.onMouseDown
    end

    wirePinnedTooltip(btn, opt.getTooltipText)

    btn:initialise()
    btn:instantiate()
    page.bcUtilityPanel:addChild(btn)
    return btn
end

UtilityPanel.install = function()
    if not UtilityPanel._installed then
        UtilityPanel._installed = true
        function ISInventoryPage:bcGetUtilityPanelHeight()
            return getUtilityPanelHeight(self)
        end

        function ISInventoryPage:bcIsFooterUtilityMode()
            return isFooterUtilityMode(self)
        end

        function ISInventoryPage:bcApplyTopButtonsOffset()
            applyTopButtonsOffset(self)
        end

        function ISInventoryPage:bcIsLocked()
            return getLocked(self)
        end

        function ISInventoryPage:bcSetLocked(value)
            return setLocked(self, value)
        end

        function ISInventoryPage:bcToggleLocked()
            return toggleLocked(self)
        end

        function ISInventoryPage:bcGetSortLootWindow()
            return getSortLootWindow()
        end

        function ISInventoryPage:bcSetSortLootWindow(value)
            return setSortLootWindow(value)
        end

        function ISInventoryPage:bcEnsureUtilityPanel()
            ensureUtilityPanel(self)
            if not self.sortPriorityButton then
                self:createSortPriorityButton()
            end
            if not self.containersLockButton then
                self:createLockButton()
            end
        end

        function ISInventoryPage:bcLayoutUtilityPanelOnly()
            self:bcEnsureUtilityPanel()
            layoutUtilityButtons(self)
        end

        function ISInventoryPage:bcApplyUtilityFooterReserve()
            layoutUtilityFooterReserve(self)
        end

        function ISInventoryPage:bcRefreshUtilityPanel()
            self:bcLayoutUtilityPanelOnly()
            self:bcApplyUtilityFooterReserve()
        end

        ISInventoryPage.updateContainersLock = function(self)
            if self.containersLockButton and self.containersLockButton.applyVisualState then
                self.containersLockButton:applyVisualState()
            end
        end

        ISInventoryPage.createSortPriorityButton = function(self)
            local size = getUtilityButtonSize(self)

            local sortBtn = makeIconButton(self, {
                utilitySlot = 1,
                size = size,

                applyVisualState = function(btn)
                    btn:setImage(Constants.Icons.Loaded.Sorting)
                    btn._tooltipText = getTextOrNull("UI_BetterContainers_Priority_tooltip") or "Sorting Priority"
                end,

                getTooltipText = function()
                    return getTextOrNull("UI_BetterContainers_Priority_tooltip") or "Sorting Priority"
                end,

                onMouseDown = function(btn, mx, my)
                    local utilityPanel = btn.parent
                    local page = utilityPanel and utilityPanel.parent or nil
                    local selectedButton = page and page.selectedButton
                    local inventoryPane = page and page.inventoryPane
                    local inventory = selectedButton and selectedButton.inventory or inventoryPane and inventoryPane.inventory
                    if not inventory then
                        return
                    end

                    local cx = getCore():getScreenWidth() / 2
                    local cy = getCore():getScreenHeight() / 2
                    local popup = Reorder_SortPopup:new(cx - 100, cy - 60, page, inventory)
                    popup:initialise()
                    popup:setAlwaysOnTop(true)
                    popup:setCapture(true)
                    popup:addToUIManager()
                end
            })

            self.sortPriorityButton = sortBtn
        end

        ISInventoryPage.createLockButton = function(self)
            local size = getUtilityButtonSize(self)

            local function applyLockVisuals(btn)
                local locked = self:bcIsLocked()
                if locked then
                    btn:setImage(Constants.Icons.Loaded.Locked)
                    btn._tooltipText = getTextOrNull("UI_BetterContainers_Unlock_tooltip") or "Unlock Inventory Window"
                else
                    btn:setImage(Constants.Icons.Loaded.Unlocked)
                    btn._tooltipText = getTextOrNull("UI_BetterContainers_Lock_tooltip") or "Lock Inventory Window"
                end

                if btn._tooltipWnd then
                    btn._tooltipWnd.description = btn._tooltipText
                end
            end

            local lockBtn = makeIconButton(self, {
                utilitySlot = 2,
                size = size,

                applyVisualState = applyLockVisuals,

                getTooltipText = function()
                    local locked = self:bcIsLocked()
                    if locked then
                        return getTextOrNull("UI_BetterContainers_Unlock_tooltip") or "Unlock Inventory Window"
                    else
                        return getTextOrNull("UI_BetterContainers_Lock_tooltip") or "Lock Inventory Window"
                    end
                end,

                onClick = function(btn)
                    self:bcToggleLocked()
                end
            })

            self.containersLockButton = lockBtn
        end

        local old_createChildren = ISInventoryPage.createChildren
        ISInventoryPage.createChildren = function(self)
            old_createChildren(self)
            self:bcEnsureUtilityPanel()
            self:bcRefreshUtilityPanel()
            self:bcApplyTopButtonsOffset()
        end

        local old_onInventoryContainerSizeChanged = ISInventoryPage.onInventoryContainerSizeChanged
        ISInventoryPage.onInventoryContainerSizeChanged = function(self)
            old_onInventoryContainerSizeChanged(self)
            self:bcRefreshUtilityPanel()
            self:bcApplyTopButtonsOffset()
        end

        local old_prerender = ISInventoryPage.prerender
        ISInventoryPage.prerender = function(self)
            old_prerender(self)
            self:bcLayoutUtilityPanelOnly()
        end

        local old_update = ISInventoryPage.update
        ISInventoryPage.update = function(self)
            old_update(self)
            self:bcLayoutUtilityPanelOnly()
            self:bcApplyUtilityFooterReserve()
        end
    end
end

return UtilityPanel
