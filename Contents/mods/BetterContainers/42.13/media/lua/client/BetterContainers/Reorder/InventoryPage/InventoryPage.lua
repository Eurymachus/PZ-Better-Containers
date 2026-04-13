require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISMouseDrag"
require "ISUI/ISInventoryPage"

local Constants = require("BetterContainers/Reorder/Constants")
local Reorder = require("BetterContainers/Reorder")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6

local ContainerButton = require("BetterContainers/Reorder/InventoryPage/ContainerButton")

local _old_addContainerButton = ISInventoryPage.addContainerButton
function ISInventoryPage:addContainerButton(container, texture, name, tooltip)
    local button = _old_addContainerButton(self, container, texture, name, tooltip)
    return ContainerButton:getInstance(button, self)
end

local _old_createChildren = ISInventoryPage.createChildren
ISInventoryPage.createChildren = function(self)
    _old_createChildren(self)

    self:createSortPriorityButton()
    self:createLockButton()
end

local function toggleLock(self, lockButton)
    local playerObj = getSpecificPlayer(self.player)
    if not playerObj then
        return
    end

    Reorder.toggleLock(playerObj, self.onCharacter)

    lockButton:applyVisualState()
end

ISInventoryPage.updateContainersLock = function(self)
    if self.containersLockButton and self.containersLockButton.applyVisualState then
        self.containersLockButton:applyVisualState()
    end
end

-- =========================================================
-- Shared UI helpers
-- =========================================================

--- Compute X/Y for a button in the vanilla bottom-right row.
-- @param self ISInventoryPage
-- @param indexFromRight number (1 = rightmost, 2 = second-from-right, etc.)
-- @param size number (button width/height)
-- @return x, y numbers
local function _computeButtonFrame(self, indexFromRight, size)
    -- X: pack from the right edge
    local x = self:getWidth() - (size * indexFromRight)

    -- Y: safe fallback using current page height + title bar (early frames)
    local y = self:getHeight() - size * 0.5 - self:titleBarHeight()
    return x, y
end

--- Wire an anchored, pinned tooltip to a button.
-- Tooltip text is provided by getTextFn() each hover tick.
-- @param btn ISButton
-- @param getTextFn function():string
local function _wirePinnedTooltip(btn, getTextFn)
    btn.onMouseMove = function(selfBtn, dx, dy)
        if not selfBtn._tooltipWnd then
            local t = ISToolTip:new()
            t:initialise()
            t:addToUIManager()
            t:setOwner(selfBtn)
            t.maxLineWidth = 250
            -- Temporary Hack (Build 42.11) — keep above other UI
            if type(t.setAlwaysOnTop) == "function" then
                t:setAlwaysOnTop(true)
            end
            selfBtn._tooltipWnd = t
        end
        local text = ""
        if type(getTextFn) == "function" then
            text = tostring(getTextFn() or "")
        elseif type(selfBtn._tooltipText) == "string" then
            -- Fallback for legacy callers
            text = selfBtn._tooltipText
        end
        selfBtn._tooltipWnd.description = text
        selfBtn._tooltipWnd:setDesiredPosition(selfBtn:getAbsoluteX(), selfBtn:getAbsoluteY() + selfBtn:getHeight() + 8)
        if type(selfBtn._tooltipWnd.bringToTop) == "function" then
            selfBtn._tooltipWnd:bringToTop()
        end
    end

    local function _killTip(selfBtn)
        if selfBtn._tooltipWnd then
            selfBtn._tooltipWnd:removeFromUIManager()
            selfBtn._tooltipWnd = nil
        end
    end

    btn.onMouseMoveOutside = _killTip
    btn.onRightMouseUpOutside = _killTip
end

--- Center vs controls row when usable; otherwise recompute a bottom-aligned Y
--- from current page geometry each frame (so resizes never drift).
local function _centerInControlsRow(page, btn)
    local originalPrerender = btn.prerender
    btn.prerender = function(b)
        if originalPrerender then
            originalPrerender(b)
        end

        local row = page.controlsUI
        local rowOK = row and row:isVisible() and (row:getHeight() or 0) > 0

        --[[if rowOK then
            local centeredY = row:getY() + (row:getHeight() - b:getHeight()) * 0.5
            if math.abs(b:getY() - centeredY) > 0.1 then
                b:setY(math.floor(centeredY))
            end]]
        -- else
        -- Recompute every frame based on current height + titlebar.
        local fallbackY = page:getHeight() - b:getHeight() * 0.5 - page:titleBarHeight()
        fallbackY = math.floor(fallbackY)
        if math.abs(b:getY() - fallbackY) > 0.1 then
            b:setY(fallbackY)
        end
        -- end
    end
end

