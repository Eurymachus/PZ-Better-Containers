local active = true
local categoryReads = 0
local helpers = { isCleanUIActive = function() return active end }
local category = { get = function(item)
    categoryReads = categoryReads + 1
    return item.category
end }
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

-- A third-party wrapper retaining ours must decorate only once, at the end.
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
assert(p.itemslist[1].cat == "Aardvark", "decorated before outer host finished")

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
