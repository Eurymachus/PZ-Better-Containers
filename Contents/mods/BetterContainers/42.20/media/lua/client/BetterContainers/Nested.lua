local Options = require("BetterContainers/_Options")
local Proximity = require("BetterContainers/Proximity")
local IniWriter = require("BetterContainers/_IO/IniWriter")

local Nested = {}

Nested._installed = false
-- Weak keys keep temporary inventory instances from being pinned in memory.
Nested._ignoredInventories = setmetatable({}, { __mode = "k" })
Nested._ignoredInventoryTypes = {}
Nested._ignoredInventoryPredicates = {}
Nested._userIgnoredInventoryTypes = {}
Nested.maxDepth = 10

local PLAYER_FILTER_EVERYTHING = 1
local PLAYER_FILTER_ONLY_POCKETS = 2
local PLAYER_FILTER_ONLY_EQUIPPED = 3
local IGNORED_TYPES_INI = IniWriter.makeFeature("NestedContainers", false)
local IGNORED_TYPES_SECTION = "IgnoredContainerTypes"
local ignoredTypesLoaded = false
local ignoredTypesDirty = false

local function sortedEnabledKeys(values)
    local keys = {}
    for key, enabled in pairs(values or {}) do
        if enabled then
            table.insert(keys, tostring(key))
        end
    end
    table.sort(keys)
    return keys
end

function Nested.loadUserIgnoredInventoryTypes()
    if ignoredTypesLoaded then return true end

    Nested._userIgnoredInventoryTypes = {}
    local row = IGNORED_TYPES_INI.get(IGNORED_TYPES_SECTION) or {}
    for invType, enabled in pairs(row) do
        if enabled ~= nil and tostring(enabled) ~= "0" and tostring(enabled) ~= "false" then
            Nested._userIgnoredInventoryTypes[tostring(invType)] = true
        end
    end

    ignoredTypesLoaded = true
    ignoredTypesDirty = false
    return true
end

function Nested.setUserIgnoredInventoryType(invType, ignored)
    if not invType or invType == "" then return false end
    Nested.loadUserIgnoredInventoryTypes()

    ignored = ignored == true
    if (Nested._userIgnoredInventoryTypes[invType] == true) == ignored then
        return false
    end

    Nested._userIgnoredInventoryTypes[invType] = ignored and true or nil
    ignoredTypesDirty = true
    return true
end

function Nested.saveUserIgnoredInventoryTypes()
    if not ignoredTypesDirty then return false end

    local order = sortedEnabledKeys(Nested._userIgnoredInventoryTypes)
    if #order == 0 then
        IGNORED_TYPES_INI.delete(IGNORED_TYPES_SECTION)
    else
        local row = {}
        for _, invType in ipairs(order) do
            row[invType] = "1"
        end
        IGNORED_TYPES_INI.setOrdered(IGNORED_TYPES_SECTION, row, order)
    end

    ignoredTypesDirty = false
    return true
end

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

    Nested.loadUserIgnoredInventoryTypes()
    if invType and Nested._userIgnoredInventoryTypes[invType] then
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

local function isSupportedMultiplayerLootParent(inventoryPage, parentInventory)
    if not isClient() or inventoryPage.onCharacter then return true end

    -- ContainerID can identify an item-owned inventory in a player's inventory.
    -- On the loot side it only has a nested representation for an item directly
    -- inside a vehicle part. World objects, corpses, floor containers, and deeper
    -- vehicle nesting resolve to no source container on the server.
    return parentInventory and parentInventory:getVehiclePart() ~= nil
end

local function shouldAddItemContainer(inventoryPage, item, parentInventory)
    if not item or not item:IsInventoryContainer() then return false end

    if not isSupportedMultiplayerLootParent(inventoryPage, parentInventory) then
        return false
    end

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

    -- True nested containers are item-owned inventories. Some multi-tile IsoObjects
    -- expose sibling object containers while scanning another tile/container; those
    -- should remain top-level world containers, not nested child buttons.
    if inventory:getContainingItem() ~= item then
        return false
    end

    return true
end

local function getParentIconTexture(parentInventory, inventoryPage)
    if not parentInventory then return nil end

    local parentItem = parentInventory:getContainingItem()
    if parentItem then
        return parentItem:getTex()
    end

    local hasWorldParent = parentInventory:getParent() ~= nil
    local hasVehicleParent = parentInventory:getVehiclePart() ~= nil
    if not hasWorldParent and not hasVehicleParent then
        return nil
    end

    local invType = parentInventory:getType()
    return (invType and ContainerButtonIcons[invType])
        or (inventoryPage and inventoryPage.conDefault)
