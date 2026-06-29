local Options = require("BetterContainers/_Options")
local Proximity = require("BetterContainers/Proximity")

local Nested = {}

Nested._installed = false
-- Weak keys keep temporary inventory instances from being pinned in memory.
Nested._ignoredInventories = setmetatable({}, { __mode = "k" })
Nested._ignoredInventoryTypes = {}
Nested._ignoredInventoryPredicates = {}
Nested.maxDepth = 10

local PLAYER_FILTER_EVERYTHING = 1
local PLAYER_FILTER_ONLY_POCKETS = 2
local PLAYER_FILTER_ONLY_EQUIPPED = 3

local function isEnabled(inventoryPage)
    if not inventoryPage then return false end

    if inventoryPage.onCharacter then
        return Options.enableNestedContainers_Player == true
    end

    return Options.enableNestedContainers_Loot == true
end

local function getMaxDepth()
    local depth = tonumber(Options.nestedContainersDepth) or Nested.maxDepth
    if depth < 1 then return 1 end
    if depth > Nested.maxDepth then return Nested.maxDepth end

    return depth
end

local function isProximityInventory(inventory)
    local invType = inventory and inventory:getType() or nil
    return Proximity.isProximityType(invType)
end

local function isBlockedLootVehicleContainer(inventory)
    if not inventory then return false end

    local part = inventory:getVehiclePart()
    if part and part:getCategory() == "seat" then
        return true
    end

    local invType = inventory:getType() or ""
    return string.find(invType, "TruckBed", 1, true) ~= nil
        or string.find(invType, "Trailer", 1, true) ~= nil
        or string.find(invType, "Trunk", 1, true) ~= nil
end

local function isFilteredPlayerInventory(inventoryPage, inventory)
    if not inventoryPage or not inventoryPage.onCharacter then return false end

    local playerObj = getSpecificPlayer(inventoryPage.player)
    if not playerObj then return false end

    local filter = Options.nestedContainersPlayerFilter or PLAYER_FILTER_EVERYTHING
    if filter == PLAYER_FILTER_EVERYTHING then return false end

    if filter == PLAYER_FILTER_ONLY_POCKETS then
        local item = inventory:getContainingItem()
        return item and playerObj:isEquipped(item)
    end

    if filter == PLAYER_FILTER_ONLY_EQUIPPED then
        return inventory == playerObj:getInventory()
    end

    return false
end

-- Public API: ignore every inventory matching this exact inventory type.
-- Example: require("BetterContainers/Nested").addIgnoredInventoryType("MyModContainer")
function Nested.addIgnoredInventoryType(invType)
    if not invType or invType == "" then return false end

    Nested._ignoredInventoryTypes[invType] = true
    return true
end

-- Public API: stop ignoring a type previously registered through addIgnoredInventoryType.
function Nested.removeIgnoredInventoryType(invType)
    if not invType or invType == "" then return false end

    Nested._ignoredInventoryTypes[invType] = nil
    return true
end

-- Public API: ignore one specific inventory instance.
-- This is useful when a mod has the inventory object but no stable unique type.
function Nested.addIgnoredInventory(inventory)
    if not inventory then return false end

    Nested._ignoredInventories[inventory] = true
    return true
end

-- Public API: stop ignoring one specific inventory instance.
function Nested.removeIgnoredInventory(inventory)
    if not inventory then return false end

    Nested._ignoredInventories[inventory] = nil
    return true
end

-- Public API: register custom ignore logic.
-- Predicate signature is function(inventoryPage, inventory) and should return true
-- when Nested Containers should skip that inventory.
-- The id lets other mods replace or remove their own rule later.
function Nested.addIgnoredInventoryPredicate(id, predicate)
    if not id or id == "" or type(predicate) ~= "function" then return false end

    Nested._ignoredInventoryPredicates[id] = predicate
    return true
end

-- Public API: remove custom ignore logic by the same id used to register it.
function Nested.removeIgnoredInventoryPredicate(id)
    if not id or id == "" then return false end

    Nested._ignoredInventoryPredicates[id] = nil
    return true
end

-- Public API: shared ignore check used internally and available to integrations.
function Nested.isIgnoredInventory(inventoryPage, inventory)
    if not inventory then return true end

    if Nested._ignoredInventories[inventory] then
        return true
    end

    local invType = inventory:getType()
    if invType and Nested._ignoredInventoryTypes[invType] then
        return true
    end

    -- External predicates are sandboxed so bad compatibility code cannot break refresh.
    for _, predicate in pairs(Nested._ignoredInventoryPredicates) do
        local ok, shouldIgnore = pcall(predicate, inventoryPage, inventory)
        if ok and shouldIgnore then
            return true
        end
    end

    return false
