local Helpers = require("BetterContainers/Helpers")
local Proximity = require("BetterContainers/Proximity")
local BlacklistCompat = require("BetterContainers/Proximity/BlacklistCompat")

local ProximityLootWindowContainerControls = {}

ProximityLootWindowContainerControls._installed = false

local function TWF_IsFloorLikeContainer(container)
    if not container then return false end
    local t = container:getType()
    return t == "floor" or t == Proximity.invName or t == Proximity.invName_corpses
end

function ProximityLootWindowContainerControls.install()
    if ProximityLootWindowContainerControls._installed then return end
    ProximityLootWindowContainerControls._installed = true

    Events.OnRefreshInventoryWindowContainers.Add(function(invSelf, state)
        local eff = require("BetterContainers/_Options").getEffectivePermissions() or {}
        if not eff.proximityActive or invSelf.onCharacter then return end

        if state == "begin" then
            return Proximity.OnBeginRefresh(invSelf)
        end

        if state == "buttonsAdded" then
            Proximity.OnButtonsAdded(invSelf)
            Proximity.HideIndividualCorpseButtons(invSelf)
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

    if not Helpers.isCleanUIActive() then
        require "ISUI/LootWindow/ISLootWindowContainerControls"

        local MoveToFloor = ISLootWindowObjectControlHandler_MoveToFloor:derive("BCProximityMoveToFloor")

        local function canMoveItemToFloor(item, handler)
            local source = item:getContainer()
            return source and source:getType() ~= "floor" and not item:isFavorite()
                and not (instanceof(item, "Moveable") and not item:CanBeDroppedOnFloor())
                and not BlacklistCompat.isHidden(item, handler.container, handler.playerObj or getSpecificPlayer(handler.playerNum))
        end

        function MoveToFloor:shouldBeVisible()
            local kind = self.container and self.container:getType()
            if kind ~= Proximity.invName and kind ~= Proximity.invName_corpses then return false end
            local items = self.container:getItems()
            for i = 0, items:size() - 1 do
                if canMoveItemToFloor(items:get(i), self) then return true end
            end
            return false
        end

        function MoveToFloor:perform()
            if isGamePaused() or not self:shouldBeVisible() then return end
            local items, seen = {}, {}
            local sourceItems = self.container:getItems()
            for i = 0, sourceItems:size() - 1 do
                local item = sourceItems:get(i)
                if not seen[item] and canMoveItemToFloor(item, self) then
                    seen[item] = true
                    items[#items + 1] = item
                end
            end
            ISInventoryPaneContextMenu.onMoveItemsTo(items, ISInventoryPage.GetFloorContainer(self.playerNum), self.playerNum)
        end

        ISLootWindowContainerControls.AddFloorHandler(MoveToFloor)

        if ISLootWindowContainerControls
            and not ISLootWindowContainerControls.__proximityInvFloorHandlers
        then
            ISLootWindowContainerControls.__proximityInvFloorHandlers = true

            function ISLootWindowContainerControls:handleJoypadContextMenu(context)
                local container = self:getDisplayedContainer()
                local object = self:getDisplayedObject()

                if object then
                    for _, handlerClass in ipairs(ISLootWindowContainerControls_HandlerList) do
                        local handler = self:checkHandler(handlerClass, object, container)
                        if handler:shouldBeVisible() then
                            handler:handleJoypadContextMenu(context)
                        end
                    end
                else
                    if container and TWF_IsFloorLikeContainer(container) then
                        for _, handlerClass in ipairs(ISLootWindowContainerControls_FloorHandlerList) do
                            local handler = self:checkHandler(handlerClass, nil, container)
                            if handler:shouldBeVisible() then
                                handler:handleJoypadContextMenu(context)
                            end
                        end
                    end
                end
            end

            function ISLootWindowContainerControls:arrange()
                local container = self:getDisplayedContainer()
                local object = self:getDisplayedObject()

                for _, control in ipairs(self.controls) do
                    control:setVisible(false)
                    self:removeChild(control)
                end
                table.wipe(self.controls)

                if object then
                    local x, y = 1, 1
                    local rowHgt = 0

                    for _, handlerClass in ipairs(ISLootWindowContainerControls_HandlerList) do
                        local handler = self:checkHandler(handlerClass, object, container)
                        if handler:shouldBeVisible() then
                            local control = handler:getControl()

                            if (x > 0) and (x + control:getWidth() > self.width) then
                                x = 1
                                y = y + rowHgt + 1
                                rowHgt = 0
                            end

                            control:setX(x)
                            control:setY(y)
                            control:setVisible(true)
                            self:addChild(control)
                            table.insert(self.controls, control)

                            x = control:getRight() + 10
                            rowHgt = math.max(rowHgt, control:getHeight())
                        end
                    end

                    self:setHeight(y + rowHgt + 1)
                else
                    if container and TWF_IsFloorLikeContainer(container) then
                        local x, y = 1, 1
                        local rowHgt = 0

                        for _, handlerClass in ipairs(ISLootWindowContainerControls_FloorHandlerList) do
                            local handler = self:checkHandler(handlerClass, nil, container)
                            if handler:shouldBeVisible() then
                                local control = handler:getControl()

                                if (x > 0) and (x + control:getWidth() > self.width) then
                                    x = 1
                                    y = y + rowHgt
                                    rowHgt = 0
                                end

                                control:setX(x)
                                control:setY(y)
                                control:setVisible(true)
                                self:addChild(control)
                                table.insert(self.controls, control)

                                x = control:getRight() + 10
                                rowHgt = math.max(rowHgt, control:getHeight())
                            end
                        end

                        self:setHeight(y + rowHgt + 1)
                    end
                end

                if #self.controls > 0 then
                    self:setX(0)
                    self:setY(self.lootWindow.resizeWidget.y - self.height)
                    self:setWidth(self.lootWindow:getWidth())
                    self:setVisible(true)
                    self:fixMouseOverButton()
                else
                    self:setVisible(false)
                    self:setHeight(0)
                end
            end
        end
    else
        Helpers.dlog("CleanUI detected -> skipping Loot Window Proximity Update for Controllers")
    end
end

return ProximityLootWindowContainerControls
