local Helpers = require("BetterContainers/Helpers")
local Options = require("BetterContainers/_Options")

local Proximity = {}

Proximity.invName           = "proximityInv"
Proximity.invName_corpses   = "twistInv_corpses"

-- Icons and Containers
Proximity.corpseIcon = getTexture("media/ui/BetterContainers/Proximity/zombie.png")
Proximity.inventoryIcon = getTexture("media/ui/BetterContainers/Proximity/inventory.png")
Proximity.forceSelectIcon = getTexture("media/ui/Panel_Icon_Pin.png")
Proximity.corpseContainer = {}
Proximity.itemContainer = {}
Proximity.inventoryButtonRef = {}
Proximity.corpseInventoryButtonRef = {}
Proximity.isForceSelected = {}
Proximity.forceSelectedType = {}
Proximity._ForceSwitchIntent = {}
Proximity._LastBrowseMs = {}
Proximity._lastBrowseGraceMs = 10000

local function _isHumanContainer(containerType)
    return containerType == "inventoryfemale"
        or containerType == "inventorymale"
end

function Proximity.HasNearbyCorpses(invSelf)
    if not invSelf or not invSelf.backpacks then return false end
    for i = 1, #invSelf.backpacks do
        local inv = invSelf.backpacks[i] and invSelf.backpacks[i].inventory
        if inv then
            local t = inv:getType()
            if _isHumanContainer(t) then
                return true
            end
        end
    end
    return false
end

function Proximity.GetItemContainer(playerNum)
    if Proximity.itemContainer[playerNum] then
        return Proximity.itemContainer[playerNum]
    end
    local iContainer = ItemContainer.new(Proximity.invName, nil, nil)
    iContainer:setExplored(true)
    iContainer:setOnlyAcceptCategory("none")
    iContainer:setCapacity(0)
    Proximity.itemContainer[playerNum] = iContainer
    return iContainer
end

function Proximity.GetCurrentForceContainer(playerNum)
    local forceType = Proximity.forceSelectedType[playerNum] or Proximity.invName
    if forceType == Proximity.invName then
        return Proximity.GetItemContainer(playerNum)
    elseif forceType == Proximity.invName_corpses then
        return Proximity.GetCorpseContainer(playerNum)
    end
    return Proximity.GetItemContainer(playerNum)
end

local function _isProximityType(invType)
    return invType == Proximity.invName or invType == Proximity.invName_corpses
end

function Proximity.ForceSelectContainer(page, invType)
    if Proximity.isTransferActive(page.player) then return end
    if _isProximityType(invType) then
        page.tempForceSelectUnlock = false
        Proximity._ForceSwitchIntent[page.player] = invType
    else
        page.tempForceSelectUnlock = true

        -- Release any pending re-force and vanilla's 1s container hold,
        -- otherwise the first click can be overridden by updateContainer().
        Proximity._ForceSwitchIntent[page.player] = nil
        page.forceSelectedContainer = nil
        page.forceSelectedContainerTime = 0
        Proximity._LastBrowseMs[page.player] = getTimestampMs()
    end
end

local old_addContainerButton = ISInventoryPage.addContainerButton
function ISInventoryPage:addContainerButton(container, texture, name, tooltip, ...)
    local btn = old_addContainerButton(self, container, texture, name, tooltip, ...)
    if not btn then return btn end

    local oldOnClick = btn.onclick
    btn.onclick = function(button, x, y)
        local eff = Options.getEffectivePermissions() or {}
        if eff.proximityActive and eff.autoLock then
            local invType = button and button.inventory and button.inventory:getType() or nil
            Proximity.ForceSelectContainer(self, invType)
        end

        if type(oldOnClick) == "function" then
            return oldOnClick(button, x, y)
        end
    end

    return btn
end

local old_selectContainer = ISInventoryPage.selectContainer
function ISInventoryPage:selectContainer(button, ...)
    local eff = Options.getEffectivePermissions() or {}
    if eff.proximityActive and eff.autoLock then
        local invType = button and button.inventory and button.inventory:getType() or nil
        Proximity.ForceSelectContainer(self, invType)
    end

    return old_selectContainer(self, button, ...)
end

function Proximity.GetCorpseContainer(playerNum)
    if Proximity.corpseContainer[playerNum] then
        return Proximity.corpseContainer[playerNum]
    end
    local cContainer = ItemContainer.new(Proximity.invName_corpses, nil, nil)
    cContainer:setExplored(true)
    cContainer:setOnlyAcceptCategory("none")
    cContainer:setCapacity(0)
    Proximity.corpseContainer[playerNum] = cContainer
    return cContainer
