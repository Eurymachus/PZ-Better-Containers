-- Protected calls belong only in this harness, to assert error propagation and
-- verify the live UI remains unchanged after deliberately failing callbacks.
local function fails(fn)
    local ok, err, trace = pcall(fn)
    assert(not ok and (tostring(err):find("injected", 1, true) or tostring(trace):find("at boom:", 1, true)), tostring(err) .. " | " .. tostring(trace))
end
local function boom() error("injected") end
local function event() return {Add = function() end} end
Events = setmetatable({}, {__index = function(t, k) local e = event(); t[k] = e; return e end})
LuaEventManager = {AddEvent = function() end}
isDebugEnabled = function() return false end
getTexture = function(name) return name end
getText = function(key) return key end
getTextOrNull = function() end
getTextManager = function() return {getFontHeight = function() return 12 end} end
UIFont = {Small = 1}
local clean = false
local helpers = {isCleanUIActive = function() return clean end, dlog = function() end, OPTIONS_APPLIED = "options"}
local options = {inventoryLeft_Player = true, inventoryLeft_Loot = false, showEquippedAttachedSection = true}
local category = {get = function(it) return it.category or "Clothes" end,
    getDisplayName = function(id) return id end, setEnabled = function() end}
local ini = {makeFeature = function() return {get = function() return {} end,
    loadAll = function() return {} end} end}
local proximity = {invName = "nearby", invName_corpses = "nearby_corpses"}
local modules = { ["BetterContainers/Helpers"] = helpers, ["BetterContainers/_Options"] = options,
    ["BetterContainers/_IO/IniWriter"] = ini, ["BetterContainers/Proximity"] = proximity,
    ["BetterContainers/Categorize/InventoryCategory"] = category }
require = function(name) return modules[name] or {} end
getSpecificPlayer = function() return {getJoypadBind = function() return 0 end} end

-- Left-strip cycling: preserve vanilla direction, wrapping, controller choice,
-- hit testing, and the real page identity. No mouse method is ever replaced.
local time = 1000
getTimestampMs = function() return time end
local fallback = 0
ISInventoryPage = {onMouseWheel = function() fallback = fallback + 1; return "right" end}
loadSwitchSides().install()
local page = setmetatable({onCharacter = true, buttonSize = 20, player = 0,
    backpacks = {"first", "second"}, containerButtonPanel = {height = 20, getScrollHeight = function() return 40 end},
    x = 5, getMouseX = function(self) return self.x end, getWidth = function() return 200 end,
    isCycleContainerKeyDown = function(self) return self.cycleKey end,
    getCurrentBackpackIndex = function() return 1 end,
    prevUnlockedContainer = function(self, index, wrap) self.direction = "prev"; self.wrap = wrap; return 2 end,
    nextUnlockedContainer = function(self, index, wrap) self.direction = "next"; self.wrap = wrap; return 2 end},
    {__index = ISInventoryPage})
page.selectContainer = function(self, button) assert(self == page); self.chosen = button end
local mouse = page.getMouseX
assert(page:onMouseWheel(-1) and page.direction == "prev" and page.wrap and page.backpackChoice == 2)
time = 1100
assert(page:onMouseWheel(1) and page.direction == "next" and not page.wrap)
page.x = 60
assert(page:onMouseWheel(1) == false)
page.cycleKey = true
assert(page:onMouseWheel(1))
page.selectContainer = boom
fails(function() page:onMouseWheel(1) end)
assert(page.getMouseX == mouse and page:getMouseX() == 60)
page.onCharacter = false
assert(page:onMouseWheel(1) == "right" and fallback == 1)
clean = true
ISInventoryPage = {onMouseWheel = mouse}
loadSwitchSides().install()
assert(ISInventoryPage.onMouseWheel == mouse)
clean = false

