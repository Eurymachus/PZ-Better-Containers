local BlacklistCompat = {}

local function enabled(option)
    return option and option.getValue and option:getValue() == true
end

-- Match TwisTonFire Blacklist 42.20's bulk-action rules without requiring the mod.
function BlacklistCompat.isHidden(item, container, playerObj)
    local blacklist = ItemBlacklist
    if not blacklist or blacklist.currentEnabled ~= true
        or not enabled(blacklist.filterHandlersOption) then return false end
    if not container or not playerObj then return false end
    if container:isInCharacterInventory(playerObj) then return false end
    if enabled(blacklist.onlyCorpsesOption) then
        local kind = string.lower(container:getType())
        if kind ~= "inventorymale" and kind ~= "inventoryfemale" and kind ~= "twistinv_corpses" then
            return false
        end
    end

    local key = blacklist.makeKey and blacklist.makeKey(item) or item:getFullType()
    if key and blacklist.isBlacklistedKey and blacklist.isBlacklistedKey(key) then return true end
    if enabled(blacklist.hideDamagedClothingOption) and item:IsClothing() then
        local maximum = item:getConditionMax()
        local threshold = blacklist.getHideClothingThresholdPercent and blacklist.getHideClothingThresholdPercent() or 100
        if maximum > 0 and threshold > 0 then
            return item:getCondition() / maximum * 100 < threshold
        end
    end
    return false
end

return BlacklistCompat