end

function Proximity.AddProximityInventoryButton(invSelf)
    local eff = Options.getEffectivePermissions() or {}
    local corpseOnly = eff.corpseOnly == true

    local proximityInvButton = nil
    local corpseButton = nil

    if corpseOnly then
        local corpseContainer = Proximity.GetCorpseContainer(invSelf.player)
        corpseContainer:clear()
        local corpseTitle = getText("IGUI_BC_Proximity_CorpseName")
        corpseButton = invSelf:addContainerButton(
            corpseContainer,
            Proximity.corpseIcon,
            corpseTitle
        )
    else
        local itemContainer = Proximity.GetItemContainer(invSelf.player)
        itemContainer:clear()
        local title = getText("IGUI_BC_Proximity_InventoryName")
        if getSpecificPlayer(invSelf.player):getVehicle() then
            title = title .. " - " .. getText("GameSound_Category_Vehicle")
        end

        proximityInvButton = invSelf:addContainerButton(
            itemContainer,
            Proximity.inventoryIcon,
            title
        )
    end

    return proximityInvButton, corpseButton
end

function Proximity.OnBeginRefresh(invSelf)
    local eff = Options.getEffectivePermissions() or {}
    if not eff.proximityActive then return end

    local proximityInvButton, corpseInvButton = Proximity.AddProximityInventoryButton(invSelf)
    Proximity.inventoryButtonRef[invSelf.player] = proximityInvButton
    Proximity.corpseInventoryButtonRef[invSelf.player] = corpseInvButton

end

function Proximity.DoRightClickMenu(self, x, y)
    local eff = Options.getEffectivePermissions() or {}
    if not eff.proximityActive then return end

    local inv = self and self.inventory
    local invType = inv and inv:getType() or nil
    if not _isProximityType(invType) then return end

    local playerNum = self.player
    local context = ISContextMenu.get(playerNum, getMouseX(), getMouseY())
    if not context then return end

    -- Lock / Unlock (only when manual lock allowed)
    if not eff.autoLock and eff.allowToggleLock then
        local locked = Proximity.isForceSelected[playerNum] and true or false
        local text = locked
            and (getTextOrNull("UI_BetterContainers_Unlock") or "Unlock")
            or (getTextOrNull("UI_BetterContainers_Lock") or "Lock")

        context:addOption(text, self, function()
            Proximity.DoOptionPress(Options.forceProximityLockKeybind)
        end)
    end

    -- Auto Lock toggle
    if eff.allowToggleAutoLock then
        local autoText = eff.autoLock
            and (getTextOrNull("UI_BetterContainers_Options_disableAutoLock") or "Disable Auto-Lock")
            or (getTextOrNull("UI_BetterContainers_Options_enableAutoLock") or "Enable Auto-Lock")

        context:addOption(autoText, self, function()
            Proximity.DoOptionPress(Options.autoLockKeybind, self)
        end)
    end
end

