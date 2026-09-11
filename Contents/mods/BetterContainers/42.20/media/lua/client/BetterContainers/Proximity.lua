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
Proximity._BrowseElapsedMs = {}
Proximity._LastTransfer = {}
Proximity._TransferRunning = {}
Proximity._HasNearbyCorpses = {}

function Proximity.isHumanContainer(containerType)
    return containerType == "inventoryfemale"
        or containerType == "inventorymale"
end

function Proximity.isProximityType(invType)
    return invType == Proximity.invName or invType == Proximity.invName_corpses
end

function Proximity.isHumanCorpseContainer(container)
    local parent = container and container.getParent and container:getParent() or nil
    if not parent or not instanceof(parent, "IsoDeadBody") then return false end
    return not parent:isAnimal()
end

function Proximity.shouldHideIndividualCorpseContainers(eff)
    eff = eff or Options.getEffectivePermissions() or {}
    return eff.proximityActive == true
        and eff.hideIndividualCorpseContainers == true
        and (eff.corpseOnly == true or eff.dualMode == true)
end

function Proximity.isLockedForPlayer(container, playerObj)
    local parent = container and container.getParent and container:getParent() or nil
    return parent ~= nil
        and playerObj ~= nil
        and instanceof(parent, "IsoThumpable")
        and parent:isLockedToCharacter(playerObj)
end

function Proximity.HasNearbyCorpseButtons(invSelf)
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

function Proximity.HasNearbyCorpses(invSelf)
    if not invSelf then return false end

    if Proximity.HasNearbyCorpseButtons(invSelf) then
        return true
    end

    local eff = Options.getEffectivePermissions() or {}
    if Proximity.shouldHideIndividualCorpseContainers(eff) then
        return Proximity._HasNearbyCorpses[invSelf.player] == true
    end

    return false
end

function Proximity.HideIndividualCorpseButtons(invSelf)
    local eff = Options.getEffectivePermissions() or {}
    if not Proximity.shouldHideIndividualCorpseContainers(eff) then return end
    if not invSelf or invSelf.onCharacter or not invSelf.backpacks then return end

    invSelf.buttonPool = invSelf.buttonPool or {}
    invSelf.bcHiddenCorpseContainers = invSelf.bcHiddenCorpseContainers or {}
    for index = #invSelf.backpacks, 1, -1 do
        local button = invSelf.backpacks[index]
        if button and Proximity.isHumanCorpseContainer(button.inventory) then
            table.insert(invSelf.bcHiddenCorpseContainers, button.inventory)
            invSelf.containerButtonPanel:removeChild(button)
            table.remove(invSelf.backpacks, index)
            table.insert(invSelf.buttonPool, button)
        end
    end
end

function Proximity.GetPreferredType(eff, invSelf)
    eff = eff or Options.getEffectivePermissions() or {}

    if eff.corpseOnly == true then
        return Proximity.invName_corpses
    end

    if eff.dualMode == true and Proximity.HasNearbyCorpses(invSelf) then
        return Proximity.invName_corpses
    end

    return Proximity.invName
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

    local eff = Options.getEffectivePermissions() or {}
    local preferredType = Proximity.GetPreferredType(eff, page)
    local browsingAlternateAggregate = eff.dualMode == true
        and Proximity.isProximityType(invType)
        and invType ~= preferredType

    if browsingAlternateAggregate then
        page.tempForceSelectUnlock = true
        Proximity._ForceSwitchIntent[page.player] = nil
        page.forceSelectedContainer = nil
        page.forceSelectedContainerTime = 0
        Proximity._BrowseElapsedMs[page.player] = 0
        return
    end

    if Proximity.isProximityType(invType) then
        page.tempForceSelectUnlock = false
        Proximity._BrowseElapsedMs[page.player] = nil
        Proximity._ForceSwitchIntent[page.player] = invType
    else
        page.tempForceSelectUnlock = true

        -- Release any pending re-force and vanilla's 1s container hold,
        -- otherwise the first click can be overridden by updateContainer().
        Proximity._ForceSwitchIntent[page.player] = nil
        page.forceSelectedContainer = nil
        page.forceSelectedContainerTime = 0
        Proximity._BrowseElapsedMs[page.player] = 0
    end
end

function Proximity.AddProximityInventoryButton(invSelf)
    local eff = Options.getEffectivePermissions() or {}
    local corpseOnly = eff.corpseOnly == true
    local showDualCorpseButton = eff.dualMode == true and (
        eff.showCorpsesOnlyWhenNearby ~= true
        or Proximity._HasNearbyCorpses[invSelf.player] ~= false
    )

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

        if showDualCorpseButton then
            local corpseContainer = Proximity.GetCorpseContainer(invSelf.player)
            corpseContainer:clear()

            local corpseTitle = getText("IGUI_BC_Proximity_CorpseName")
            corpseButton = invSelf:addContainerButton(
                corpseContainer,
                Proximity.corpseIcon,
                corpseTitle
            )
        end
    end

    return proximityInvButton, corpseButton
