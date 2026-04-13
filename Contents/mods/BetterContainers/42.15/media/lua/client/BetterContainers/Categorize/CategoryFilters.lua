require("ISUI/ISInventoryPane")

local FiltersUI = require("BetterContainers/Categorize/ui/FiltersUI")
local Categorize = require("BetterContainers/Categorize")

local MOD = "BetterContainers"
local DEBUG = getCore():getDebug()

local function dlog(msg)
    if not DEBUG then return end
    DebugLog.log(DebugType.General, "[" .. MOD .. "] " .. tostring(msg))
end

local CategoryFilters = {}

CategoryFilters.UNCAT_KEY = "__UNCAT__"
CategoryFilters.UNCAT_LABEL = "Uncategorised"

local function _normalizeCat(cat)
    if not cat or cat == "" then
        return CategoryFilters.UNCAT_KEY
    end
    return cat
end

local function _cloneApplied(applied)
    local staged = { map = {}, count = 0 }
    if not applied or not applied.map or not applied.count or applied.count <= 0 then
        return staged
    end

    for k, _ in pairs(applied.map) do
        staged.map[k] = true
        staged.count = staged.count + 1
    end

    return staged
end

local function _makeAppliedFromStaged(staged)
    if not staged or not staged.count or staged.count <= 0 then
        return nil
    end

    local applied = { map = {}, count = 0 }
    for k, _ in pairs(staged.map) do
        applied.map[k] = true
        applied.count = applied.count + 1
    end
    if applied.count <= 0 then
        return nil
    end
    return applied
end

local function _buildCategoryEntries(pane, showAll)
    local entries = {}
    local counts = {}
    local hasUncat = false

    -- Count categories in current context (still based on pane contents)
    local list = pane._bcItemslistUnfiltered or pane.itemslist or {}
    for i = 1, #list do
        local row = list[i]
        local cat = row and row.cat
        local norm = _normalizeCat(cat)

        -- pane.itemslist rows are "stacks"; row.count is (real items + 1) due to vanilla stacking.
        local qty = 1
        if row and row.count then
            qty = row.count - 1
            if qty < 1 then qty = 1 end
        end
        counts[norm] = (counts[norm] or 0) + qty
        if norm == CategoryFilters.UNCAT_KEY then
            hasUncat = true
        end
    end

    -- Universe: all possible categories (post-tweak), cached in Categorize.lua
    local all = {}
    if type(Categorize) == "table" and Categorize.getAllDisplayCategories then
        all = Categorize.getAllDisplayCategories() or {}
    end

    local seen = {}

    -- Always include Uncategorised so users can filter for it even when count=0
    local uncatCount = counts[CategoryFilters.UNCAT_KEY] or 0
    if showAll or uncatCount > 0 then
        seen[CategoryFilters.UNCAT_KEY] = true
        entries[#entries + 1] = {
            key = CategoryFilters.UNCAT_KEY,
            label = CategoryFilters.UNCAT_LABEL,
            checked = false,
            count = uncatCount,
        }
    end

    -- Add every category from the universe
    for i = 1, #all do
        local cat = all[i]
        local norm = _normalizeCat(cat)

        local c = counts[norm] or 0
        if (showAll or c > 0) and not seen[norm] then
            seen[norm] = true

            local label = norm
            if norm == CategoryFilters.UNCAT_KEY then
                label = CategoryFilters.UNCAT_LABEL
            end

            entries[#entries + 1] = {
                key = norm,
                label = label,
                checked = false,
                count = c,
            }
        end
    end

    table.sort(entries, function(a, b)
        -- Keep Uncategorised at the bottom (optional; remove if you want pure alpha)
        if a.key == CategoryFilters.UNCAT_KEY and b.key ~= CategoryFilters.UNCAT_KEY then return false end
        if b.key == CategoryFilters.UNCAT_KEY and a.key ~= CategoryFilters.UNCAT_KEY then return true end
        return tostring(a.label) < tostring(b.label)
    end)

    return entries, hasUncat
end