function Proximity.OnButtonsAdded(invSelf)
    local eff = Options.getEffectivePermissions() or {}

    local proximityInvButtonRef  = Proximity.inventoryButtonRef[invSelf.player]
    local corpseInvButtonRef = Proximity.corpseInventoryButtonRef[invSelf.player]
    if not proximityInvButtonRef and not corpseInvButtonRef then return end

    if not eff.proximityActive then return end

    local playerNum = invSelf.player

    local corpseOnly = eff.corpseOnly == true
    local hasCorpsesNearby = corpseOnly and Proximity.HasNearbyCorpses(invSelf) or false

    -- Decide whether we should force at all, and which target we'd force to.
    local policyForce = eff.autoLock == true
    local shouldForce
    if policyForce then
        shouldForce = true
    else
        shouldForce = (Proximity.isForceSelected[playerNum] and true or false)
    end

    local targetType = Proximity.forceSelectedType[playerNum]
    if policyForce and not targetType then
        targetType = (eff.corpseOnly == true) and Proximity.invName_corpses or Proximity.invName
    end

    if corpseOnly then
        if hasCorpsesNearby then
            targetType = Proximity.invName_corpses
        else
            -- In corpse-only mode with autolock OFF, allow normal browsing when no corpses exist.
            -- With autolock ON (policyForce), we must still be able to snap back.
            if not policyForce then
                shouldForce = false
            end
        end
    end

    -- If autolock is enabled, respect tempForceSelectUnlock (let the player browse other containers).
    local autolockUnlock = (eff.autoLock == true) and (invSelf.tempForceSelectUnlock == true)

    if shouldForce and not autolockUnlock then
        Proximity.forceSelectedType[playerNum] = targetType
        invSelf:setForceSelectedContainer(Proximity.GetCurrentForceContainer(playerNum))
    end

    local locked = (eff.autoLock == true) or (Proximity.isForceSelected[playerNum] and true or false)

    local function consumeRightClick(_self, _x, _y)
        Proximity.DoRightClickMenu(_self, _x, _y)
        return true
    end

    if proximityInvButtonRef then
        proximityInvButtonRef.textureOverride = locked and Proximity.forceSelectIcon or nil
        proximityInvButtonRef.inventory:getItems():clear()
        proximityInvButtonRef.onRightMouseDown = consumeRightClick
    end
    if corpseInvButtonRef then
        corpseInvButtonRef.textureOverride = locked and Proximity.forceSelectIcon or nil
        corpseInvButtonRef.inventory:getItems():clear()
        corpseInvButtonRef.onRightMouseDown = consumeRightClick
    end

    for i = 1, #invSelf.backpacks do
        local btn = invSelf.backpacks[i]
        local invToAdd = btn and btn.inventory
        if invToAdd then
            local invType = invToAdd:getType()

            -- Never merge from our own collector containers (future-proof + avoids edge duplication)
            if invType ~= Proximity.invName and invType ~= Proximity.invName_corpses then
                local items = invToAdd:getItems()

                if corpseOnly then
                    if corpseInvButtonRef and _isHumanContainer(invType) then
                        corpseInvButtonRef.inventory:getItems():addAll(items)
                    end
                else
                    if proximityInvButtonRef then
                        proximityInvButtonRef.inventory:getItems():addAll(items)
                    end
                    if corpseInvButtonRef and _isHumanContainer(invType) then
                        corpseInvButtonRef.inventory:getItems():addAll(items)
                    end
                end
            end
        end
    end
end

function Proximity.updateForceSelected(playerNum, state)
    local eff = Options.getEffectivePermissions() or {}

    if not eff.proximityActive then
        --Proximity.isForceSelected[playerNum] = false
        --Proximity.forceSelectedType[playerNum] = nil
        Proximity._ForceSwitchIntent[playerNum] = nil
    else
        if eff.autoLock ~= true then
            Proximity.isForceSelected[playerNum] = state
        end
        Proximity.forceSelectedType[playerNum] = (eff.corpseOnly == true) and Proximity.invName_corpses or Proximity.invName
    end
    ISInventoryPage.dirtyUI()
end

Events[Helpers.OPTIONS_APPLIED].Add(function()
    for playerNum = 0, getNumActivePlayers() - 1 do
        Proximity.updateForceSelected(playerNum, Proximity.isForceSelected[playerNum])
    end
end)

function Proximity.OnToggleAutoLock(playerNum)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local lootWindow = getPlayerLoot and getPlayerLoot(playerNum)
    local page = lootWindow and lootWindow.inventoryPane and lootWindow.inventoryPane.inventoryPage or nil
    if not page then return end

    if _isProximityType(page.inventory:getType()) then
        -- Already viewing proximity/corpses
        return
    end

    local text = getTextOrNull("IGUI_BC_Proximity_ForceSelectAutoLock") or "Auto-Lock Active"
    HaloTextHelper.addText(player, text, "", HaloTextHelper.getColorWhite())

    Proximity.DoAutoLock(playerNum, page, true) -- immediate restore
    ISInventoryPage.dirtyUI()
end

function Proximity.OnToggleForceSelected(playerNum)
    local eff = Options.getEffectivePermissions() or {}
    if not eff.proximityActive then return end

    if eff.autoLock then
        Proximity.OnToggleAutoLock(playerNum)
        return
    end

    if not eff.allowToggleLock then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    Proximity.updateForceSelected(playerNum, not Proximity.isForceSelected[playerNum])
    local text = Proximity.isForceSelected[playerNum]
        and getText("IGUI_BC_Proximity_ForceSelectOn")
        or getText("IGUI_BC_Proximity_ForceSelectOff")
    HaloTextHelper.addText(player, text, "", HaloTextHelper.getColorWhite())