--- Factory to create a bottom-right anchored icon button with pinned tooltip & row-centering.
-- @param self ISInventoryPage
-- @param opt table {
--   indexFromRight: number,            -- 1=rightmost, 2=second, ...
--   size: number,                      -- button size
--   getTooltipText: function():string, -- tooltip text provider (called on hover)
--   onClick: function(btn)             -- primary click handler (LMB)
--   onMouseDown: function(btn,x,y)     -- alternative mouse down (optional)
--   applyVisualState: function(btn)    -- set icon/tooltip based on state (optional; called now and after onClick if provided)
-- }
-- @return ISButton
local function _makeIconButton(self, opt)
    local size = assert(opt.size, "size required")
    local idx = opt.indexFromRight or 1
    local x, y = _computeButtonFrame(self, idx, size)

    local btn = ISButton:new(x, y, size, size, "", self)

    -- Anchors: stick to bottom-right
    btn.anchorLeft, btn.anchorRight = false, true
    btn.anchorTop, btn.anchorBottom = false, true

    -- Optional state visual setup (icon + default tooltip text)
    if type(opt.applyVisualState) == "function" then
        btn.applyVisualState = opt.applyVisualState
    end

    if btn.applyVisualState then
        btn:applyVisualState()
    end

    -- Click behavior
    if type(opt.onClick) == "function" then
        btn:setOnClick(function()
            opt.onClick(btn)
            -- Refresh visuals after state change
            if btn.applyVisualState then
                btn:applyVisualState()
            end
        end)
    end
    if type(opt.onMouseDown) == "function" then
        btn.onMouseDown = opt.onMouseDown
    end

    -- Tooltip lifecycle
    _wirePinnedTooltip(btn, opt.getTooltipText)

    -- Vertical centering vs vanilla row
    _centerInControlsRow(self, btn)

    btn:initialise()
    btn:instantiate()
    self:addChild(btn)
    return btn
end

-- =========================================================
-- Button creators (refactored to use the shared factory)
-- =========================================================

-- Create the "Sorting Priority" button (rightmost)
ISInventoryPage.createSortPriorityButton = function(self)
    local size = self.buttonSize / 2

    local sortBtn = _makeIconButton(self, {
        indexFromRight = 1,
        size = size,

        applyVisualState = function(btn)
            btn:setImage(Constants.Icons.Loaded.Sorting)
            -- keep a fallback string on the button; factory also supports a provider fn
            btn._tooltipText = getTextOrNull("UI_BetterContainers_Priority_tooltip") or "Sorting Priority"
        end,

        getTooltipText = function()
            return getTextOrNull("UI_BetterContainers_Priority_tooltip") or "Sorting Priority"
        end,

        -- Open manual popup centered on screen for the selected container
        onMouseDown = function(btn, mx, my)
            local page = btn:getParent()
            local selectedButton = page and page.selectedButton
            if not selectedButton then
                return
            end

            local cx = getCore():getScreenWidth() / 2
            local cy = getCore():getScreenHeight() / 2
            local popup = Reorder_SortPopup:new(cx - 100, cy - 60, page, selectedButton.inventory)
            popup:initialise()
            popup:setAlwaysOnTop(true)
            popup:setCapture(true)
            popup:addToUIManager()
        end
    })

    self.sortPriorityButton = sortBtn
end

-- Create the Lock/Unlock button (second from right), stateful visuals
ISInventoryPage.createLockButton = function(self)
    local size = self.buttonSize / 2

    local function _applyLockVisuals(btn)
        local locked = Reorder.isLocked(self) or not Reorder.canSortBackpacks(self)
        if locked then
            btn:setImage(Constants.Icons.Loaded.Locked)
            btn._tooltipText = getTextOrNull("UI_BetterContainers_Unlock_tooltip") or "Unlock Container Order"
        else
            btn:setImage(Constants.Icons.Loaded.Unlocked)
            btn._tooltipText = getTextOrNull("UI_BetterContainers_Lock_tooltip") or "Lock Container Order"
        end
        -- keep any live tooltip window in sync if open
        if btn._tooltipWnd then
            btn._tooltipWnd.description = btn._tooltipText
        end
    end

    local lockBtn = _makeIconButton(self, {
        indexFromRight = 2,
        size = size,

        applyVisualState = _applyLockVisuals,

        getTooltipText = function()
            -- Always derive from current state
            local locked = Reorder.isLocked(self) or not Reorder.canSortBackpacks(self)
            if locked then
                return getTextOrNull("UI_BetterContainers_Unlock_tooltip") or "Unlock Container Order"
            else
                return getTextOrNull("UI_BetterContainers_Lock_tooltip") or "Lock Container Order"
            end
        end,

        onClick = function(btn)
            -- If reordering is disallowed, bounce to the options popup for clarity
            if not Reorder.canSortBackpacks(self) then
                if self.sortPriorityButton and self.sortPriorityButton.onMouseDown then
                    self.sortPriorityButton:onMouseDown(0, 0)
                end
                return
            end
            -- Toggle logic
            toggleLock(self, btn)
            -- visuals will be refreshed by factory via applyVisualState
        end
    })

    self.containersLockButton = lockBtn
end

local function isButtonValid(invPage, button)
    local panel = invPage and invPage.containerButtonPanel
    return button:getIsVisible() and panel and panel.children and panel.children[button.ID] ~= nil
end