end

local function clearParentIcon(button)
    if not button or not button._bcNestedRender then return end

    button.render = button._bcNestedRender
    button._bcNestedRender = nil
end

local function applyParentIcon(button, parentInventory, inventoryPage)
    clearParentIcon(button)

    if not Options.showNestedContainerParentIcon then return end
    if not button or not parentInventory then return end

    local parentTex = getParentIconTexture(parentInventory, inventoryPage)
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

local function addNestedButton(inventoryPage, item, parentInventory)
    local button = inventoryPage:addContainerButton(
        item:getInventory(),
        item:getTex(),
        item:getName(),
        item:getName()
    )

    clearParentIcon(button)

    if button and item:getVisual() and item:getClothingItem() then
        local tint = item:getVisual():getTint(item:getClothingItem())
        if tint then
            button:setTextureRGBA(tint:getRedFloat(), tint:getGreenFloat(), tint:getBlueFloat(), 1.0)
        end
    end

    applyParentIcon(button, parentInventory, inventoryPage)

    return button
end

local function scanInventory(inventoryPage, inventory, depth, visited, existingButtons)
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
        if shouldAddItemContainer(inventoryPage, item, inventory) then
            local itemInventory = item:getInventory()
            if not visited[itemInventory] then
                if not (existingButtons and existingButtons[itemInventory]) then
                    addNestedButton(inventoryPage, item, inventory)
                    inventoryPage.bcNestedParents[itemInventory] = inventory
                end
                scanInventory(inventoryPage, itemInventory, depth + 1, visited, existingButtons)
            end
        end
    end
end

local function isWithinContainer(container, ancestor)
    local visited = {}

    while container and not visited[container] do
        if container == ancestor then return true end
        visited[container] = true

        local containingItem = container:getContainingItem()
        container = containingItem and containingItem:getContainer() or nil
    end

    return false
end

local function nestedAncestorsHaveRoom(character, item, source, destination)
    if not item or not destination then return true end

    local containingItem = destination:getContainingItem()
    local ancestor = containingItem and containingItem:getContainer() or nil
    local addedWeight = item:getUnequippedWeight()
    local visited = {}

    while ancestor and not visited[ancestor] do
        visited[ancestor] = true

        -- Moving an item within the same ancestor does not increase that
        -- ancestor's total weight, so only check genuinely incoming weight.
        if not isWithinContainer(source, ancestor) then
            local used = ancestor:getCapacityWeight()
            local capacity = ancestor:getEffectiveCapacity(character)
            if used + addedWeight > capacity + 0.0001 then
                return false
            end
        end

        containingItem = ancestor:getContainingItem()
        ancestor = containingItem and containingItem:getContainer() or nil
    end

    return true
end

function Nested.OnButtonsAdded(inventoryPage)
    if not inventoryPage or not inventoryPage.backpacks then return end
    inventoryPage.bcNestedParents = {}

    local visited = {}
    local existingButtons = {}
    -- Only scan the buttons that existed before we started adding nested buttons.
    local originalButtonCount = #inventoryPage.backpacks

    for i = 1, originalButtonCount do
        local button = inventoryPage.backpacks[i]
        local inventory = button and button.inventory or nil
        clearParentIcon(button)
        if inventory then
            existingButtons[inventory] = true
        end
    end

    if not isEnabled(inventoryPage) then return end

    for i = 1, originalButtonCount do
        local button = inventoryPage.backpacks[i]
        local inventory = button and button.inventory or nil
        scanInventory(inventoryPage, inventory, 1, visited, existingButtons)
    end
end