end

Proximity.DoOptionPress = function(key, page)
    local player = getPlayer() or getSpecificPlayer(0)
    if not player then return end
    local playerNum = player:getPlayerNum()

    local eff = Options.getEffectivePermissions() or {}

    if key == Options.forceProximityLockKeybind and eff.allowToggleLock then
        Proximity.OnToggleForceSelected(playerNum)
        return
    end

    if key == Options.enableProximityKeybind and eff.allowToggleProximity then
        Options.OnToggle()
        Proximity.updateForceSelected(playerNum, Proximity.isForceSelected[playerNum])
        return
    end

    if key == Options.corpseOnlyModeKeybind and eff.allowSwitchMode then
        Options.OnToggleMode()
        Proximity.updateForceSelected(playerNum, Proximity.isForceSelected[playerNum])
        return
    end

    if key == Options.autoLockKeybind and eff.allowToggleAutoLock and page then
        Options.OnToggleAutoLock()
        Proximity.OnToggleAutoLock(playerNum)
        return
    end
end

Events.OnRefreshInventoryWindowContainers.Add(function(invSelf, state)
    local eff = Options.getEffectivePermissions() or {}
    if not eff.proximityActive or invSelf.onCharacter then return end

    if state == "begin" then
        return Proximity.OnBeginRefresh(invSelf)
    end

    if state == "buttonsAdded" then
        return Proximity.OnButtonsAdded(invSelf)
    end
end)

local ISCraftingUI_getContainers = ISCraftingUI.getContainers
function ISCraftingUI:getContainers()
    ISCraftingUI_getContainers(self)
    if not self.character or not self.containerList then return end

    local proximityInvContainer = Proximity.itemContainer[self.playerNum]
    if proximityInvContainer then
        self.containerList:remove(proximityInvContainer)
    end

    local corpseInvContainer = Proximity.corpseContainer[self.playerNum]
    if corpseInvContainer then
        self.containerList:remove(corpseInvContainer)
    end
end

local ISInventoryPaneContextMenu_getContainers = ISInventoryPaneContextMenu.getContainers
ISInventoryPaneContextMenu.getContainers = function(character)
    local containerList = ISInventoryPaneContextMenu_getContainers(character)
    if not containerList or not character then return containerList end

    local playerNum = character:getPlayerNum()

    local proximityInvContainer = Proximity.itemContainer[playerNum]
    if proximityInvContainer then
        containerList:remove(proximityInvContainer)
    end

    local corpseInvContainer = Proximity.corpseContainer[playerNum]
    if corpseInvContainer then
        containerList:remove(corpseInvContainer)
    end

    return containerList
end

local vanillaHoveredItems = {}
local function getVanillaHoveredItem(playerNum)
    local t = vanillaHoveredItems[playerNum]
    if not t then
        t = {}
        vanillaHoveredItems[playerNum] = t
    end
    return t
end

local proximityHoveredItems = {}
local function getProximityHoveredItem(playerNum)
    local t = proximityHoveredItems[playerNum]
    if not t then
        t = {}
        proximityHoveredItems[playerNum] = t
    end
    return t
end

local _old_clearWorldObjectHighlights = ISInventoryPane.clearWorldObjectHighlights
function ISInventoryPane:clearWorldObjectHighlights()
    local held = getProximityHoveredItem(self.player)

    for worldItem in pairs(self.highlightItems) do
        getVanillaHoveredItem(self.player)[worldItem] = nil

        -- If Proximity owns this highlight, remove it so vanilla won't unhighlight it.
        if held[worldItem] then
            self.highlightItems[worldItem] = nil
        end
    end

    return _old_clearWorldObjectHighlights(self)
end

local _old_doWorldObjectHighlight = ISInventoryPane.doWorldObjectHighlight
function ISInventoryPane:doWorldObjectHighlight(_item)
    --attempt to find the world item, if it doesn't exist we assume it's not on the floor
    if instanceof(_item, "InventoryItem") then
        local worldItem = _item:getWorldItem();
        if (worldItem and worldItem:getChunk() ~= nil) then
            --found the world item, highlight and keep track of it
            getVanillaHoveredItem(self.player)[worldItem] = worldItem;
        end
    end

    return _old_doWorldObjectHighlight(self, _item);
end