ISInventoryPage.setContainerButtons_Reorder = function(self, draggedButton)
    -- Don't reorder if the button hasn't moved far enough
    if draggedButton and math.abs(draggedButton:getY() - draggedButton.reorderStartY) <= 32 then
        draggedButton:setY(draggedButton.reorderStartY)
        return
    end

    local playerObj = getSpecificPlayer(self.player)

    local inventoriesAndY = {}
    for index, button in ipairs(self.backpacks) do
        if isButtonValid(self, button) then
            table.insert(inventoriesAndY, {
                inventory = button.inventory,
                y = button:getY()
            })
        end
    end
    table.sort(inventoriesAndY, function(a, b)
        return a.y < b.y
    end)

    local seenObjs = {}
    local lastSort = 0
    for index, data in ipairs(inventoriesAndY) do
        local rd = Reorder.getData(playerObj, data.inventory)
        local parent = rd and rd.owner
        local isManual = rd and rd:isManual()
        local isDraggedButton = data.inventory == draggedButton.inventory

        if not isDraggedButton and parent ~= playerObj and seenObjs[parent] then
            -- Skip this button, some IsoObjects have multiple inventories
        else
            if parent then
                seenObjs[parent] = true
            end

            local savedSort = rd and rd:getSortNumber() or nil
            if not isManual or isDraggedButton or savedSort == nil then
                lastSort = lastSort + 10
                if rd and rd.setSort then
                    rd:setSort(lastSort, nil)
                end
            else
                lastSort = savedSort
                -- Look back one button
                if index > 1 then
                    local prevInventory = inventoriesAndY[index - 1].inventory
                    local prevSort = Reorder.getSortPriority(playerObj, prevInventory)
                    if prevSort >= lastSort then
                        Reorder.setSortPriority(playerObj, prevInventory, lastSort - 1, false)
                    end
                end
            end
        end
    end
end

ISInventoryPage.applyBackpackOrder = function(self)
    local playerObj = getSpecificPlayer(self.player)
    local panel = self.containerButtonPanel

    local buttonsAndSort = {}
    for index, button in ipairs(self.backpacks) do
        if isButtonValid(self, button) then
            local sort = 1000 + index
            local rd = Reorder.getData(playerObj, button.inventory)
            if rd then
                sort = rd:getSortNumber() or (1000 + index)
            end
            table.insert(buttonsAndSort, {
                button = button,
                sort = sort
            })
        end
    end

    table.sort(buttonsAndSort, function(a, b)
        return a.sort < b.sort
    end)

    -- Y coordinates are relative to the PANEL (top of the button list),
    -- so don't add page:titleBarHeight() anymore.
    for index, data in ipairs(buttonsAndSort) do
        data.button:setY((index - 1) * self.buttonSize)
    end
end

local _old_refreshBackpacks = ISInventoryPage.refreshBackpacks
ISInventoryPage.refreshBackpacks = function(self)
    if self.killTheChoice then
        self.backpackChoice = nil
        self.killTheChoice = false
    end

    _old_refreshBackpacks(self)
    if Reorder.canSortBackpacks(self) then
        self:applyBackpackOrder()
    end
    self.pendingReorder = false
end

local _old_onMouseWheel = ISInventoryPage.onMouseWheel
ISInventoryPage.onMouseWheel = function(self, del)
    -- Store the original order of the backpacks
    local originalOrder = {}
    for index, button in ipairs(self.backpacks) do
        originalOrder[button] = index
    end

    -- Sort the backpacks by their Y position so that scrolling works as expected
    table.sort(self.backpacks, function(a, b)
        return a:getY() < b:getY()
    end)

    -- The backpacks *might* get refreshed by the mousescroll, so we track that
    self.pendingReorder = true

    local retVal = _old_onMouseWheel(self, del)

    -- The backpacks were not refreshed, so we need to restore the original order
    if self.pendingReorder then
        table.sort(self.backpacks, function(a, b)
            return originalOrder[a] < originalOrder[b]
        end)
        self.pendingReorder = false
    end

    return retVal
end


local _old_onJoypadDown = ISInventoryPage.onJoypadDown
local function onJoypadDown(self, target, button)
    -- Store the original order of the backpacks
    local originalOrder = {}
    for index, button in ipairs(target.backpacks) do
        originalOrder[button] = index
    end

    -- Sort the backpacks by their Y position so that scrolling works as expected
    table.sort(target.backpacks, function(a, b)
        return a:getY() < b:getY()
    end)

    -- Clear the 'backpackChoice', not sure what its actually for, but we stop it from existing on bumper inputs
    target.killTheChoice = true

    local retVal = _old_onJoypadDown(self, button)
    table.sort(target.backpacks, function(a, b)
        return originalOrder[a] < originalOrder[b]
    end)
    return retVal
end

ISInventoryPage.onJoypadDown = function(self, button)
    if button == Joypad.LBumper then
        return onJoypadDown(self, getPlayerInventory(self.player), button)
    end

    if button == Joypad.RBumper then
        local lootPage = getPlayerLoot(self.player)
        if Reorder.canSortBackpacks(lootPage) then
            return onJoypadDown(self, lootPage, button)
        end
    end

    return _old_onJoypadDown(self, button)
end
