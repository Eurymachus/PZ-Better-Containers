require("BetterContainers/Categorize/ItemTweaker_CC")

local CATEGORIES_ROOT = "BetterContainers/Categorize/Categories/"

local Helpers = require("BetterContainers/Helpers")

local function dlog(msg)
    Helpers.dlog(msg)
end

local OPTS = require("BetterContainers/_Options")
local isEnabled = OPTS.showAdvancedDisplayCategories

local Categorize = {}

-- Cached universe of DisplayCategory strings (post-tweak).
-- Built from ScriptItems to avoid context-dependent shrinking.
local _BC_AllDisplayCategories = nil -- array

-- fullType -> originalDisplayCategory (string or false for "nil/absent")
local _BC_OrigDisplayCategory = nil

local function _bcCaptureOriginalDisplayCategory(fullType)
    if not _BC_OrigDisplayCategory then
        _BC_OrigDisplayCategory = {}
    end
    if _BC_OrigDisplayCategory[fullType] ~= nil then
        return
    end

    local scriptItem = ScriptManager.instance and ScriptManager.instance:getItem(fullType) or nil
    if not scriptItem then
        _BC_OrigDisplayCategory[fullType] = false
        return
    end

    local ok, cat = pcall(function() return scriptItem:getDisplayCategory() end)
    if ok and cat ~= nil then
        _BC_OrigDisplayCategory[fullType] = cat
    else
        _BC_OrigDisplayCategory[fullType] = false
    end
end

local function _bcRestoreOriginalDisplayCategory(fullType)
    if not (_BC_OrigDisplayCategory and _BC_OrigDisplayCategory[fullType] ~= nil) then
        return false
    end

    local orig = _BC_OrigDisplayCategory[fullType]
    local scriptItem = ScriptManager.instance and ScriptManager.instance:getItem(fullType) or nil
    if not scriptItem then
        return false
    end

    -- If original was nil/absent, we can't "remove" a param cleanly with DoParam.
    -- We pick the safest restore: set to vanilla empty if needed; otherwise restore string.
    if orig == false then
        -- best-effort: blank category (keeps engine stable; avoids nil)
        scriptItem:DoParam("DisplayCategory = ")
        return true
    end

    scriptItem:DoParam("DisplayCategory = " .. tostring(orig))
    return true
end

local function loadCategories()
    dlog("showAdvancedDisplayCategories = " .. tostring(isEnabled))
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

    local function autoCategory(item)
        if not item then return nil end

        local dc = item.getDisplayCategory and (item:getDisplayCategory() or "") or ""

        -- Water display category -> beverage bucket
        if dc == "Water" then
            return "FoodB"
        end

        -- Food: perishable vs non-perishable
        if isItemTypeSafe(item, ItemType and ItemType.FOOD) then
            local dtr = item.getDaysTotallyRotten and item:getDaysTotallyRotten() or -1
            if dtr > 0 and dtr < 1000000000 then
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
            if dc == "Explosives" or dc == "Devices" then
                return "WepBomb"
            end

            if dc ~= "" then
                if string.sub(dc, -6) == "Weapon" then
                    return "WepMelee"
                end
                if dc == "Weapon" or dc == "WeaponCrafted" then
                    return "WepMelee"
                end
                if dc == "Gun" or dc == "Guns" or dc == "Firearm" or dc == "Firearms" then
                    return "WepFire"
                end
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

    -- ===== 3) APPLY =====
    local applied = 0
    for fullType, rec in pairs(best) do
        _bcCaptureOriginalDisplayCategory(fullType)
        TweakItem(fullType, "DisplayCategory", rec.category)
        applied = applied + 1
    end

    ItemTweaker.tweakItems()
    dlog("Applied DisplayCategory tweaks " .. tostring(applied))

    -- DisplayCategory universe has changed; rebuild on next request.
    _BC_AllDisplayCategories = nil
end

