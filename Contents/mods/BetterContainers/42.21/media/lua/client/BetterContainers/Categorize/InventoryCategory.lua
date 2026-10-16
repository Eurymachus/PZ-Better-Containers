local CategoryStore = require("BetterContainers/Categorize/CategoryStore")

local InventoryCategory = {}
local enabled = false

function InventoryCategory.setEnabled(value)
    enabled = value == true
end

function InventoryCategory.get(itemOrFullType)
    local fullType = itemOrFullType
    local item = nil

    if type(itemOrFullType) ~= "string" then
        item = itemOrFullType
        fullType = item and item.getFullType and item:getFullType() or nil
    end

    if enabled and fullType then
        local mapped = CategoryStore.getEffective(fullType)
        if mapped and mapped ~= "" then
            return mapped
        end
    end

    if item then
        local displayCategory = item.getDisplayCategory and item:getDisplayCategory() or nil
        if displayCategory and displayCategory ~= "" then
            return displayCategory
        end

        local category = item.getCategory and item:getCategory() or nil
        if category and category ~= "" then
            return category
        end
    end

    return nil
end

return InventoryCategory
