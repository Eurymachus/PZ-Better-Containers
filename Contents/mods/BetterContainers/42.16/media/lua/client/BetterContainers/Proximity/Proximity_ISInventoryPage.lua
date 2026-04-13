require "ISUI/ISInventoryPage"

local Options = require("BetterContainers/_Options")
local Proximity = require("BetterContainers/Proximity")

local ProximityInventoryPage = {}

ProximityInventoryPage._installed = false

local function clearProximityHighlights(page)
    if not page.coloredProximityInventories then return end

    for container in pairs(page.coloredProximityInventories) do
        local selectedContainer = page.coloredInv
        if container ~= selectedContainer then
            local parent = page:getContainerParent(container)
            if parent then
                local isWorldParent = instanceof(parent, "IsoWorldInventoryObject")
                local vanillaOwns = isWorldParent and Proximity.getVanillaHoveredItem(page.player)[parent]
                local mouseOverOwns = parent == page.mouseOverColoredContainer

                if not vanillaOwns and not mouseOverOwns then
                    parent:setHighlighted(page.player, false)
                    parent:setOutlineHighlight(page.player, false)
                    parent:setOutlineHlAttached(page.player, false)
                end

                if isWorldParent then
                    Proximity.getProximityHoveredItem(page.player)[parent] = nil
                end
            end

            page.coloredProximityInventories[container] = nil
        end
    end
end

local function canUseProximityHighlight(page)
    if not page then return false end

    local eff = Options.getEffectivePermissions() or {}
    if not eff.proximityActive then return false end
    if page.onCharacter or page.isCollapsed then return false end
    if not Options.enableProximityHighlight then return false end

    local invType = page.inventory and page.inventory:getType() or nil
    return invType == Proximity.invName or invType == Proximity.invName_corpses
end

local function isCorpseOnlyHighlightMode()
    local eff = Options.getEffectivePermissions() or {}
    return eff.corpseOnly == true
end

local function getProximityHighlightColor()
    local hl = getCore():getObjectHighlitedColor()
    return hl, hl:getR(), hl:getG(), hl:getB()
end

local function applyProximityHighlightForContainer(page, playerNum, corpseOnly, hl, hlR, hlG, hlB, container)
    if not page or not container then return end

    if corpseOnly and not Proximity.isHumanContainer(container:getType()) then
        return
    end

    local parent = page:getContainerParent(container)
    if not parent then return end

    local isWorldParent = instanceof(parent, "IsoWorldInventoryObject")
    local vanillaOwns = isWorldParent and Proximity.getVanillaHoveredItem(playerNum)[parent]
    local mouseOverOwns = parent == page.mouseOverColoredContainer

    if vanillaOwns or mouseOverOwns then
        return
    end

    page.coloredProximityInventories = page.coloredProximityInventories or {}
    page.coloredProximityInventories[container] = true

    if isWorldParent then
        Proximity.getProximityHoveredItem(playerNum)[parent] = true
    end

    parent:setHighlighted(playerNum, true, false)
    parent:setHighlightColor(playerNum, hl)

    if instanceof(parent, "IsoObject") and not instanceof(parent, "IsoDeadBody") then
        parent:setOutlineHighlight(playerNum, true)
        parent:setOutlineHlAttached(playerNum, true)
        parent:setOutlineHighlightCol(playerNum, hlR, hlG, hlB, 1)
    end
end

function ProximityInventoryPage.install()
    if ProximityInventoryPage._installed then return end
    ProximityInventoryPage._installed = true

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

    local old_onMouseOutButton = ISInventoryPage.onMouseOutButton
    function ISInventoryPage:onMouseOutButton(button, x, y)
        local inv = button and button.inventory or nil

        old_onMouseOutButton(self, button, x, y)

        if not inv or not canUseProximityHighlight(self) then
            return
        end

        local corpseOnly = isCorpseOnlyHighlightMode()
        local hl, hlR, hlG, hlB = getProximityHighlightColor()

        applyProximityHighlightForContainer(
            self,
            self.player,
            corpseOnly,
            hl, hlR, hlG, hlB,
            inv
        )
    end

    local old_ISInventoryPage_update = ISInventoryPage.update
    function ISInventoryPage:update()
        old_ISInventoryPage_update(self)

        local playerNum = self.player
        local eff = Options.getEffectivePermissions() or {}

        if Proximity._ForceSwitchIntent[playerNum] then
            if not eff.proximityActive then
                Proximity._ForceSwitchIntent[playerNum] = nil
            else
                local target = Proximity._ForceSwitchIntent[playerNum]
                Proximity.forceSelectedType[playerNum] = target

                local manualForce = Proximity.isForceSelected[playerNum] and true or false
                local policyForce = eff.autoLock == true
                local forceWanted = manualForce or policyForce
                local autolockUnlock = policyForce and self.tempForceSelectUnlock

                if forceWanted and not autolockUnlock then
                    self:setForceSelectedContainer(Proximity.GetCurrentForceContainer(playerNum))
                end

                Proximity._ForceSwitchIntent[playerNum] = nil
                return
            end
        end

        Proximity.DoAutoLock(playerNum, self, false)

        if not canUseProximityHighlight(self) then
            clearProximityHighlights(self)
            return
        end

        self.coloredProximityInventories = self.coloredProximityInventories or {}
        clearProximityHighlights(self)

        local corpseOnly = isCorpseOnlyHighlightMode()
        local hl, hlR, hlG, hlB = getProximityHighlightColor()

        for i = 1, #self.backpacks do
            local entry = self.backpacks[i]
            local container = entry and entry.inventory
            if container then
                applyProximityHighlightForContainer(
                    self,
                    playerNum,
                    corpseOnly,
                    hl, hlR, hlG, hlB,
                    container
                )
            end
        end
    end
end

return ProximityInventoryPage