local function addIgnoreTypeContextOption(inventoryPage, button)
    local inventory = button and button.inventory or nil
    local invType = inventory and inventory:getType() or nil
    if not invType or invType == "" or invType == "floor" then return end

    local context = getPlayerContextMenu(inventoryPage.player)
    if not context or (context.numOptions and context.numOptions <= 1) then
        context = ISContextMenu.get(inventoryPage.player, getMouseX(), getMouseY())
    end
    if not context then return end

    Nested.loadUserIgnoredInventoryTypes()
    local ignoredTypes = Nested._userIgnoredInventoryTypes
    local isIgnored = ignoredTypes[invType] == true

    local nestingMenu = context:getNew(context)
    local nestingRoot = context:addOption(
        getTextOrNull("ContextMenu_BetterContainers_Nesting") or "Nesting",
        nil,
        nil
    )
    context:addSubMenu(nestingRoot, nestingMenu)

    local label
    if isIgnored then
        label = getTextOrNull("ContextMenu_BetterContainers_AllowNestedContainerType")
            or "Allow Nested Container Type"
    else
        label = getTextOrNull("ContextMenu_BetterContainers_IgnoreNestedContainerType")
            or "Ignore Nested Container Type"
    end

    local option = nestingMenu:addOption(label, nil, function()
        Nested.setUserIgnoredInventoryType(invType, not isIgnored)
        inventoryPage:refreshBackpacks()
    end)
    option.toolTip = ISToolTip:new()
    option.toolTip:initialise()
    option.toolTip.description = invType

    local containedIgnoredTypes = {}
    local visited = {}

    local function collectContainedIgnoredTypes(container, depth)
        if not container or depth > getMaxDepth() or visited[container] then return end
        visited[container] = true

        local items = container:getItems()
        if not items then return end

        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item and item:IsInventoryContainer() then
                local childInventory = item:getInventory()
                if childInventory and childInventory:getContainingItem() == item then
                    local childType = childInventory:getType()
                    if childType and ignoredTypes[childType] then
                        containedIgnoredTypes[childType] = item:getName() or childType
                    end
                    collectContainedIgnoredTypes(childInventory, depth + 1)
                end
            end
        end
    end

    collectContainedIgnoredTypes(inventory, 1)

    local ignoredMenu = nestingMenu:getNew(nestingMenu)
    local ignoredRoot = nestingMenu:addOption(
        getTextOrNull("ContextMenu_BetterContainers_IgnoredNestedContainerTypes")
            or "Ignored Container Types",
        nil,
        nil
    )
    nestingMenu:addSubMenu(ignoredRoot, ignoredMenu)

    local sortedTypes = {}
    for childType in pairs(containedIgnoredTypes) do
        table.insert(sortedTypes, childType)
    end
    table.sort(sortedTypes, function(a, b)
        local aName = tostring(containedIgnoredTypes[a] or a)
        local bName = tostring(containedIgnoredTypes[b] or b)
        if aName == bName then return a < b end
        return aName < bName
    end)

    if #sortedTypes == 0 then
        local emptyOption = ignoredMenu:addOption(
            getTextOrNull("ContextMenu_BetterContainers_NoIgnoredNestedContainerTypes")
                or "None",
            nil,
            nil
        )
        emptyOption.notAvailable = true
        return
    end

    for _, childType in ipairs(sortedTypes) do
        local targetType = childType
        local childName = containedIgnoredTypes[targetType]
        local allowOption = ignoredMenu:addOption(childName, nil, function()
            Nested.setUserIgnoredInventoryType(targetType, false)
            inventoryPage:refreshBackpacks()
        end)
        allowOption.toolTip = ISToolTip:new()
        allowOption.toolTip:initialise()
        allowOption.toolTip.description = (getTextOrNull("ContextMenu_BetterContainers_AllowNestedContainerType")
            or "Allow Nested Container Type") .. ": " .. targetType
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
    Events.OnGameBoot.Add(Nested.loadUserIgnoredInventoryTypes)
    Events.OnSave.Add(Nested.saveUserIgnoredInventoryTypes)

    require "TimedActions/ISInventoryTransferAction"
    local oldTransferIsValid = ISInventoryTransferAction.isValid
    function ISInventoryTransferAction:isValid(...)
        -- Bicycle uses a zero-time floor-to-inventory transfer as part of its
        -- mount sequence. Leave mod-owned mount transfers entirely to the
        -- validator that created them, regardless of mod load order.
        if self.bicycleMount then
            return oldTransferIsValid(self, ...)
        end

        if not nestedAncestorsHaveRoom(
            self.character,
            self.item,
            self.srcContainer,
            self.destContainer
        ) then
            return false
        end

        return oldTransferIsValid(self, ...)
    end

    require "ISUI/ISInventoryPage"
    local oldOnBackpackRightMouseDown = ISInventoryPage.onBackpackRightMouseDown
    function ISInventoryPage:onBackpackRightMouseDown(x, y)
        oldOnBackpackRightMouseDown(self, x, y)

        local inventoryPage = self.parent and self.parent.parent or nil
        if inventoryPage and self.inventory then
            addIgnoreTypeContextOption(inventoryPage, self)
        end
    end
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