local function unloadCategories()
    if not _BC_OrigDisplayCategory then
        return
    end

    local restored = 0
    for fullType, _ in pairs(_BC_OrigDisplayCategory) do
        if _bcRestoreOriginalDisplayCategory(fullType) then
            restored = restored + 1
        end
    end

    dlog("UnloadCategories restored script items = " .. tostring(restored))

    -- DisplayCategory universe has changed; rebuild on next request.
    _BC_AllDisplayCategories = nil
end

local function _getScriptDisplayCategory(scriptItem)
    if not scriptItem then return nil end
    -- ScriptItem is a Java object; getter name is stable in 42.x
    local ok, v = pcall(function() return scriptItem:getDisplayCategory() end)
    if ok then return v end
    return nil
end

local function _applyItemDisplayCategoryFromScript(invItem)
    if not invItem then return false end
    if not invItem.getFullType then return false end
    if not invItem.setDisplayCategory then return false end

    local fullType = invItem:getFullType()
    if not fullType then return false end

    local scriptItem = ScriptManager.instance and ScriptManager.instance:getItem(fullType) or nil
    local cat = _getScriptDisplayCategory(scriptItem)
    if cat == nil then
        return false
    end

    -- Set the runtime item field immediately (does not require recreating the item)
    invItem:setDisplayCategory(cat)
    return true
end

local function _walkContainer(container, seenContainers, stats)
    if not container then return end
    if seenContainers[container] then return end
    seenContainers[container] = true

    local items = container:getItems()
    if not items then return end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if _applyItemDisplayCategoryFromScript(item) then
                stats.items = stats.items + 1
            end

            -- Recurse into nested containers (bags in bags)
            -- InventoryContainer has getItemContainer(), but we guard to avoid hard deps.
            local nested = nil
            if item.getItemContainer then
                local ok, c = pcall(function() return item:getItemContainer() end)
                if ok then nested = c end
            end
            if nested then
                _walkContainer(nested, seenContainers, stats)
            end
        end
    end
end

local function _walkPlayersInventories(stats)
    if not getNumActivePlayers or not getPlayer then
        return
    end

    local n = getNumActivePlayers()
    if not n or n <= 0 then
        return
    end

    local seenContainers = {}

    for pn = 0, n - 1 do
        local playerObj = getPlayer(pn)
        if playerObj and playerObj.getInventory then
            local inv = playerObj:getInventory()
            if inv then
                _walkContainer(inv, seenContainers, stats)
            end
        end
    end
end

local function _applyObjectContainers(obj, seenContainers, stats)
    if not obj then return end

    -- Single container
    if obj.getContainer then
        local ok, c = pcall(function() return obj:getContainer() end)
        if ok and c then
            _walkContainer(c, seenContainers, stats)
        end
    end

    -- Multi container (safe enumeration; avoids getContainers signature collisions)
    if obj.getContainerCount and obj.getContainerByIndex then
        local okCount, n = pcall(function() return obj:getContainerCount() end)
        if okCount and n and n > 0 then
            for j = 0, n - 1 do
                local okC, cj = pcall(function() return obj:getContainerByIndex(j) end)
                if okC and cj then
                    _walkContainer(cj, seenContainers, stats)
                end
            end
        end
    end
end

local function _walkSquare(square, seenSquares, seenContainers, stats)
    if not square then return end

    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()
    local key = tostring(x) .. "," .. tostring(y) .. "," .. tostring(z)
    if seenSquares[key] then return end
    seenSquares[key] = true

    -- Ground items on this square
    if square.getWorldObjects then
        local worldObjs = square:getWorldObjects()
        if worldObjs then
            for i = 0, worldObjs:size() - 1 do
                local wio = worldObjs:get(i)
                if wio and wio.getItem then
                    local item = wio:getItem()
                    if item and _applyItemDisplayCategoryFromScript(item) then
                        stats.items = stats.items + 1
                    end
                end
            end
        end
    end

    -- IsoObjects on this square (where containers usually live)
    if square.getObjects then
        local objs = square:getObjects()
        if objs then
            for i = 0, objs:size() - 1 do
                local obj = objs:get(i)
                if obj and instanceof(obj, "IsoObject") and (not instanceof(obj, "IsoMovingObject")) then
                    _applyObjectContainers(obj, seenContainers, stats)
                end
            end
        end
    end
