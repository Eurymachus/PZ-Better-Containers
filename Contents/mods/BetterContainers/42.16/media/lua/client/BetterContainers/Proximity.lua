local Helpers = require("BetterContainers/Helpers")
local Options = require("BetterContainers/_Options")

local Proximity = {}

Proximity.invName = "proximityInv"
Proximity.invName_corpses = "twistInv_corpses"

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
Proximity._LastTransfer = {}
Proximity._TransferRunning = {}

function Proximity.isHumanContainer(containerType)
    return containerType == "inventoryfemale"
        or containerType == "inventorymale"
end

function Proximity.isProximityType(invType)
    return invType == Proximity.invName or invType == Proximity.invName_corpses
end

function Proximity.HasNearbyCorpses(invSelf)
    if not invSelf or not invSelf.backpacks then return false end

    for i = 1, #invSelf.backpacks do
        local inv = invSelf.backpacks[i] and invSelf.backpacks[i].inventory
        if inv then
            local t = inv:getType()
            if Proximity.isHumanContainer(t) then
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

function Proximity.GetCurrentForceContainer(playerNum)
    local forceType = Proximity.forceSelectedType[playerNum] or Proximity.invName

    if forceType == Proximity.invName then
        return Proximity.GetItemContainer(playerNum)
    elseif forceType == Proximity.invName_corpses then
        return Proximity.GetCorpseContainer(playerNum)
    end

    return Proximity.GetItemContainer(playerNum)
end

function Proximity.ForceSelectContainer(page, invType)
    if not page then return end
    if Proximity.isTransferActive(page.player) then return end

    if Proximity.isProximityType(invType) then
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
    if not Proximity.isProximityType(invType) then return end

    local playerNum = self.player
    local context = ISContextMenu.get(playerNum, getMouseX(), getMouseY())
    if not context then return end

    if not eff.autoLock and eff.allowToggleLock then
        local locked = Proximity.isForceSelected[playerNum] and true or false
        local text = locked
            and (getTextOrNull("UI_BetterContainers_Unlock") or "Unlock")
            or (getTextOrNull("UI_BetterContainers_Lock") or "Lock")

        context:addOption(text, self, function()
            Proximity.DoOptionPress(Options.forceProximityLockKeybind)
        end)
    end

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

    local proximityInvButtonRef = Proximity.inventoryButtonRef[invSelf.player]
    local corpseInvButtonRef = Proximity.corpseInventoryButtonRef[invSelf.player]
    if not proximityInvButtonRef and not corpseInvButtonRef then return end

    if not eff.proximityActive then return end

    local playerNum = invSelf.player
    local corpseOnly = eff.corpseOnly == true
    local hasCorpsesNearby = corpseOnly and Proximity.HasNearbyCorpses(invSelf) or false

    local policyForce = eff.autoLock == true
    local shouldForce
    if policyForce then
        shouldForce = true
    else
        shouldForce = Proximity.isForceSelected[playerNum] and true or false
    end

    local targetType = Proximity.forceSelectedType[playerNum]
    if policyForce and not targetType then
        targetType = corpseOnly and Proximity.invName_corpses or Proximity.invName
    end

    if corpseOnly then
        if hasCorpsesNearby then
            targetType = Proximity.invName_corpses
        else
            if not policyForce then
                shouldForce = false
            end
        end
    end

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

            if invType ~= Proximity.invName and invType ~= Proximity.invName_corpses then
                local items = invToAdd:getItems()

                if corpseOnly then
                    if corpseInvButtonRef and Proximity.isHumanContainer(invType) then
                        corpseInvButtonRef.inventory:getItems():addAll(items)
                    end
                else
                    if proximityInvButtonRef then
                        proximityInvButtonRef.inventory:getItems():addAll(items)
                    end
                    if corpseInvButtonRef and Proximity.isHumanContainer(invType) then
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
        Proximity._ForceSwitchIntent[playerNum] = nil
    else
        if eff.autoLock ~= true then
            Proximity.isForceSelected[playerNum] = state
        end
        Proximity.forceSelectedType[playerNum] = (eff.corpseOnly == true)
            and Proximity.invName_corpses
            or Proximity.invName
    end

    ISInventoryPage.dirtyUI()