end

local function shouldAddItemContainer(inventoryPage, item)
    if not item or not item:IsInventoryContainer() then return false end

    -- Equipped bags already have their own player inventory buttons.
    if inventoryPage.onCharacter then
        local playerObj = getSpecificPlayer(inventoryPage.player)
        if playerObj and playerObj:isEquipped(item) then
            return false
        end

        if item.isKeyRing and item:isKeyRing() then
            return false
        end
    end

    local inventory = item:getInventory()
    if not inventory or Nested.isIgnoredInventory(inventoryPage, inventory) then
        return false
    end

    return true
end

local function applyParentIcon(button, item)
    if not Options.showNestedContainerParentIcon then return end
    if not button or not item then return end

    local parentContainer = item:getContainer()
    if not parentContainer then return end

    local parentItem = parentContainer:getContainingItem()
    if not parentItem then return end

    local parentTex = parentItem:getTex()
    if not parentTex then return end

    if not button._bcNestedRender then
        button._bcNestedRender = button.render
    end

    button.render = function(self)
        if self._bcNestedRender then
            self._bcNestedRender(self)
        end

        local margin = 1
        local iconSize = self.height / 2
        self:drawTextureScaled(parentTex, self.width - iconSize - margin, self.height - iconSize - margin, iconSize, iconSize, 1)
    end
end

local function addNestedButton(inventoryPage, item)
    local button = inventoryPage:addContainerButton(
        item:getInventory(),
        item:getTex(),
        item:getName(),
        item:getName()
    )

    if button and item:getVisual() and item:getClothingItem() then
        local tint = item:getVisual():getTint(item:getClothingItem())
        if tint then
            button:setTextureRGBA(tint:getRedFloat(), tint:getGreenFloat(), tint:getBlueFloat(), 1.0)
        end
    end

    applyParentIcon(button, item)

    return button
end

local function scanInventory(inventoryPage, inventory, depth, visited)
    if depth > getMaxDepth() then return end
    if Nested.isIgnoredInventory(inventoryPage, inventory) then return end
    if isFilteredPlayerInventory(inventoryPage, inventory) then return end
    if visited[inventory] then return end

    visited[inventory] = true

    local items = inventory:getItems()
    if not items then return end

    -- Add a button for each nested container, then keep walking into that container.
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if shouldAddItemContainer(inventoryPage, item) then
            local itemInventory = item:getInventory()
            if not visited[itemInventory] then
                addNestedButton(inventoryPage, item)
                scanInventory(inventoryPage, itemInventory, depth + 1, visited)
            end
        end
    end
end

function Nested.OnButtonsAdded(inventoryPage)
    if not isEnabled(inventoryPage) then return end
    if not inventoryPage or not inventoryPage.backpacks then return end

    local visited = {}
    -- Only scan the buttons that existed before we started adding nested buttons.
    local originalButtonCount = #inventoryPage.backpacks

    for i = 1, originalButtonCount do
        local button = inventoryPage.backpacks[i]
        local inventory = button and button.inventory or nil
        scanInventory(inventoryPage, inventory, 1, visited)
    end
end

function Nested.install()
    if Nested._installed then return end
    Nested._installed = true

    Events.OnRefreshInventoryWindowContainers.Add(function(inventoryPage, state)
        if state == "buttonsAdded" then
            Nested.OnButtonsAdded(inventoryPage)
        end
    end)
end

-- Compatibility aliases for mod authors that prefer the shorter wording.
Nested.ignoreInventory = Nested.addIgnoredInventory
Nested.unignoreInventory = Nested.removeIgnoredInventory
Nested.ignoreInventoryType = Nested.addIgnoredInventoryType
Nested.unignoreInventoryType = Nested.removeIgnoredInventoryType
Nested.ignoreInventoryPredicate = Nested.addIgnoredInventoryPredicate
Nested.unignoreInventoryPredicate = Nested.removeIgnoredInventoryPredicate

-- Built-in ignores use the same public API other mods use.
Nested.addIgnoredInventoryType("floor")

Nested.addIgnoredInventoryPredicate("BetterContainers.Proximity", function(_, inventory)
    return isProximityInventory(inventory)
end)

Nested.addIgnoredInventoryPredicate("BetterContainers.VehicleLoot", function(inventoryPage, inventory)
    return inventoryPage and not inventoryPage.onCharacter and isBlockedLootVehicleContainer(inventory)
end)

return Nested
