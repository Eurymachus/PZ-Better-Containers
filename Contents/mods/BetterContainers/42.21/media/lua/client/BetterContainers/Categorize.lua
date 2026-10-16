local CATEGORIES_ROOT = "BetterContainers/Categorize/Categories/"

local Helpers = require("BetterContainers/Helpers")
local CategoryStore = require("BetterContainers/Categorize/CategoryStore")
local InventoryCategory = require("BetterContainers/Categorize/InventoryCategory")

local function dlog(msg)
    Helpers.dlog(msg)
end

local OPTS = require("BetterContainers/_Options")
local isEnabled = OPTS.showAdvancedDisplayCategories

local Categorize = {}

-- Cached universe of vanilla DisplayCategory strings.
-- Built from ScriptItems to avoid context-dependent shrinking; mapped and
-- custom inventory categories are added by CategoryStore.
local _BC_AllDisplayCategories = nil -- array

local function _bcTrim(s)
    if type(s) ~= "string" then return "" end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _bcBuildCategoryBlacklist(value)
    value = _bcTrim(tostring(value or ""))
    local disabled = string.lower(value)
    if value == "" or disabled == "none" or disabled == "off" or disabled == "false" or disabled == "-" then
        return nil
    end

    local out = {}
    local count = 0
    for token in string.gmatch(value, "([^,]+)") do
        local category = _bcTrim(token)
        if category ~= "" then
            local key = string.lower(category)
            if not out[key] then
                out[key] = true
                count = count + 1
            end
        end
    end

    if count == 0 then return nil end
    return out
end

local function _bcIsDisplayCategoryBlacklisted(scriptItem, blacklist)
    if not (scriptItem and blacklist) then return false end
    local ok, category = pcall(function() return scriptItem:getDisplayCategory() end)
    if not (ok and category and category ~= "") then return false end
    return blacklist[string.lower(_bcTrim(tostring(category)))] == true
end