end

function Proximity.OnOptionsApplied()
    for playerNum = 0, getNumActivePlayers() - 1 do
        Proximity.updateForceSelected(playerNum, Proximity.isForceSelected[playerNum])
    end
end

function Proximity.OnToggleAutoLock(playerNum)
    local player = getSpecificPlayer(playerNum)
    if not player then return end

    local lootWindow = getPlayerLoot and getPlayerLoot(playerNum)
    local page = lootWindow and lootWindow.inventoryPane and lootWindow.inventoryPane.inventoryPage or nil
    if not page then return end

    if Proximity.isProximityType(page.inventory:getType()) then
        return
    end

    local text = getTextOrNull("IGUI_BC_Proximity_ForceSelectAutoLock") or "Auto-Lock Active"
    HaloTextHelper.addText(player, text, "", HaloTextHelper.getColorWhite())

    Proximity.DoAutoLock(playerNum, page, true)
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

function Proximity.setTransferRunning(playerNum, isRunning)
    if playerNum == nil then return end

    if isRunning then
        Proximity._TransferRunning[playerNum] = true
    else
        Proximity._TransferRunning[playerNum] = nil
    end

    Proximity._LastBrowseMs[playerNum] = getTimestampMs()
end

function Proximity.isTransferActive(playerNum)
    return Proximity._TransferRunning and Proximity._TransferRunning[playerNum] or false
end

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

    if eff.proximityActive and eff.autoLock and page.tempForceSelectUnlock then
        local proxInv = Proximity.itemContainer[playerNum] or Proximity.GetItemContainer(playerNum)
        local corpseInv = Proximity.corpseContainer[playerNum]

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

function Proximity.OnAutolockFailsafeEveryTenMinutes()
    local eff = Options.getEffectivePermissions() or {}
    if not (eff.proximityActive and eff.autoLock) then return end

    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player then
            local last = Proximity._LastBrowseMs[playerNum] or 0
            local now = getTimestampMs()
            local remaining = now - last

            if last > 0 and remaining < Proximity._lastBrowseGraceMs then
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

Proximity._vanillaHoveredItems = {}
Proximity._proximityHoveredItems = {}

function Proximity.getVanillaHoveredItem(playerNum)
    local t = Proximity._vanillaHoveredItems[playerNum]
    if not t then
        t = {}
        Proximity._vanillaHoveredItems[playerNum] = t
    end
    return t
end

function Proximity.getProximityHoveredItem(playerNum)
    local t = Proximity._proximityHoveredItems[playerNum]
    if not t then
        t = {}
        Proximity._proximityHoveredItems[playerNum] = t
    end
    return t
end

Proximity._installed = false
Proximity._eventsInstalled = false

Proximity.install = function()
    if Proximity._installed then return end
    Proximity._installed = true

    local ProximityInventoryPane = require("BetterContainers/Proximity/Proximity_ISInventoryPane")
    local ProximityInventoryPage = require("BetterContainers/Proximity/Proximity_ISInventoryPage")
    local ProximityLootWindowControls = require("BetterContainers/Proximity/Proximity_ISLootWindowContainerControls")
    local ProximityTransferAction = require("BetterContainers/Proximity/Proximity_ISInventoryTransferAction")

    -- Install Proximity hooks explicitly after all files have loaded.
    -- Reorder already patches ISInventoryPage during file load, so installing
    -- Proximity here makes it wrap the final Reorder-owned page methods.
    ProximityInventoryPane.install()
    ProximityInventoryPage.install()
    ProximityLootWindowControls.install()
    ProximityTransferAction.install()

    if not Proximity._eventsInstalled then
        Proximity._eventsInstalled = true

        Events[Helpers.OPTIONS_APPLIED].Add(function()
            Proximity.OnOptionsApplied()
        end)

        Events.EveryTenMinutes.Add(function()
            Proximity.OnAutolockFailsafeEveryTenMinutes()
        end)

        Events.OnKeyPressed.Add(function(key)
            Proximity.DoOptionPress(key)
        end)
    end
end

return Proximity