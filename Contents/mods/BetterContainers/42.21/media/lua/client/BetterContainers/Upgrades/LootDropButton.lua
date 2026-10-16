local LootDropButton = {}

local function droppableItems(pane, row)
    local entry = pane.items and pane.items[row]
    local result = {}
    if not entry then return result end
    for _, item in ipairs(ISInventoryPane.getActualItems({ entry })) do
        local container = item:getContainer()
        if container and container:getType() ~= "floor" and not item:isFavorite()
            and not (instanceof(item, "Moveable") and not item:CanBeDroppedOnFloor()) then
            result[#result + 1] = item
        end
    end
    return result
end

function LootDropButton.install()
    if LootDropButton._installed then return end
    LootDropButton._installed = true
    require("ISUI/ISInventoryPane")

    local oldOnContext = ISInventoryPane.onContext
    ISInventoryPane.onContext = function(self, button)
        if button.mode == "bcLootDrop" then
            -- Resolve real source containers again at click time, including proximity rows.
            ISInventoryPaneContextMenu.onDropItems(droppableItems(self, self.buttonOption), self.player)
        end
        return oldOnContext(self, button)
    end

    local oldDoButtons = ISInventoryPane.doButtons
    ISInventoryPane.doButtons = function(self, row)
        oldDoButtons(self, row)
        local loot = getPlayerLoot(self.player)
        if not loot or loot.inventoryPane ~= self then return end
        local grab = self.contextButton1
        -- Inherit vanilla's pause, sleep, dragging, tutorial and context-menu gates.
        if not grab:getIsVisible() or grab.mode ~= "grab" then return end
        if #droppableItems(self, row) == 0 then return end

        local previous = grab
        local button = self.contextButton2
        local stack = button:getIsVisible() and button.mode == "grab1"
        if stack then
            previous = button
            button = self.contextButton3
        end
        button:setTitle(getText(stack and "IGUI_invpanel_drop_all" or "ContextMenu_Drop"))
        button.mode = "bcLootDrop"
        button:setWidthToTitle()
        button:setX(previous:getRight() + 1)
        button:setY(grab:getY())
        button:setVisible(true)
    end
end

return LootDropButton
