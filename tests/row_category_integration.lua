local active = true
local categoryReads = 0
local helpers = { isCleanUIActive = function() return active end }
local category = { get = function(item)
    categoryReads = categoryReads + 1
    return item.category
end }
category.getRow = function(row)
    if row._bcEquippedAttachedSeparator or row.type == "separator" then return row.cat end
    return row.items and category.get(row.items[1]) or row.cat
end
require = function(name)
    if name == "BetterContainers/Helpers" then return helpers end
    if name == "BetterContainers/Categorize/InventoryCategory" then return category end
end
local function event()
    local handlers = {}
    return { Add = function(fn) handlers[#handlers + 1] = fn end,
        fire = function() for _, fn in ipairs(handlers) do fn() end end,
        handlers = handlers }
end
Events = { OnGameStart = event(), OnTick = event() }
local calls = 0
local function host(self, value)
    calls = calls + 1
    return value, nil, "tail"
end
ISInventoryPane = { refreshContainer = host }
local original = ISInventoryPane
loadMod()
local function row(name, cat, match)
    return {name = name, cat = "old", matchesSearch = match, items = {{category = cat}}}
end
local function pane(class)
    return setmetatable({itemslist = {
        row("A", "Zulu", true), row("B", "Alpha", false),
        row("C", "Beta", true), row("D", "Gamma", false)},
        itemSortFunc = function(a, b) return a.cat < b.cat end}, {__index = class})
end
local function checkOrder(p, expected)
    local ids = ""
    for _, r in ipairs(p.itemslist) do ids = ids .. r.name end
    assert(ids == expected, ids .. " != " .. expected)
end
local p = pane(original)
p.searchText = "x"
local a, b, c = p:refreshContainer("value")
assert(a == "value" and b == nil and c == "tail", "host returns lost")
checkOrder(p, "CABD")
p.itemSortFunc = function(a, b) return a.cat > b.cat end
p:refreshContainer()
checkOrder(p, "ACDB")
p.itemSortFunc = function(a, b) return a.cat < b.cat end
p.searchText = ""
p.searchCategoryText = "x"
p:refreshContainer()
checkOrder(p, "CABD")
p.searchCategoryText = ""
p:refreshContainer()
checkOrder(p, "BCDA")

-- A replacement after OnGameStart must not be blocked by an old marker.
Events.OnGameStart.fire()
original.refreshContainer = host
Events.OnTick.fire()
assert(original.refreshContainer ~= host)
local stable = original.refreshContainer
for i = 1, 10 do Events.OnTick.fire() end
assert(original.refreshContainer == stable, "wrapper churn")

-- A third-party wrapper retaining ours must keep its post-refresh changes.
original.refreshContainer = function(self, ...)
    local a, b, c = stable(self, ...)
    self.itemslist[1].items[1].category = "Aardvark"
    return a, b, c
end
Events.OnTick.fire()
p = pane(original)
categoryReads = 0
a, b, c = p:refreshContainer("wrapped")
assert(categoryReads == 4, "nested decoration")
assert(a == "wrapped" and b == nil and c == "tail")
assert(p.itemslist[1].cat == "Alpha", "outer wrapper repeated decoration")
assert(p.itemslist[1].items[1].category == "Aardvark", "host postprocessing lost")

-- Alternate classes may appear after startup and later become the active class.
CleanUI_Clean_ISInventoryPane = original
CleanUI_Vanilla_ISInventoryPane = {refreshContainer = host}
ISInventoryPane = CleanUI_Vanilla_ISInventoryPane
Events.OnTick.fire()
p = pane(ISInventoryPane)
p:refreshContainer()
checkOrder(p, "BCDA")
ISInventoryPane = original
Events.OnTick.fire()

-- A failing host must not leave the pane permanently inside a refresh.
local fail = true
ISInventoryPane.refreshContainer = function(self)
    if fail then error("expected host failure") end
end
Events.OnTick.fire()
p = pane(ISInventoryPane)
assert(not pcall(function() p:refreshContainer() end))
fail = false
categoryReads = 0
p:refreshContainer()
assert(categoryReads == 4, "refresh guard leaked after error")

-- Standalone mode keeps ordinary sorting and adds no tick monitor.
active = false
Events = { OnGameStart = event(), OnTick = event() }
ISInventoryPane = {refreshContainer = host}
CleanUI_Clean_ISInventoryPane = nil
CleanUI_Vanilla_ISInventoryPane = nil
loadMod()
assert(#Events.OnTick.handlers == 0)
p = pane(ISInventoryPane)
p.searchText = "x"
p:refreshContainer()
checkOrder(p, "BCDA")
assert(type(ISInventoryPane.renderdetails) == "function")

-- Exercise the real feature wrappers, including their temporary comparator and
-- post-refresh section construction. Reinstalling must preserve their results.
local originalRequire = require
local options = {}
local savedState = {}
helpers.dlog = function() end
require = function(name)
    if name == "BetterContainers/_Options" then return options end
    if name == "BetterContainers/_IO/IniWriter" then
        return {makeFeature = function() return {
            get = function() return savedState end,
            set = function(_, value) savedState = value end} end}
    end
    return originalRequire(name)
end
ISInventoryItem = {}
string.sort = function(a, b) return a > b end
local function item(name, cat, weight)
    return {category = cat, getName = function() return name end,
        getDisplayName = function() return name end, getType = function() return name end,
        getFullType = function() return name end, getUnequippedWeight = function() return weight end}
end
local normal = item("Apple", "Zulu", 3)
local pinned = item("Zebra", "Alpha", 1)
local equippedA = item("Boots", "Clothes", 2)
local equippedB = item("Axe", "Weapon", 4)
local inventory = {getItems = function() return {size = function() return 0 end} end}
local player = {getInventory = function() return inventory end,
    getWornItems = function() end, getAttachedItems = function() end,
    getPrimaryHandItem = function() return equippedA end,
    getSecondaryHandItem = function() return equippedB end}
getSpecificPlayer = function() return player end
local function makeStack(it)
    return {name = it:getName(), cat = "old", count = 2, weight = it:getUnequippedWeight(),
        items = {it, it}, matchesSearch = it ~= pinned}
end
local scenarios = 0
for _, clean in ipairs({false, true}) do
    for _, collapsed in ipairs({false, true}) do
        for _, pinEnabled in ipairs({false, true}) do
            for _, sectionEnabled in ipairs({false, true}) do
                for _, sortKey in ipairs({"name", "category", "weight"}) do
                    active = clean
                    options.showFavouritesOnPlayerInventories = pinEnabled
                    options.showEquippedAttachedSection = sectionEnabled
                    savedState = {collapsed = collapsed}
                    Events = {OnGameStart = event(), OnTick = event()}
                    CleanUI_Clean_ISInventoryPane = nil
                    CleanUI_Vanilla_ISInventoryPane = nil
                    local byName = function(a, b) return a.name < b.name end
                    local byCat = function(a, b) return a.cat < b.cat end
                    local byWeight = function(a, b) return a.weight < b.weight end
                    ISInventoryPane = {itemSortByCatInc = byCat, itemSortByWeightAsc = byWeight,
                        refreshContainer = function(self)
                            self.itemslist = {makeStack(normal), makeStack(pinned),
                                makeStack(equippedA), makeStack(equippedB)}
                            table.sort(self.itemslist, self.itemSortFunc)
                        end}
                    loadMod()
                    loadEquippedAttachedSection().install()
                    local pins = loadPinnedItems()
                    pins.FavouritedItems.Zebra = true
                    pins.installInventoryPaneSortPatch()
                    local p = setmetatable({parent = {onCharacter = true},
                        inventoryPage = {onCharacter = true}, inventory = inventory,
                        player = 0, collapsed = {}, selected = {},
                        itemSortFunc = sortKey == "name" and byName or sortKey == "category" and ISInventoryPane.itemSortByCatInc or byWeight,
                        saveSelection = function() return {} end,
                        restoreSelection = function() end, updateScrollbars = function() end},
                        {__index = ISInventoryPane})
                    local function snapshot()
                        local result = ""
                        for _, r in ipairs(p.itemslist) do
                            result = result .. r.name .. ":" .. r.cat .. "|"
                        end
                        return result
                    end
                    p:refreshContainer()
                    local expected = snapshot()
                    Events.OnGameStart.fire()
                    Events.OnTick.fire()
                    p:refreshContainer()
                    assert(snapshot() == expected, "feature ordering changed after reinstall: " .. sortKey)
                    if pinEnabled then assert(p.itemslist[1].items[1] == pinned, "pin lost") end
                    if sectionEnabled then
                        assert(p.itemslist[3]._bcEquippedAttachedSeparator, "section moved")
                        assert(#p.itemslist == (collapsed and 3 or 5), "section collapse changed")
                        if not collapsed then
                            assert(p.itemslist[4]._bcEquippedAttachedChild and p.itemslist[5]._bcEquippedAttachedChild)
                        end
                    end
                    if clean then
                        p.searchText = "match"
                        p:refreshContainer()
                        assert(p.itemslist[1].matchesSearch, "pin displaced search matches")
                        if sectionEnabled then assert(p.itemslist[3]._bcEquippedAttachedSeparator) end
                    end
                    scenarios = scenarios + 1
                end
            end
        end
    end
end
assert(scenarios == 48)

-- A later filter may overwrite cat, retain rows, and sort again. Category
-- comparisons must resolve the items without writing back into those rows.
local aRow = makeStack(normal)
local bRow = makeStack(pinned)
aRow.cat = "AAA"
bRow.cat = "ZZZ"
assert(not ISInventoryPane.itemSortByCatInc(aRow, bRow), "stale row categories controlled sort")
assert(ISInventoryPane.itemSortByCatInc(bRow, aRow))
assert(aRow.cat == "AAA" and bRow.cat == "ZZZ", "comparison mutated shared rows")

for _, clean in ipairs({false, true}) do
    active = clean
    Events = {OnGameStart=event(), OnTick=event()}
    ISInventoryPane = {refreshContainer=host}
    CleanUI_Clean_ISInventoryPane = nil
    CleanUI_Vanilla_ISInventoryPane = nil
    if clean then loadCleanUIComparators() else loadVanillaComparators() end
    loadMod()
    assert(ISInventoryPane.itemSortByCatInc(bRow, aRow))
    assert(ISInventoryPane.itemSortByCatDesc(aRow, bRow))
    aRow.equipped = true
    assert(not ISInventoryPane.itemSortByCatInc(aRow, bRow))
    assert(not ISInventoryPane.itemSortByCatDesc(aRow, bRow))
    aRow.equipped = nil
    if clean then
        local separator = {type="separator", cat="AAA", name="separator"}
        assert(not ISInventoryPane.itemSortByCatInc(separator, bRow))
        assert(ISInventoryPane.itemSortByCatDesc(bRow, separator))
    end
    local stableComparator = ISInventoryPane.itemSortByCatInc
    Events.OnGameStart.fire()
    Events.OnTick.fire()
    assert(stableComparator == ISInventoryPane.itemSortByCatInc, "comparator identity churn")
end