local function clearProximityHighlights(page)
    if not page.coloredProximityInventories then return end

    for container in pairs(page.coloredProximityInventories) do
        local selectedContainer = page.coloredInv
        if container ~= selectedContainer then
            local parent = page:getContainerParent(container)
            if parent then
                local isWorldParent = instanceof(parent, "IsoWorldInventoryObject")
                if not (isWorldParent and getVanillaHoveredItem(page.player)[parent]) then
                    parent:setHighlighted(page.player, false)
                    parent:setOutlineHighlight(page.player, false)
                    parent:setOutlineHlAttached(page.player, false)
                end
                if isWorldParent then
                    getProximityHoveredItem(page.player)[parent] = nil
                end
            end
            page.coloredProximityInventories[container] = nil
        end
    end
end

-- TRANSFER AUTHORITY

Proximity._LastTransfer = {}

local function _setTransferRunning(playerNum, isRunning)
    if not playerNum then return end
    Proximity._TransferRunning = Proximity._TransferRunning or {}
    if isRunning then
        Proximity._TransferRunning[playerNum] = true
    else
        Proximity._TransferRunning[playerNum] = nil
    end
    Proximity._LastBrowseMs[playerNum] = getTimestampMs()
end

local old_ISInventoryTransferAction_start = ISInventoryTransferAction.start
function ISInventoryTransferAction:start(...)
    local playerNum = self.character and self.character:getPlayerNum()

    if playerNum ~= nil then
        _setTransferRunning(playerNum, true)
    end

    if old_ISInventoryTransferAction_start then
        return old_ISInventoryTransferAction_start(self, ...)
    end
end

local old_ISInventoryTransferAction_perform = ISInventoryTransferAction.perform
function ISInventoryTransferAction:perform(...)
    local playerNum = self.character and self.character:getPlayerNum()

    local ret
    if old_ISInventoryTransferAction_perform then ret = old_ISInventoryTransferAction_perform(self, ...) end

    -- Vanilla sets started=false only when it really finishes (after ISBaseTimedAction.perform).
    if playerNum ~= nil and self.started == false then
        _setTransferRunning(playerNum, false)
    end

    return ret
end

local old_ISInventoryTransferAction_stop = ISInventoryTransferAction.stop
function ISInventoryTransferAction:stop(...)
    local playerNum = self.character and self.character:getPlayerNum()

    if playerNum ~= nil then
        _setTransferRunning(playerNum, false)
    end

    if old_ISInventoryTransferAction_stop then
        return old_ISInventoryTransferAction_stop(self, ...)
    end
end

function Proximity.isTransferActive(playerNum)
    local transferRunning = Proximity._TransferRunning and Proximity._TransferRunning[playerNum] or false
    return transferRunning
end

--  TRANSFER AUTHORITY END

function Proximity.DoAutoLock(playerNum, page, queue)
    local eff = Options.getEffectivePermissions() or {}
    if not (eff.proximityActive and eff.autoLock) then return false end
    if Proximity.isTransferActive(playerNum) then return false end
    if not page then return false end

    local defaultType = (eff.corpseOnly == true)
        and Proximity.invName_corpses
        or Proximity.invName

    if not Proximity.forceSelectedType[playerNum] then
        Proximity.forceSelectedType[playerNum] = defaultType
    end

    if queue == true then
        page.tempForceSelectUnlock = false
        Proximity._ForceSwitchIntent[playerNum] = Proximity.forceSelectedType[playerNum]
        return true
    end

    -- update() path: only attempt snapback when temp-unlocked
    if eff.proximityActive and eff.autoLock and page.tempForceSelectUnlock then
        local proxInv = Proximity.itemContainer[playerNum] or Proximity.GetItemContainer(playerNum)
        local corpseInv = Proximity.corpseContainer[playerNum] -- may be nil

        local foundOther = false
        for i = 1, #page.backpacks do
            local entry = page.backpacks[i]
            local inv = entry and entry.inventory
            if inv
                and inv ~= proxInv
                and (not corpseInv or inv ~= corpseInv)
                and inv:getType() ~= "floor"
            then
                foundOther = true
                break
            end
        end

        if not foundOther then
            page.tempForceSelectUnlock = false
            Proximity._ForceSwitchIntent[playerNum] = Proximity.forceSelectedType[playerNum]
            return true
        end
    end

    return false
end

