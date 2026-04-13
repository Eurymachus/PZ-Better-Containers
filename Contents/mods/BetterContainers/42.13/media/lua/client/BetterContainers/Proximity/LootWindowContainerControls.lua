local Helpers = require("BetterContainers/Helpers")
local Proximity = require("BetterContainers/Proximity")

local function _normalizeModId(id)
    return (id and tostring(id) or ""):lower()
        :gsub("\\", "")
        :gsub("/", "")
        :gsub("%s+", "")
end

local function _isModActive(modId)
    local mods = getActivatedMods and getActivatedMods() or nil
    if not mods then return false end

    local needle = _normalizeModId(modId)

    for i = 0, mods:size() - 1 do
        if _normalizeModId(mods:get(i)) == needle then
            return true
        end
    end

    return false
end

if _isModActive("CleanUI") then
    Helpers.dlog("CleanUI detected -> skipping Loot Window Proxmity Update for Controllers")
    return
end

require "ISUI/LootWindow/ISLootWindowContainerControls"

if ISLootWindowContainerControls
    and not ISLootWindowContainerControls.__proximityInvFloorHandlers
then
    ISLootWindowContainerControls.__proximityInvFloorHandlers = true

    local function TWF_IsFloorLikeContainer(container)
        if not container then return false end
        local t = container:getType()
        return t == "floor" or t == Proximity.invName or t == Proximity.invName_corpses
    end

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