end

local function _walkWorldObjectsAndContainers(stats)
    if not (getCell and getNumActivePlayers and getPlayer) then
        return
    end

    local cell = getCell()
    if not (cell and cell.getGridSquare) then
        return
    end

    local seenSquares = {}
    local seenContainers = {}

    local function walkBounds(xmin, xmax, ymin, ymax)
        if not (xmin and xmax and ymin and ymax) then return false end

        -- Iterate all potentially loaded tiles in bounds; only act on squares that exist.
        for x = xmin, xmax do
            for y = ymin, ymax do
                for z = 0, 7 do
                    local sq = cell:getGridSquare(x, y, z)
                    if sq then
                        _walkSquare(sq, seenSquares, seenContainers, stats)
                    end
                end
            end
        end

        return true
    end

    -- 1) Preferred: true all-loaded traversal using each local player's chunk-map bounds
    local usedBounds = false
    if cell.getChunkMap then
        local n = getNumActivePlayers()
        for pn = 0, n - 1 do
            local cm = cell:getChunkMap(pn)
            if cm and cm.getWorldXMinTiles and cm.getWorldXMaxTiles and cm.getWorldYMinTiles and cm.getWorldYMaxTiles then
                local xmin = cm:getWorldXMinTiles()
                local xmax = cm:getWorldXMaxTiles()
                local ymin = cm:getWorldYMinTiles()
                local ymax = cm:getWorldYMaxTiles()

                if walkBounds(xmin, xmax, ymin, ymax) then
                    usedBounds = true
                end
            end
        end
    end

    if usedBounds then
        return
    end

    -- 2) Fallback: radius scan around each player (still only touches loaded squares via getGridSquare)
    local R = 60
    local n = getNumActivePlayers()
    for pn = 0, n - 1 do
        local playerObj = getPlayer(pn)
        if playerObj and playerObj.getCurrentSquare then
            local psq = playerObj:getCurrentSquare()
            if psq then
                local px, py, pz = psq:getX(), psq:getY(), psq:getZ()
                for dx = -R, R do
                    for dy = -R, R do
                        local sq = cell:getGridSquare(px + dx, py + dy, pz)
                        if sq then
                            _walkSquare(sq, seenSquares, seenContainers, stats)
                        end
                    end
                end
            end
        end
    end
end

-- Public entrypoint: call this after changing your categorize option in-game.
-- It (1) reapplies ScriptItem tweaks via loadCategories(), then (2) relabels all loaded InventoryItems immediately.
local function recategorizeAllLoadedItemsNow(load)
    local stats = { items = 0 }

    if load then
        loadCategories()
    else
        unloadCategories()
    end

    -- Only relabel live items when an in-game cell exists
    if not getCell then
        dlog("Re-categorise skipped live relabel (no getCell)")
        return
    end

    local cell = getCell()
    if not cell or not cell.getObjectList then
        dlog("Re-categorise skipped live relabel (no active cell)")
        return
    end

    _walkPlayersInventories(stats)
    _walkWorldObjectsAndContainers(stats)

    dlog("Re-categorised loaded items = " .. tostring(stats.items))
end

local function updateCategories()
    if isEnabled ~= OPTS.showAdvancedDisplayCategories then
        isEnabled = OPTS.showAdvancedDisplayCategories
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

function Categorize.invalidateAllDisplayCategories()
    _BC_AllDisplayCategories = nil
end

Events.OnMainMenuEnter.Add(function() loadCategories() end)
Events[Helpers.OPTIONS_APPLIED].Add(updateCategories)

return Categorize