end

function Proximity.OnBeginRefresh(invSelf)
    invSelf.bcProximityRefreshGeneration = (invSelf.bcProximityRefreshGeneration or 0) + 1
    invSelf.bcHiddenCorpseContainers = nil

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

    if invType == Proximity.invName_corpses then
        local corpseContainersText = eff.hideIndividualCorpseContainers
            and (getTextOrNull("UI_BetterContainers_ShowCorpseContainers") or "Show Corpse Containers")
            or (getTextOrNull("UI_BetterContainers_HideCorpseContainers") or "Hide Corpse Containers")

        context:addOption(corpseContainersText, self, function()
            Options.OnToggleHideIndividualCorpseContainers()
        end)
    end

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
    local refreshGeneration = invSelf.bcProximityRefreshGeneration
    local eff = Options.getEffectivePermissions() or {}

    local proximityInvButtonRef = Proximity.inventoryButtonRef[invSelf.player]
    local corpseInvButtonRef = Proximity.corpseInventoryButtonRef[invSelf.player]
    if not proximityInvButtonRef and not corpseInvButtonRef then return end

    if not eff.proximityActive then return end

    local playerNum = invSelf.player
    local playerObj = getSpecificPlayer(playerNum)
    local corpseOnly = eff.corpseOnly == true
    local dualMode = eff.dualMode == true
    local hasCorpsesNearby = (corpseOnly or dualMode) and Proximity.HasNearbyCorpseButtons(invSelf) or false
    local previousHasCorpses = Proximity._HasNearbyCorpses[playerNum]
    Proximity._HasNearbyCorpses[playerNum] = hasCorpsesNearby

    if dualMode and eff.showCorpsesOnlyWhenNearby then
        local corpseButtonVisible = corpseInvButtonRef ~= nil
        if previousHasCorpses ~= nil and corpseButtonVisible ~= hasCorpsesNearby then
            ISInventoryPage.dirtyUI()
        elseif previousHasCorpses == nil and not hasCorpsesNearby then
            ISInventoryPage.dirtyUI()
        end
    end

    -- dirtyUI can immediately rebuild the page and reassign pooled buttons.
    -- Let the nested refresh own its completed aggregation.
    if invSelf.bcProximityRefreshGeneration ~= refreshGeneration then
        return
    end

    local policyForce = eff.autoLock == true
    local shouldForce
    if policyForce then
        shouldForce = true
    else
        shouldForce = Proximity.isForceSelected[playerNum] and true or false
    end

    local targetType = Proximity.forceSelectedType[playerNum]
    if policyForce and not targetType then
        targetType = Proximity.GetPreferredType(eff, invSelf)
    end

    if dualMode and shouldForce and not invSelf.tempForceSelectUnlock then
        targetType = hasCorpsesNearby and Proximity.invName_corpses or Proximity.invName
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

    if invSelf.bcProximityRefreshGeneration ~= refreshGeneration then
        return
    end

    -- Verify ownership before modifying inventories through pooled buttons.
    if proximityInvButtonRef and proximityInvButtonRef.inventory ~= Proximity.itemContainer[playerNum] then
        proximityInvButtonRef = nil
    end
    if corpseInvButtonRef and corpseInvButtonRef.inventory ~= Proximity.corpseContainer[playerNum] then
        corpseInvButtonRef = nil
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
        if invToAdd and not Proximity.isLockedForPlayer(invToAdd, playerObj) then
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
        local lootWindow = getPlayerLoot and getPlayerLoot(playerNum)
        local page = lootWindow and lootWindow.inventoryPane and lootWindow.inventoryPane.inventoryPage or nil
        Proximity.forceSelectedType[playerNum] = Proximity.GetPreferredType(eff, page)
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

    local lootWindow = getPlayerLoot and getPlayerLoot(playerNum)
    local page = lootWindow and lootWindow.inventoryPane and lootWindow.inventoryPane.inventoryPage or nil
    local current = page and page.inventoryPane and page.inventoryPane.inventory or page and page.inventory or nil
    local currentType = current and current:getType() or nil

    if page and page.tempForceSelectUnlock and not Proximity.isProximityType(currentType) then
        Proximity._BrowseElapsedMs[playerNum] = 0
    else
        Proximity._BrowseElapsedMs[playerNum] = nil
    end
end

function Proximity.hasQueuedTransferAction(playerNum)
    if not ISTimedActionQueue then return false end

    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return false end

    local queue = ISTimedActionQueue.getTimedActionQueue(playerObj)
    local actions = queue and queue.queue
    if not actions then return false end

    for i = 1, #actions do
        local action = actions[i]
        if action and action.Type == "ISInventoryTransferAction" then
            return true
        end
    end

    return false
end

function Proximity.isTransferActive(playerNum)
    if not (Proximity._TransferRunning and Proximity._TransferRunning[playerNum]) then
        return false
    end

    if Proximity.hasQueuedTransferAction(playerNum) then
        return true
    end

    Proximity.setTransferRunning(playerNum, false)
    return false