-- Equipped-section drawing uses a disposable view. All live methods, hover
-- state and the global icon dispatcher survive errors from any draw stage.
local stage
local texts, icons = {}, 0
local equipment = {getName = function() return "Boots" end, getTex = function() return "boots" end}
local stack = {_bcEquippedAttachedSeparator = true, _bcEquippedAttachedCount = 1,
    _bcEquippedAttachedItems = {equipment}, name = "section", items = {equipment, equipment}}
local pane
local function icon(self) assert(self == pane); icons = icons + 1 end
ISInventoryItem = {renderItemIcon = icon}
ISInventoryPane = {renderdetails = function(self, dragged)
    assert(self.itemSortFunc == pane.itemSortFunc, "sort indicator identity changed")
    self.renderCount = (self.renderCount or 0) + 1
    self:refreshContainer() -- Must receive the real pane, not retain the view.
    if stage == "render" then boom() end
    self:drawText("Boots", 50, 31, 1, 1, 1, 1)
    self:drawText("Clothes", 110, 31, 1, 1, 1, 1)
    self:drawTexture("badge", 10, 31)
    ISInventoryItem.renderItemIcon(self, equipment, 10, 31, 1, 20, 20)
    if not dragged then assert(self.mouseOverOption == 0) end
    return "rendered"
end}
loadEquippedAttachedSection().install()
pane = setmetatable({itemslist = {{name = "normal", items = {equipment, equipment}}, stack},
    items = {{}, stack}, collapsed = {normal = true, section = true},
    itemHgt = 20, headerHgt = 10, column2 = 40, column3 = 100, column4 = 180,
    mouseOverOption = 2, player = 0, refreshContainer = function(self) assert(self == pane) end,
    itemSortFunc = function(a, b) return a.name < b.name end,
    getMouseX = function() return 50 end, getMouseY = function() return 31 end,
    getYScroll = function() return 0 end, getHeight = function() return 200 end,
    drawText = function(self, text) assert(self == pane); if stage == "text" then boom() end; texts[#texts+1] = text end,
    drawTexture = function() error("header badge should be suppressed") end,
    drawTextureScaled = function(self) assert(self == pane); if stage == "icon" then boom() end; icons = icons + 1 end,
    drawRect = function(self) assert(self == pane); if stage == "overlay" then boom() end end}, {__index = ISInventoryPane})
getCore = function() return {getOptionFontSizeReal = function() return 1 end} end
local drawText, drawTexture, drawScaled = pane.drawText, pane.drawTexture, pane.drawTextureScaled
local dispatch = ISInventoryItem.renderItemIcon
for _, failure in ipairs({"render", "text", "icon", "overlay"}) do
    stage = failure
    fails(function() pane:renderdetails(false) end)
    assert(pane.drawText == drawText and pane.drawTexture == drawTexture and pane.drawTextureScaled == drawScaled)
    assert(pane.mouseOverOption == 2 and ISInventoryItem.renderItemIcon == dispatch)
    assert(rawget(pane, "_bcSectionRenderItemIcon") == nil)
end
stage = nil
texts = {}
assert(pane:renderdetails(false) == "rendered")
assert(texts[1] == "Equipped Items (1)" and texts[2] == "")
assert(pane:renderdetails(true) == "rendered")
local before = icons
ISInventoryItem.renderItemIcon(pane, equipment)
assert(icons == before + 1 and pane.mouseOverOption == 2)

-- Real metadata and translation helpers: missing data still falls back, while
-- actual errors propagate rather than being mistaken for missing data.
local store = loadCategoryStore()
store.loaded = true
store.definitions = {Custom = {displayName = "My Category"}}
modules["BetterContainers/Categorize/CategoryStore"] = store
Translator = nil
assert(store.injectCustomTranslations() == false)
local translations = {}
Translator = {BY_NAME = {get = function() return {put = function(_, k, v) translations[k] = v end} end}}
assert(store.injectCustomTranslations() and translations.IGUI_ItemCat_Custom == "My Category")
Translator.BY_NAME.get = boom
fails(store.injectCustomTranslations)
Translator = nil
ISCollapsableWindow = {derive = function() return {} end}
local ui = loadCategoryUI()
assert(ui.name({}, "Base.Fallback") == "Base.Fallback" and not ui.hidden({}))
assert(ui.name({getDisplayName = function() return "Label" end}, "type") == "Label")
assert(ui.hidden({isHidden = function() return true end}))
fails(function() ui.name({getDisplayName = boom}, "type") end)
fails(function() ui.hidden({isHidden = boom}) end)
local menu = loadContextMenu()
assert(menu.text("missing", "fallback") == "fallback")
getText = function() return "translated" end
assert(menu.text("key", "fallback") == "translated")
getText = boom
fails(function() menu.text("key") end)
getText = function(k) return k end
options.showAdvancedDisplayCategories = true
local categorize = loadCategorize()
assert(categorize.blacklist({getDisplayCategory = function() return " Food " end}, {food = true}))
assert(not categorize.blacklist({getDisplayCategory = function() end}, {food = true}))
fails(function() categorize.blacklist({getDisplayCategory = boom}, {food = true}) end)
local previousRequire = require
require = function(name) if name:find("Categories/", 1, true) then boom() end; return previousRequire(name) end
fails(categorize.load)
require = previousRequire

-- Load every bundled category pack through the real loader. Enabling every
-- optional mapping also catches a missing path formerly hidden by pcall.
getActivatedMods = function() return {contains = function() return true end} end
local sampleScript = {getFullName = function() return "Base.UnmappedTest" end,
    getDisplayCategory = function() return "UnmappedCategory" end}
getAllItems = function() return {size = function() return 1 end, get = function() return sampleScript end} end
local loadedPacks = 0
require = function(name)
    if name:find("Categories/", 1, true) then
        assert(categoryLoaders[name], "missing category pack: " .. name)
        loadedPacks = loadedPacks + 1
        return categoryLoaders[name]()
    end
    return previousRequire(name)
end
categorize.load()
assert(loadedPacks > 20 and store.defaults["Base.UnmappedTest"] == "UnmappedCategory")
local categories = categorize.module.getAllDisplayCategories()
local found = false
for _, id in ipairs(categories) do if id == "UnmappedCategory" then found = true end end
assert(found)
require = previousRequire

-- A game session can load the mod without firing OnMainMenuEnter afterward.
-- Saved options equal to the defaults must still initialize the real resolver.
local realCategory = loadInventoryCategory()
modules["BetterContainers/Categorize/InventoryCategory"] = realCategory
local session = loadCategorize()
local radio = {getFullType = function() return "Base.WalkieTalkie4" end,
    getDisplayCategory = function() return "Communications" end}
local scriptRadio = {getDisplayCategory = radio.getDisplayCategory}
ScriptManager = {instance = {getItem = function() return scriptRadio end}}
require = function(name)
    if categoryLoaders[name] then return categoryLoaders[name]() end
    return previousRequire(name)
end
session.update()
store.setOverride("Base.WalkieTalkie4", "ClothingFeet")
assert(realCategory.get(radio) == "ClothingFeet", "unchanged startup options left category resolver disabled")
-- All presentation consumers must ignore a category overwritten by a later mod.
radio.getName = function() return "Tactical Walkie Talkie" end
radio.getJobDelta = function() return 0 end
local stale = {items = {radio, radio}, cat = "Communications", count = 2}
assert(realCategory.getRow(stale) == "ClothingFeet")
assert(BetterContainersInventoryCategory == realCategory, "optional API missing")
local drawn
loadCategoryDraw()(realCategory, {column3=0, itemHgt=20, headerHgt=0,
    drawText=function(_, text) drawn=text end}, radio, stale)
assert(drawn == realCategory.getDisplayName("ClothingFeet"), "renderer trusted overwritten cat")
local search = loadSearchBar()
assert(search.matches({player=0}, stale, "clothingfeet"), "search missed resolved category")
assert(not search.matches({player=0}, stale, "communications"), "search used overwritten category")
modules["BetterContainers/Categorize"] = {getAllDisplayCategories=function() return {"ClothingFeet", "Communications"} end}
getCore = function() return {getDebug=function() return false end} end
ISInventoryPane = {refreshContainer=function(self) self.itemslist={stale} end}
local filters = loadCategoryFilters()
local entries = filters.entries({itemslist={stale}}, false)
assert(#entries == 1 and entries[1].key == "ClothingFeet" and entries[1].count == 1)
filters.module.installInventoryPaneFilteringPatch()
local filtered = setmetatable({_bcCategoryFilterApplied={map={ClothingFeet=true},count=1}, selected={}, itemHgt=20,
    saveSelection=function() return {} end, restoreSelection=function() end,
    setScrollHeight=function() end, setScrollWidth=function() end}, {__index=ISInventoryPane})
filtered:refreshContainer()
assert(#filtered.itemslist == 1, "filter rejected resolved category")
filtered._bcCategoryFilterApplied.map = {Communications=true}
filtered:refreshContainer()
assert(#filtered.itemslist == 0, "filter accepted overwritten category")
local refreshed = 0
ISInventoryPage = {dirtyUI = function() refreshed = refreshed + 1 end}
local playerRefreshes, lootRefreshes = 0, 0
local playerPane = {inventory = {}, refreshContainer = function(self)
    playerRefreshes = playerRefreshes + 1
    self.itemslist = {{items = {radio}, cat = realCategory.get(radio)}}
end}
local lootPane = {inventory = {}, refreshContainer = function(self)
    lootRefreshes = lootRefreshes + 1
    self.itemslist = {{items = {radio}, cat = realCategory.get(radio)}}
end}
getNumActivePlayers = function() return 1 end
getPlayerInventory = function() return {inventoryPane = playerPane} end
getPlayerLoot = function() return {inventoryPane = lootPane} end
assert(session.module.applySingleCategoryChange("Base.WalkieTalkie4", false))
assert(refreshed == 1)
assert(playerRefreshes == 1 and lootRefreshes == 1, "live panes were not refreshed")
assert(playerPane.itemslist[1].cat == "ClothingFeet" and lootPane.itemslist[1].cat == "ClothingFeet")
store.setOverride("Base.WalkieTalkie4", "ClothingLegs")
session.module.applySingleCategoryChange("Base.WalkieTalkie4", false)
assert(lootPane.itemslist[1].cat == "ClothingLegs", "loot row retained old assignment")
store.resetOverride("Base.WalkieTalkie4")
session.module.applySingleCategoryChange("Base.WalkieTalkie4", false)
assert(lootPane.itemslist[1].cat == "Communications")
assert(realCategory.get(radio) == "Communications")
options.showAdvancedDisplayCategories = false
session.update()
store.setOverride("Base.WalkieTalkie4", "ClothingFeet")
assert(realCategory.get(radio) == "Communications", "disabled option ignored")
options.showAdvancedDisplayCategories = true
session.update()
assert(realCategory.get(radio) == "ClothingFeet", "re-enable lost assignment")
require = previousRequire
modules["BetterContainers/Categorize/InventoryCategory"] = category
getNumActivePlayers = nil
getPlayerInventory = nil
getPlayerLoot = nil

local nested = loadNested()
nested._ignoredInventoryPredicates = {}
local inventory = {getType = function() return "bag" end}
nested.addIgnoredInventoryPredicate("test", function() return true end)
assert(nested.isIgnoredInventory({}, inventory))
nested.removeIgnoredInventoryPredicate("test")
assert(not nested.isIgnoredInventory({}, inventory))
nested.addIgnoredInventoryPredicate("broken", boom)
fails(function() nested.isIgnoredInventory({}, inventory) end)

local realHelpers = loadHelpers()
local fallbackCalls = 0
instanceItem = function() fallbackCalls = fallbackCalls + 1; return {getTexture = function() return "fallbackTexture" end} end
ScriptManager = {instance = {getItem = function() return {getIcon = function() return "Hammer" end} end}}
assert(realHelpers.getIconTexture("Base.TestIcon") == "Hammer")
ScriptManager.instance.getItem = function() end
assert(realHelpers.getIconTexture("Base.MissingIcon") == "fallbackTexture" and fallbackCalls == 1)
ScriptManager.instance.getItem = boom
fails(function() realHelpers.getIconTexture("Base.BrokenIcon") end)
assert(fallbackCalls == 1)

-- Smart Deposit: correct overloads and reservations, missing metadata, lock
-- checks, and no fallback to an item-only check that could overbook capacity.
instanceof = function(obj, name) return obj.kind == name end
local smart = loadSmartDeposit()
assert(smart.type({}) == nil and smart.fullType({}) == nil and smart.weight({}) == 0)
assert(smart.weight({getActualWeight = function() return 3 end}) == 3)
local moving = {getFullType = function() return "Base.Food" end, getUnequippedWeight = function() return 2 end}
assert(smart.fullType(moving) == "Base.Food" and smart.weight(moving) == 2)
local args
local container = {isItemAllowed = function() return true end,
    hasRoomFor = function(_, ...) args = {...}; return true end}
local player = {}
assert(smart.room(container, player, moving, 0) and args[1] == player and args[2] == moving and #args == 2)
assert(smart.room(container, player, moving, 3) and args[2] == 5 and args[3] == 5)
container.hasRoomFor = boom
fails(function() smart.room(container, player, moving, 3) end)
container.isItemAllowed = function() return false end
assert(not smart.room(container, player, moving, 0))
local locked = {kind = "IsoThumpable", isLockedToCharacter = function() return true end}
assert(smart.locked({getParent = function() return locked end}, player))
locked.isLockedToCharacter = boom
fails(function() smart.locked({getParent = function() return locked end}, player) end)
fails(function() smart.weight({getUnequippedWeight = boom}) end)
ISInventoryPane = {transferItemsByWeight = function() return "vanilla" end}
ISInventoryPage = {}
ISInventoryPaneDraggedItems = nil
smart.module.install()
assert(ISInventoryPane.transferItemsByWeight({}, {}, {getType = function() return "bag" end}) == "vanilla")
fails(function() ISInventoryPane.transferItemsByWeight({sortItemsByTypeAndWeight = boom}, {},
    {getType = function() return "nearby" end}) end)

-- Run the real planner with multiple items. Exact type wins over category,
-- category wins over an empty container, and reservations prevent overfilling.
options.getEffectivePermissions = function() return {} end
local function list(values)
    return {size = function() return #values end, get = function(_, index) return values[index + 1] end}
end
local origin = {}
local function depositItem(fullType, cat)
    return {category = cat, getFullType = function() return fullType end,
        getUnequippedWeight = function() return 2 end, getContainer = function() return origin end}
end
local function storage(contents, capacity)
    return {getType = function() return "crate" end, getItems = function() return list(contents) end,
        isItemAllowed = function() return true end,
        hasRoomFor = function(_, _, value)
            local weight = type(value) == "number" and value or value:getUnequippedWeight()
            return weight <= capacity
        end}
end
local first, second, third = depositItem("Base.Apple", "Food"), depositItem("Base.Apple", "Food"), depositItem("Base.Apple", "Food")
local empty = storage({}, 20)
local categoryMatch = storage({depositItem("Base.Pear", "Food")}, 2)
local exactMatch = storage({depositItem("Base.Apple", "Food")}, 2)
getPlayerLoot = function() return {backpacks = {
    {inventory = empty}, {inventory = categoryMatch}, {inventory = exactMatch}}} end
local plan = smart.plan(0, player, {first, second, third}, {})
assert(plan.destinationOrder[1] == exactMatch and plan.destinationOrder[2] == categoryMatch and plan.destinationOrder[3] == empty)
assert(plan.groupedItems[exactMatch][1] == first and plan.groupedItems[categoryMatch][1] == second and plan.groupedItems[empty][1] == third)