local function loadCategories()
    dlog("showAdvancedDisplayCategories = " .. tostring(isEnabled))
    InventoryCategory.setEnabled(isEnabled)
    if not isEnabled then return end
    local Categories = {}

    local function loadCategoryFile(path)
        local path = CATEGORIES_ROOT .. path
        local ok, data = pcall(require, path)
        if not ok or type(data) ~= "table" then
            dlog("Failed loading category file " .. tostring(path))
            return
        end

        for category, items in pairs(data) do
            if type(items) == "table" then
                Categories[category] = Categories[category] or {}
                for i = 1, #items do
                    Categories[category][#Categories[category] + 1] = items[i]
                end
            end
        end
    end

    -- ===== LOAD TABLES =====
    loadCategoryFile("vanilla/food")
    loadCategoryFile("vanilla/literature")
    loadCategoryFile("vanilla/weapons")
    loadCategoryFile("vanilla/clothing")
    loadCategoryFile("vanilla/household")
    loadCategoryFile("vanilla/containers")
    loadCategoryFile("vanilla/crafting")
    loadCategoryFile("vanilla/medical")
    loadCategoryFile("vanilla/electronics_media")
    loadCategoryFile("vanilla/survival")
    loadCategoryFile("vanilla/world_objects")
    loadCategoryFile("vanilla/vehicle")
    loadCategoryFile("vanilla/farming")

    local okApplyMods, applyMods = pcall(require, CATEGORIES_ROOT .. "_applyMods")
    if okApplyMods and type(applyMods) == "function" then
        applyMods(loadCategoryFile, dlog)
    end

    -- ===== FULLTYPE CACHE (for wildcards + auto-pass) =====
    local function buildScriptItemIndex()
        local items = getAllItems()
        local all = {}
        local byFullType = {}

        for i = 0, items:size() - 1 do
            local it = items:get(i)
            if it and it.getFullName then
                local ft = it:getFullName()
                if ft and ft ~= "" then
                    all[#all + 1] = ft
                    byFullType[ft] = it
                end
            end
        end

        return all, byFullType
    end

    local ALL_FULLTYPES, SCRIPTITEM_BY_FULLTYPE = buildScriptItemIndex()
    local CATEGORY_BLACKLIST = _bcBuildCategoryBlacklist(OPTS.categoryBlacklist)
    local skippedBlacklisted = 0

    -- ===== WILDCARDS =====
    local function isWildcard(s)
        return type(s) == "string" and string.find(s, "*", 1, true) ~= nil
    end

    local function globToLuaPattern(glob)
        -- Escape Lua pattern chars, then turn '*' into '.*'
        local p = glob:gsub("([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1")
        p = p:gsub("%*", ".*")
        return "^" .. p .. "$"
    end

    local wildcardCache = {} -- glob -> { fullTypes }

    local function expandWildcard(glob)
        local cached = wildcardCache[glob]
        if cached then return cached end

        local pat = globToLuaPattern(glob)
        local matches = {}

        for i = 1, #ALL_FULLTYPES do
            local ft = ALL_FULLTYPES[i]
            if ft and string.match(ft, pat) then
                matches[#matches + 1] = ft
            end
        end

        wildcardCache[glob] = matches

        dlog("Wildcard " .. tostring(glob) .. " -> " .. tostring(#matches))

        return matches
    end

    local function wildcardSpecificityScore(glob)
        -- Higher = more specific. Simple heuristic: count of non-* characters.
        if type(glob) ~= "string" then return 0 end
        local nStar = 0
        for i = 1, #glob do
            if string.sub(glob, i, i) == "*" then
                nStar = nStar + 1
            end
        end
        return #glob - nStar
    end

    local function getSortedCategoryKeys()
        local keys = {}
        for k in pairs(Categories) do
            keys[#keys + 1] = k
        end
        table.sort(keys) -- deterministic
        return keys
    end

    -- ===== ASSIGNMENT MODEL =====
    -- spec: 2 = explicit, 1 = wildcard-derived, 0 = auto
    -- For wildcard-derived entries, a higher wildcardScore (more literal characters) wins on spec ties.
    local best = {}   -- fullType -> { category, spec, wildcardScore }

    local function setBest(fullType, category, spec, wildcardScore)
        if _bcIsDisplayCategoryBlacklisted(SCRIPTITEM_BY_FULLTYPE[fullType], CATEGORY_BLACKLIST) then
            skippedBlacklisted = skippedBlacklisted + 1
            return
        end

        local prev = best[fullType]
        if not prev then
            best[fullType] = { category = category, spec = spec, wildcardScore = wildcardScore or 0 }
            return
        end

        -- Explicit beats wildcard; wildcard beats auto.
        if spec > prev.spec then
            best[fullType] = { category = category, spec = spec, wildcardScore = wildcardScore or 0 }
            return
        end

        -- On wildcard ties, the more specific wildcard wins.
        if spec == prev.spec and spec == 1 then
            local ns = wildcardScore or 0
            local ps = prev.wildcardScore or 0
            if ns > ps then
                best[fullType] = { category = category, spec = spec, wildcardScore = ns }
            end
        end
    end

    -- ===== 1) MANUAL APPLY (explicit + wildcard) =====
    do
        local cats = getSortedCategoryKeys()

        for ci = 1, #cats do
            local category = cats[ci]
            local entries = Categories[category]

            for i = 1, #entries do
                local e = entries[i]
                if type(e) == "string" then
                    if isWildcard(e) then
                        local matches = expandWildcard(e)
                        local score = wildcardSpecificityScore(e)
                        for j = 1, #matches do
                            setBest(matches[j], category, 1, score)
                        end
                    else
                        setBest(e, category, 2, 0)
                    end
                end
            end
        end
    end

    -- ===== 2) AUTO CATEGORIZE (only if not already explicit/wildcard) =====
    local function isItemTypeSafe(item, itemType)
        return item and item.isItemType and ItemType and itemType and item:isItemType(itemType) == true
    end

    local function isPerishableFood(item)
        if not isItemTypeSafe(item, ItemType and ItemType.FOOD) then
            return false
        end

        local dtr = item.getDaysTotallyRotten and item:getDaysTotallyRotten() or -1
        return dtr > 0 and dtr < 1000000000
    end

    -- Script spoilage data is authoritative when a broad or stale manual rule
    -- places perishable food in the non-perishable category.
    for fullType, rec in pairs(best) do
        if rec.category == "FoodN" and isPerishableFood(SCRIPTITEM_BY_FULLTYPE[fullType]) then
            rec.category = "FoodP"
        end
    end

    local function autoCategory(item)
        if not item then return nil end

        local dc = item.getDisplayCategory and (item:getDisplayCategory() or "") or ""

        -- Water display category -> beverage bucket
        if dc == "Water" then
            return "FoodB"
        end

        -- Food: perishable vs non-perishable
        if isItemTypeSafe(item, ItemType and ItemType.FOOD) then
            if isPerishableFood(item) then
                return "FoodP"
            end
            return "FoodN"
        end

        -- Literature
        if isItemTypeSafe(item, ItemType and ItemType.LITERATURE) then
            local sk = item.getSkillTrained and (item:getSkillTrained() or "") or ""
            if sk ~= "" then
                return "LitS"
            end

            local learned = item.getLearnedRecipes and item:getLearnedRecipes() or nil
            if learned and learned.isEmpty and (not learned:isEmpty()) then
                return "LitR"
            end

            local stress = item.getStressChange and item:getStressChange() or 0
            local bored  = item.getBoredomChange and item:getBoredomChange() or 0
            local unhappy = item.getUnhappyChange and item:getUnhappyChange() or 0
            if stress ~= 0 or bored ~= 0 or unhappy ~= 0 then
                return "LitE"
            end

            return "LitW"
        end

        -- Ammo
        if isItemTypeSafe(item, ItemType and ItemType.AMMO) then
            return "Ammo"
        end

        -- Keys
        if isItemTypeSafe(item, ItemType and ItemType.KEY) then
            return "Key"
        end

        -- Medical
        if isItemTypeSafe(item, ItemType and ItemType.MEDICAL) then
            return "Med"
        end

        -- Containers (avoid clothing containers)
        if isItemTypeSafe(item, ItemType and ItemType.CONTAINER) then
            local isClothing = isItemTypeSafe(item, ItemType and ItemType.CLOTHING)
            if not isClothing then
                return "Cont"
            end
        end

        -- Weapons
        if isItemTypeSafe(item, ItemType and ItemType.WEAPON) then
            -- Cap guns can carry both firearm and fake-weapon tags.
            if item.hasTag and ItemTag and ItemTag.FAKE_WEAPON and item:hasTag(ItemTag.FAKE_WEAPON) then
                return dc ~= "" and dc or nil
            end

            if dc == "Explosives" or dc == "Devices" then
                return "WepBomb"
            end

            if item.hasTag and ItemTag and ItemTag.FIREARM and item:hasTag(ItemTag.FIREARM) then
                return "WepFire"
            end

            if item.isRanged and item:isRanged() then
                return "WepRange"
            end

            if dc == "Gun" or dc == "Guns" or dc == "Firearm" or dc == "Firearms" then
                return "WepFire"
            end

            return "WepMelee"
        end

        return nil
    end

    do
        for i = 1, #ALL_FULLTYPES do
            local ft = ALL_FULLTYPES[i]
            if ft and not best[ft] then
                local it = SCRIPTITEM_BY_FULLTYPE[ft]
                local cat = autoCategory(it)
                if cat then
                    setBest(ft, cat, 0, 0)
                end
            end
        end
    end

    local resolvedDefaults = {}
    for fullType, rec in pairs(best) do
        resolvedDefaults[fullType] = rec.category
    end
    for fullType, scriptItem in pairs(SCRIPTITEM_BY_FULLTYPE) do
        if not resolvedDefaults[fullType] and scriptItem.getDisplayCategory then
            local ok, category = pcall(function() return scriptItem:getDisplayCategory() end)
            if ok and category and category ~= "" then
                resolvedDefaults[fullType] = category
            end
        end
    end
    CategoryStore.setDefaults(resolvedDefaults)
    CategoryStore.injectCustomTranslations()

    -- Sparse player overrides are authoritative over the resolved defaults.
    for fullType, category in pairs(CategoryStore.overrides) do
        local scriptItem = SCRIPTITEM_BY_FULLTYPE[fullType]
        if scriptItem and not _bcIsDisplayCategoryBlacklisted(scriptItem, CATEGORY_BLACKLIST) then
            best[fullType] = { category = category, spec = 3, wildcardScore = 0 }
        end
    end

    dlog("Built inventory category mappings " .. tostring(#ALL_FULLTYPES))
    if skippedBlacklisted > 0 then
        dlog("Skipped blacklisted inventory category mappings " .. tostring(skippedBlacklisted))
    end

    -- The inventory-category universe has changed; rebuild on next request.
    _BC_AllDisplayCategories = nil
end

local function recategorizeAllLoadedItemsNow(load)
    InventoryCategory.setEnabled(load)
    if load then
        loadCategories()
    else
        CategoryStore.setDefaults({})
        _BC_AllDisplayCategories = nil
    end

    if ISInventoryPage and ISInventoryPage.dirtyUI then
        ISInventoryPage.dirtyUI()
    end
end

local categoryBlacklist = OPTS.categoryBlacklist

local function updateCategories()
    if isEnabled ~= OPTS.showAdvancedDisplayCategories or categoryBlacklist ~= OPTS.categoryBlacklist then
        isEnabled = OPTS.showAdvancedDisplayCategories
        categoryBlacklist = OPTS.categoryBlacklist
        recategorizeAllLoadedItemsNow(isEnabled)
    end
end

function Categorize.getAllDisplayCategories()
    if _BC_AllDisplayCategories then
        return _BC_AllDisplayCategories
    end

    local set = {}
    local out = {}

    if getAllItems then
        local items = getAllItems()
        if items then
            for i = 0, items:size() - 1 do
                local it = items:get(i)
                if it and it.getDisplayCategory then
                    local ok, dc = pcall(function() return it:getDisplayCategory() end)
                    if ok and dc and dc ~= "" and not set[dc] then
                        set[dc] = true
                        out[#out + 1] = dc
                    end
                end
            end
        end
    end

    table.sort(out)
    _BC_AllDisplayCategories = out
    return _BC_AllDisplayCategories
end

function Categorize.getAvailableCategories()
    return CategoryStore.getAllCategoryIDs(Categorize.getAllDisplayCategories())
end

function Categorize.getCategoryDisplayName(categoryID)
    return CategoryStore.getCategoryDisplayName(categoryID)
end

function Categorize.getCategoryStore()
    return CategoryStore
end

function Categorize.getInventoryCategory(itemOrFullType)
    return InventoryCategory.get(itemOrFullType)
end

function Categorize.applyCategoryChanges(flush)
    recategorizeAllLoadedItemsNow(isEnabled)
    if flush ~= false then
        CategoryStore.flush()
    end
end

function Categorize.applySingleCategoryChange(fullType, flush)
    if type(fullType) ~= "string" or fullType == "" then return false end
    if not isEnabled then
        if flush ~= false then CategoryStore.flush() end
        return false
    end

    local scriptItem = ScriptManager.instance and ScriptManager.instance:getItem(fullType) or nil
    if not scriptItem then return false end
    local blacklist = _bcBuildCategoryBlacklist(OPTS.categoryBlacklist)
    if _bcIsDisplayCategoryBlacklisted(scriptItem, blacklist) then return false end

    _BC_AllDisplayCategories = nil
    if ISInventoryPage and ISInventoryPage.dirtyUI then
        ISInventoryPage.dirtyUI()
    end
    dlog("Updated inventory category for item type " .. fullType)

    if flush ~= false then CategoryStore.flush() end
    return true
end

function Categorize.invalidateAllDisplayCategories()
    _BC_AllDisplayCategories = nil
end

local function _contextItemFullType(items)
    if type(items) ~= "table" then return nil end
    local item = items[1]
    if type(item) == "table" and item.items then
        item = item.items[1]
    end
    if item and item.getFullType then return item:getFullType() end
    return nil
end

local function _addCategoryManagerContextOption(playerNum, context, items, test)
    if test or not (context and context.addOption) then return end
    local fullType = _contextItemFullType(items)
    if not fullType then return end

    local scriptItem = ScriptManager.instance and ScriptManager.instance:getItem(fullType) or nil
    if not scriptItem then return end
    if scriptItem.isHidden then
        local ok, hidden = pcall(function() return scriptItem:isHidden() end)
        if ok and hidden then return end
    end

    context:addOption(getTextOrNull("ContextMenu_BetterContainers_ChangeCategory") or "Change Category",
        nil, function()
            local CategoryManagerUI = require("BetterContainers/Categorize/ui/CategoryManagerUI")
            CategoryManagerUI.open(playerNum, fullType)
        end)
end

Categorize.install = function()
    if Categorize._installed then return end
    Categorize._installed = true
    CategoryStore.ensureLoaded()
    CategoryStore.installTextResolver()
    CategoryStore.injectCustomTranslations()
    Events.OnMainMenuEnter.Add(function() loadCategories() end)
    Events[Helpers.OPTIONS_APPLIED].Add(updateCategories)
    Events.OnSave.Add(CategoryStore.flush)
    Events.OnDisconnect.Add(CategoryStore.flush)
    Events.OnFillInventoryObjectContextMenu.Add(_addCategoryManagerContextOption)

    require("BetterContainers/Categorize/InventoryPaneRender")
    local CategoryFilters = require("BetterContainers/Categorize/CategoryFilters")

    CategoryFilters.install()
end

return Categorize