end

function Proximity.DoAutoLock(playerNum, page, queue)
    local eff = Options.getEffectivePermissions() or {}
    if not (eff.proximityActive and eff.autoLock) then return false end
    if Proximity.isTransferActive(playerNum) then return false end
    if not page then return false end

    local preferredType = Proximity.GetPreferredType(eff, page)
    Proximity.forceSelectedType[playerNum] = preferredType

    local current = page.inventoryPane and page.inventoryPane.inventory or page.inventory
    local currentType = current and current:getType() or nil
    if currentType == preferredType then
        page.tempForceSelectUnlock = false
        Proximity._BrowseElapsedMs[playerNum] = nil
        Proximity._ForceSwitchIntent[playerNum] = nil
        return false
    end

    if queue == true then
        page.tempForceSelectUnlock = false
        Proximity._BrowseElapsedMs[playerNum] = nil
        Proximity._ForceSwitchIntent[playerNum] = Proximity.forceSelectedType[playerNum]
        return true
    end


    if Proximity.isProximityType(currentType) then
        if eff.dualMode == true and page.tempForceSelectUnlock then
            return false
        end

        page.tempForceSelectUnlock = false
        Proximity._BrowseElapsedMs[playerNum] = nil
        Proximity._ForceSwitchIntent[playerNum] = preferredType
        return true
    end

    if eff.proximityActive and eff.autoLock and page.tempForceSelectUnlock then
        local proxInv = Proximity.itemContainer[playerNum] or Proximity.GetItemContainer(playerNum)
        local corpseInv = Proximity.corpseContainer[playerNum]

        local currentAvailable = currentType == "floor"
        if not currentAvailable then
            for i = 1, #page.backpacks do
                local entry = page.backpacks[i]
                local inv = entry and entry.inventory
                if inv == current and inv ~= proxInv and (not corpseInv or inv ~= corpseInv) then
                    currentAvailable = true
                    break
                end
            end
        end

        if not currentAvailable then
            page.tempForceSelectUnlock = false
            Proximity._ForceSwitchIntent[playerNum] = Proximity.forceSelectedType[playerNum]
            return true
        end
    end

    return false
end

function Proximity.OnAutoLockTick()
    local eff = Options.getEffectivePermissions() or {}
    if not (eff.proximityActive and eff.autoLock) then return end
    if isGamePaused and isGamePaused() then return end

    local delaySeconds = tonumber(Options.autoLockDelaySeconds) or 10
    local delayMs = math.max(5, delaySeconds) * 1000
    local gameTime = getGameTime and getGameTime()
    local elapsedThisTickMs = gameTime and gameTime:getRealworldSecondsSinceLastUpdate() * 1000 or 0
    local snappedBack = false

    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player then
            local lootWindow = getPlayerLoot and getPlayerLoot(playerNum)
            local page = lootWindow and lootWindow.inventoryPane and lootWindow.inventoryPane.inventoryPage or nil
            local current = page and page.inventoryPane and page.inventoryPane.inventory or page and page.inventory or nil
            local currentType = current and current:getType() or nil
            local preferredType = page and Proximity.GetPreferredType(eff, page) or nil

            if not page or not page.tempForceSelectUnlock or currentType == preferredType then
                Proximity._BrowseElapsedMs[playerNum] = nil
            end

            local transferActive = Proximity.isTransferActive(playerNum)
            local elapsed = Proximity._BrowseElapsedMs[playerNum]
            if elapsed ~= nil and not transferActive then
                elapsed = elapsed + elapsedThisTickMs
                Proximity._BrowseElapsedMs[playerNum] = elapsed
            end

            if elapsed ~= nil and not transferActive and elapsed >= delayMs then
                if page then
                    Helpers.dlog("Snap Back Now!")
                    snappedBack = Proximity.DoAutoLock(playerNum, page, true) or snappedBack
                else
                    Helpers.dlog("Failed Snap Back.")
                end
            end
        end
    end

    if snappedBack then
        ISInventoryPage.dirtyUI()
    end
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
    local ProximitySmartDeposit = require("BetterContainers/Proximity/Proximity_SmartDeposit")

    -- Install Proximity hooks explicitly after all files have loaded.
    -- Reorder already patches ISInventoryPage during file load, so installing
    -- Proximity here makes it wrap the final Reorder-owned page methods.
    ProximityInventoryPane.install()
    ProximityInventoryPage.install()
    ProximityLootWindowControls.install()
    ProximityTransferAction.install()
    ProximitySmartDeposit.install()

    if not Proximity._eventsInstalled then
        Proximity._eventsInstalled = true

        Events[Helpers.OPTIONS_APPLIED].Add(function()
            Proximity.OnOptionsApplied()
        end)

        Events.OnTick.Add(function()
            Proximity.OnAutoLockTick()
        end)

        Events.OnKeyPressed.Add(function(key)
            Proximity.DoOptionPress(key)
        end)
    end
end

return Proximity
