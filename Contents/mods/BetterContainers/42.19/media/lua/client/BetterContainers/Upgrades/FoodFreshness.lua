local Options = require("BetterContainers/_Options")

local FoodFreshness = {}

local INFINITE_AGE = 1000000000
local BAR_HEIGHT = 3
local BAR_PAD = 8
local MIN_BAR_WIDTH = 48

local function clamp01(value)
    return math.max(0, math.min(1, value))
end

local function getFreshness(item)
    if not (item and instanceof(item, "Food")) then return nil end

    local offAgeMax = item:getOffAgeMax()
    if not offAgeMax or offAgeMax <= 0 or offAgeMax >= INFINITE_AGE then return nil end

    local age = item:getAge() or 0
    local offAge = item:getOffAge() or 0
    return clamp01(1 - age / offAgeMax), clamp01(1 - offAge / offAgeMax)
end

local function getLeastFreshItem(items)
    local leastFreshItem
    local leastFreshness

    if not items then return nil end
    for _, item in ipairs(items) do
        local freshness = getFreshness(item)
        if freshness and (leastFreshness == nil or freshness < leastFreshness) then
            leastFreshItem = item
            leastFreshness = freshness
        end
    end

    return leastFreshItem
end

local function drawIndicator(pane, item, row)
    local freshness, stalePoint = getFreshness(item)
    if freshness == nil then return end

    local x = pane.column2 + BAR_PAD
    local width = pane.column3 - x - BAR_PAD

    local rowTop = pane.headerHgt + row * pane.itemHgt
    local visibleTop = rowTop + pane:getYScroll()
    if visibleTop + pane.itemHgt < pane.headerHgt or visibleTop > pane.height then return end

    if Options.showFoodFreshnessBar and width >= MIN_BAR_WIDTH then
        local y = rowTop + pane.itemHgt - BAR_HEIGHT - 1
        local fillWidth = math.floor(width * freshness + 0.5)
        local staleX = x + math.floor(width * stalePoint + 0.5)

        pane:drawRect(x, y, width, BAR_HEIGHT, 0.70, 0.10, 0.10, 0.10)

        if fillWidth > 0 then
            local fresh = freshness > stalePoint
            local r, g, b = 0.25, 0.75, 0.30
            if not fresh then
                r, g, b = 0.90, 0.55, 0.12
            end
            pane:drawRect(x, y, fillWidth, BAR_HEIGHT, 0.90, r, g, b)
        end

        pane:drawRect(staleX, y - 1, 1, BAR_HEIGHT + 2, 0.95, 0.95, 0.85, 0.45)
    end

    if Options.showFoodFreshnessPercentage then
        local text = tostring(math.floor(freshness * 100 + 0.5)) .. "%"
        local font = UIFont.Small
        local textWidth = getTextManager():MeasureStringX(font, text)
        local textX = pane.column3 - BAR_PAD - textWidth
        local textY = rowTop + math.max(0, (pane.itemHgt - getTextManager():getFontHeight(font)) / 2 - 1)

        local reservedBarHeight = Options.showFoodFreshnessBar and BAR_HEIGHT or 0
        pane:drawRect(textX - 3, rowTop + 1, textWidth + 6, pane.itemHgt - reservedBarHeight - 3, 0.72, 0.04, 0.04, 0.04)
        pane:drawText(text, textX, textY, 0.82, 0.88, 0.82, 1.0, font)
    end
end

local function drawIndicators(pane)
    if not Options.showFoodFreshnessBar and not Options.showFoodFreshnessPercentage then return end
    if not (pane and pane.itemslist and pane.mode == "details") then return end

    local row = 0
    for _, stack in ipairs(pane.itemslist) do
        local items = stack and stack.items
        drawIndicator(pane, getLeastFreshItem(items), row)

        local collapsed = pane.collapsed and stack.name and pane.collapsed[stack.name]
        if not collapsed and items then
            local last = math.min(#items, ISInventoryPane.MAX_ITEMS_IN_STACK_TO_RENDER + 1)
            for index = 2, last do
                row = row + 1
                drawIndicator(pane, items[index], row)
            end
        end

        row = row + 1
    end
end

function FoodFreshness.install()
    if FoodFreshness._installed then return end
    FoodFreshness._installed = true

    require("ISUI/ISInventoryPane")
    local oldRenderDetails = ISInventoryPane.renderdetails
    if not oldRenderDetails then return end

    ISInventoryPane.renderdetails = function(self, doDragged, ...)
        local result = oldRenderDetails(self, doDragged, ...)
        if not doDragged then
            drawIndicators(self)
        end
        return result
    end
end

return FoodFreshness