local old_ISInventoryPage_update = ISInventoryPage.update
function ISInventoryPage:update()
    old_ISInventoryPage_update(self)
    local playerNum = self.player

    local eff = Options.getEffectivePermissions() or {}

    if Proximity._ForceSwitchIntent[playerNum] then
        -- If proximity isn't active, discard pending intent.
        if not eff.proximityActive then
            Proximity._ForceSwitchIntent[playerNum] = nil
        else
            local target = Proximity._ForceSwitchIntent[playerNum]
            Proximity.forceSelectedType[playerNum] = target

            -- Only ever force the lock if effective autolock is enabled.
            local manualForce = Proximity.isForceSelected[playerNum] and true or false
            local policyForce = eff.autoLock == true
            local forceWanted = (manualForce or policyForce)

            -- Under autolock, respect tempForceSelectUnlock.
            local autolockUnlock = policyForce and self.tempForceSelectUnlock

            if forceWanted and not autolockUnlock then
                self:setForceSelectedContainer(Proximity.GetCurrentForceContainer(playerNum))
            end

            Proximity._ForceSwitchIntent[playerNum] = nil
            return
        end
    end

    Proximity.DoAutoLock(playerNum, self, false)

    -- Highlighting

    if not eff.proximityActive or self.onCharacter then
        clearProximityHighlights(self)
        return
    end

    local invType = self.inventory:getType()
    if not Options.enableProximityHighlight
        or self.isCollapsed
        or (invType ~= Proximity.invName and invType ~= Proximity.invName_corpses)
    then
        clearProximityHighlights(self)
        return
    end

    -- Ensure tracking table exists
    self.coloredProximityInventories = self.coloredProximityInventories or {}

    -- Reset highlights (important after refresh)
    clearProximityHighlights(self)

    -- Cache highlight color once
    local hl = getCore():getObjectHighlitedColor()
    local hlR, hlG, hlB = hl:getR(), hl:getG(), hl:getB()

    -- Set Highlights for objects/corpses
    local corpseOnly = eff.corpseOnly == true

    for i = 1, #self.backpacks do
        local entry = self.backpacks[i]
        local container = entry and entry.inventory
        if container then
            -- In corpseOnly mode, only highlight actual corpse inventories.
            local highlightType = container:getType()
            if corpseOnly and not _isHumanContainer(highlightType) then
                -- skip non-corpse containers (crates, cupboards, etc.)
            else
                local parent = self:getContainerParent(container)
                if parent then
                    local isWorldParent = instanceof(parent, "IsoWorldInventoryObject")
                    local vanillaOwns = isWorldParent and getVanillaHoveredItem(playerNum)[parent]

                    self.coloredProximityInventories[container] = true

                    if isWorldParent then
                        getProximityHoveredItem(playerNum)[parent] = true
                    end

                    if not vanillaOwns then
                        parent:setHighlighted(playerNum, true, false)
                        parent:setHighlightColor(playerNum, hl)

                        if instanceof(parent, "IsoObject") and not instanceof(parent, "IsoDeadBody") then
                            parent:setOutlineHighlight(playerNum, true)
                            parent:setOutlineHlAttached(playerNum, true)
                            parent:setOutlineHighlightCol(playerNum, hlR, hlG, hlB, 1)
                        end
                    end
                end
            end
        end
    end
end

local function _autolockFailsafeEveryTenMinutes()
    local eff = Options.getEffectivePermissions() or {}
    if not (eff.proximityActive and eff.autoLock) then return end

    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player then
            local last = Proximity._LastBrowseMs[playerNum] or 0
            local now = getTimestampMs()
            local remaining = (now - last)
            if last > 0 and remaining < Proximity._lastBrowseGraceMs then
                -- Do Nothing for this player
                Helpers.dlog("Don't snapback yet: " .. tostring(remaining) .. "ms remaining.")
            else
                local lootWindow = getPlayerLoot and getPlayerLoot(playerNum)
                local page = lootWindow and lootWindow.inventoryPane and lootWindow.inventoryPane.inventoryPage or nil
                if page then
                    Helpers.dlog("Snap Back Now!")
                    Proximity.DoAutoLock(playerNum, page, true)
                else
                    Helpers.dlog("Failed Snap Back.")
                end
            end
        end
    end

    ISInventoryPage.dirtyUI()
end

Events.EveryTenMinutes.Add(_autolockFailsafeEveryTenMinutes)

-- Keybinds
Events.OnKeyPressed.Add(Proximity.DoOptionPress)

return Proximity