local function _syncChecksFromStaged(entries, staged)
    if not entries or not staged then return end
    for i = 1, #entries do
        local e = entries[i]
        e.checked = staged.map[e.key] == true
    end
end

function CategoryFilters.openPopup(pane, button)
    if pane._bcFiltersPopup then
        pane._bcFiltersPopup:close()
        pane._bcFiltersPopup = nil
        return
    end

    pane:refreshContainer()

    local entries = _buildCategoryEntries(pane, false)
    local staged = _cloneApplied(pane._bcCategoryFilterApplied)
    _syncChecksFromStaged(entries, staged)

    local x = button:getAbsoluteX()
    local y = button:getAbsoluteY() + button.height

    local w = 450
    local h = 300

    local ui = FiltersUI:new(x, y, w, h, pane.player)
    ui:initialise()
    ui:instantiate()

    ui:configure(
        entries,
        staged,
        function(_staged)
            pane._bcCategoryFilterApplied = _makeAppliedFromStaged(_staged)
            pane:refreshContainer()
            ISInventoryPage.dirtyUI()
        end,
        function()
            pane._bcCategoryFilterApplied = nil
            pane:refreshContainer()
            ISInventoryPage.dirtyUI()
        end,
        function()
            pane._bcFiltersPopup = nil
        end,
        function(showAll, _staged)
            pane:refreshContainer()
            local newEntries = _buildCategoryEntries(pane, showAll == true)
            _syncChecksFromStaged(newEntries, _staged)
            return newEntries
        end
    )

    pane._bcFiltersPopup = ui
    ui:addToUIManager()
    -- Ensure top-most
    ui.alwaysOnTop = true
    if ui.setAlwaysOnTop then
        ui:setAlwaysOnTop(true)
    end
    ui:bringToTop()
end

function CategoryFilters.installInventoryPaneFilterButtonPatch()
    if CategoryFilters._installedFilterBtn then return end
    CategoryFilters._installedFilterBtn = true

    local _vanilla_onFilterMenu = ISInventoryPane.onFilterMenu

    function ISInventoryPane:onFilterMenu(button)
        -- Keep vanilla safety gate
        local playerObj = getSpecificPlayer(self.player)
        if playerObj and playerObj.isAsleep and playerObj:isAsleep() then return end

        -- Open our popup instead of vanilla weight sort menu
        return CategoryFilters.openPopup(self, button)
    end

    local _vanilla_createChildren = ISInventoryPane.createChildren
    function ISInventoryPane:createChildren()
        _vanilla_createChildren(self)
        local filterButton = self.filterMenu
        if filterButton then
            filterButton.tooltip = getTextOrNull("Tooltip_FilterMenu") or "Category Filters Menu"
        end
    end

    CategoryFilters._vanilla_onFilterMenu = _vanilla_onFilterMenu
end

function CategoryFilters.installInventoryPaneFilteringPatch()
    if CategoryFilters._installedFilterRefresh then return end
    CategoryFilters._installedFilterRefresh = true

    local _vanilla_refreshContainer = ISInventoryPane.refreshContainer

    function ISInventoryPane:refreshContainer(...)
        _vanilla_refreshContainer(self, ...)

        self._bcItemslistUnfiltered = self.itemslist

        local applied = self._bcCategoryFilterApplied
        if not applied or not applied.map or not applied.count or applied.count <= 0 then
            return
        end

        local src = self.itemslist or {}
        local out = {}
        for i = 1, #src do
            local row = src[i]
            local cat = row and row.cat
            local key = _normalizeCat(cat)
            if applied.map[key] then
                out[#out + 1] = row
            end
        end

        self.itemslist = out
        self:setScrollHeight(#out * self.itemHgt)
        self:setScrollWidth(0)
    end

    CategoryFilters._vanilla_refreshContainer = _vanilla_refreshContainer
end

function CategoryFilters.install()
    CategoryFilters.installInventoryPaneFilterButtonPatch()
    CategoryFilters.installInventoryPaneFilteringPatch()
end

CategoryFilters.install()

return CategoryFilters