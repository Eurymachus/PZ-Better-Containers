local Helpers = require("BetterContainers/Helpers")
local Permissions = require("BetterContainers/Permissions")
local ModOptionsTooltipPatch = require("BetterContainers/_Patches/ModOptionsTooltipPatch")

ModOptionsTooltipPatch.install()

local Options = {
    -- REORDER
    allowReorderingContainers = true,
    enableUtilityPanelFooter = false,

    -- CATEGORIZE
    showAdvancedDisplayCategories = true,
    categoryBlacklist = "Lore",

    -- CUSTOMIZE
    enableCustomizer = true,
    enableCustomizerSubMenu = true,

    -- NESTED
    enableNestedContainers_Player = false,
    enableNestedContainers_Loot = false,
    nestedContainersDepth = 2,
    nestedContainersPlayerFilter = 1,
    showNestedContainerParentIcon = true,

    -- PROXIMITY
    enableProximity = true,
    proximityIncludeNestedContainers = false,
    enableProximityKeybind = Keyboard.KEY_NUMPAD1,
    forceProximityLockKeybind = Keyboard.KEY_NUMPAD0,
    enableProximityHighlight = true,
    enableCorpseOnly = false,
    enableDualMode = false,
    showCorpsesOnlyWhenNearby = true,
    hideIndividualCorpseContainers = false,
    corpseOnlyModeKeybind = Keyboard.KEY_NUMPAD3,
    enableAutoLock = false,
    autoLockDelaySeconds = 10,
    enableAutoLockKeybind = "TOGGLE_AUTOLOCK",

    -- UPDRAGES
    enableSearchBar = true,
    inventoryLeft_Player = false,
    inventoryLeft_Loot = true,
    enableLockInventory = true,
    showFavouritesOnPlayerInventories = false,
    showEquippedAttachedSection = false,
    preserveInventoryWindowsAfterPause = true,
    showFoodFreshnessBar = true,
    showWeightColumn = false,
    showFoodFreshnessPercentage = true,
}

local config = {
    -- REORDER
    allowReorderingContainers = nil,
    enableUtilityPanelFooter = nil,

    -- CATEGORIZE
    showAdvancedDisplayCategories = nil,
    categoryBlacklist = nil,

    -- CUSTOMIZE
    enableCustomizer = nil,
    enableCustomizerSubMenu = nil,

    -- NESTED
    enableNestedContainers_Player = nil,
    enableNestedContainers_Loot = nil,
    nestedContainersDepth = nil,
    nestedContainersPlayerFilter = nil,
    showNestedContainerParentIcon = nil,

    -- PROXIMITY
    enableProximity = nil,
    proximityIncludeNestedContainers = nil,
    enableProximityKeybind = nil,
    forceProximityLockKeybind = nil,
    enableProximityHighlight = nil,
    enableCorpseOnly = nil,
    enableDualMode = nil,
    showCorpsesOnlyWhenNearby = nil,
    hideIndividualCorpseContainers = nil,
    corpseOnlyModeKeybind = nil,
    enableAutoLock = nil,
    autoLockDelaySeconds = nil,
    enableAutoLockKeybind = nil,

    -- UPDRAGES
    enableSearchBar = nil,
    inventoryLeft_Player = nil,
    inventoryLeft_Loot = nil,
    enableLockInventory = nil,
    showFavouritesOnPlayerInventories = nil,
    showEquippedAttachedSection = nil,
    preserveInventoryWindowsAfterPause = nil,
    showFoodFreshnessBar = nil,
    showWeightColumn = nil,
    showFoodFreshnessPercentage = nil,
}

function Options.getEffectivePermissions()
    return Permissions.compute(Options)
end

local function updateOptions()
    -- Apply server-policy UI gating (visible but disabled)
    local function _setOptionEnabled(opt, enabled)
        if not opt then return end

        -- This is the vanilla gate MainOptions uses when building the UI.
        opt.isEnabled = enabled

        -- If UI already exists, apply immediately.
        local el = opt.element
        if type(el) == "table" and el.btn then
            -- keybind path: option.element becomes keyTextElement, real control is .btn
            el = el.btn
        end

        if el and el.disableOption then
            -- ISTickBox (yes/no) style
            el:disableOption("", not enabled)
            return
        end

        if el and el.setEnable then
            -- ISButton etc
            el:setEnable(enabled)
            return
        end

        if el and el.disabled ~= nil then
            -- sliders etc
            el.disabled = not enabled
            return
        end
    end

    local eff = Options.getEffectivePermissions() or {}
    local ui = eff.ui or {}

    local function _applyUi(key, opt)
        local st = ui[key]
        if not (st and opt) then return end
        if st.enabled == false then
            _setOptionEnabled(opt, false)
            opt._bcTooltipSuffix = st.reason or nil
        else
            _setOptionEnabled(opt, true)
            opt._bcTooltipSuffix = nil
        end

        -- If ModOptions UI is open, apply immediately; otherwise it will apply on build via our patch.
        ModOptionsTooltipPatch.apply(opt)
    end

    _applyUi("enableProximity", config.enableProximity)
    _applyUi("enableProximity", config.enableProximityKeybind)
    _applyUi("enableCorpseOnly", config.enableCorpseOnly)
    _applyUi("enableCorpseOnly", config.enableDualMode)
    _applyUi("enableCorpseOnly", config.showCorpsesOnlyWhenNearby)
    _applyUi("enableCorpseOnly", config.hideIndividualCorpseContainers)
    _applyUi("enableCorpseOnly", config.corpseOnlyModeKeybind)
    _applyUi("toggleLock", config.forceProximityLockKeybind)
    _applyUi("enableProximity", config.enableProximityHighlight)
    _applyUi("enableProximity", config.proximityIncludeNestedContainers)
    _applyUi("enableAutoLock", config.enableAutoLock)
    _applyUi("autoLockDelaySeconds", config.autoLockDelaySeconds)
end

local function applyOptions()
    local opts = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions:getOptions(Helpers.MODULE_ID)
    if not opts then
        Helpers.dlog("ModOptions not ready; keeping defaults.")
        return
    end

    --Options.allowReorderingContainers  = opts:getOption("allowReorderingContainers"):getValue()
    --Options.enableUtilityPanelFooter  = opts:getOption("enableUtilityPanelFooter"):getValue()

    -- CATEGORIZE
    Options.showAdvancedDisplayCategories  = opts:getOption("showAdvancedDisplayCategories"):getValue()
    Options.categoryBlacklist = opts:getOption("categoryBlacklist"):getValue()

    -- CUSTOMIZE
    Options.enableCustomizer  = opts:getOption("enableCustomizer"):getValue()
    Options.enableCustomizerSubMenu  = opts:getOption("enableCustomizerSubMenu"):getValue()

    -- NESTED
    Options.enableNestedContainers_Player = opts:getOption("enableNestedContainers_Player"):getValue()
    Options.enableNestedContainers_Loot = opts:getOption("enableNestedContainers_Loot"):getValue()
    Options.nestedContainersDepth = opts:getOption("nestedContainersDepth"):getValue()
    Options.nestedContainersPlayerFilter = opts:getOption("nestedContainersPlayerFilter"):getValue()
    Options.showNestedContainerParentIcon = opts:getOption("showNestedContainerParentIcon"):getValue()

    -- PROXIMITY
    Options.enableProximity = opts:getOption("enableProximity"):getValue()
    Options.proximityIncludeNestedContainers = opts:getOption("proximityIncludeNestedContainers"):getValue()
    Options.enableProximityKeybind = opts:getOption("enableProximityKeybind"):getValue()
    Options.forceProximityLockKeybind = opts:getOption("forceProximityLockKeybind"):getValue()
    Options.enableProximityHighlight = opts:getOption("enableProximityHighlight"):getValue()
    Options.enableCorpseOnly = opts:getOption("enableCorpseOnly"):getValue()
    Options.enableDualMode = opts:getOption("enableDualMode"):getValue()
    Options.showCorpsesOnlyWhenNearby = opts:getOption("showCorpsesOnlyWhenNearby"):getValue()
    Options.hideIndividualCorpseContainers = opts:getOption("hideIndividualCorpseContainers"):getValue()
    Options.corpseOnlyModeKeybind = opts:getOption("corpseOnlyModeKeybind"):getValue()
    Options.enableAutoLock = opts:getOption("enableAutoLock"):getValue()
    Options.autoLockDelaySeconds = opts:getOption("autoLockDelaySeconds"):getValue()

    -- UPGRADES
    Options.enableSearchBar = opts:getOption("enableSearchBar"):getValue()
    Options.inventoryLeft_Player = opts:getOption("inventoryLeft_Player"):getValue()
    Options.inventoryLeft_Loot = opts:getOption("inventoryLeft_Loot"):getValue()
    Options.enableLockInventory = opts:getOption("enableLockInventory"):getValue()
    Options.showFavouritesOnPlayerInventories  = opts:getOption("showFavouritesOnPlayerInventories"):getValue()
    Options.showEquippedAttachedSection = opts:getOption("showEquippedAttachedSection"):getValue()
    Options.preserveInventoryWindowsAfterPause = opts:getOption("preserveInventoryWindowsAfterPause"):getValue()
    Options.showFoodFreshnessBar = opts:getOption("showFoodFreshnessBar"):getValue()
    Options.showWeightColumn = opts:getOption("showWeightColumn"):getValue()
    Options.showFoodFreshnessPercentage = opts:getOption("showFoodFreshnessPercentage"):getValue()

    triggerEvent(Helpers.OPTIONS_APPLIED)
end

local function initConfig()
    -- Create the panel (same cadence as BGI)
    local title = getTextOrNull("UI_BetterContainers_Options_Title") or "Better Containers"
    local panel = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions:create(Helpers.MODULE_ID, title)
    if not panel then
        Helpers.log("PZAPI.ModOptions missing; no options UI (defaults apply).")
        return
    end

    -- REORDER
    local allowReorderTitle  = getTextOrNull("UI_BetterContainers_Options_allowReorderingContainers")
                                    or "Allow Reordering Container Buttons"
    local allowReorderTooltip  = getTextOrNull("UI_BetterContainers_Options_allowReorderingContainers_Tooltip")
                                    or "When enabled will allow the reordering of inventory container buttons, including player buttons"
    --[[
    config.allowReorderingContainers = panel:addTickBox(
        "allowReorderingContainers",
        allowReorderTitle,
        Options.allowReorderingContainers,
        allowReorderTooltip
    )
    local enableUtilityPanelFooterTitle  = getTextOrNull("UI_BetterContainers_Options_enableUtilityPanelFooter")
                                    or "Lock and Sort Footer"
    local enableUtilityPanelFooterTooltip  = getTextOrNull("UI_BetterContainers_Options_enableUtilityPanelFooter_Tooltip")
                                    or "When enabled moves the Lock and Sort buttons to the Foot of the Container Buttons"
    config.enableUtilityPanelFooter = panel:addTickBox(
        "enableUtilityPanelFooter",
        enableUtilityPanelFooterTitle,
        Options.enableUtilityPanelFooter,
        enableUtilityPanelFooterTooltip
    )
    ]]

    -- CATEGORIZE
    panel:addDescription(getTextOrNull("UI_BetterContainers_Options_CategoriesTitle") or "Advanced Display Category Options")

    local showCatTitle  = getTextOrNull("UI_BetterContainers_Options_showAdvancedDisplayCategories")
                                    or "Show Advanced Display Categories"
    local showCatTooltip  = getTextOrNull("UI_BetterContainers_Options_showAdvancedDisplayCategories_Tooltip")
                                    or "When enabled will improve the display categories of items in the inventory panels (Small lag when enabling)"

    config.showAdvancedDisplayCategories = panel:addTickBox(
        "showAdvancedDisplayCategories",
        showCatTitle,
        Options.showAdvancedDisplayCategories,
        showCatTooltip
    )

    config.categoryBlacklist = panel:addTextEntry(
        "categoryBlacklist",
        getTextOrNull("UI_BetterContainers_Options_categoryBlacklist")
            or "Category Blacklist",
        Options.categoryBlacklist,
        getTextOrNull("UI_BetterContainers_Options_categoryBlacklist_Tooltip")
            or "Better Containers will not recategorize items already using these script DisplayCategory names. Separate categories with commas. Enter none to disable."
    )

    panel:addSeparator()

    -- CUSTOMIZE
    panel:addDescription(getTextOrNull("UI_BetterContainers_Options_CustomizerTitle") or "Container Customizer Options")

    local enableCustomizerTitle  = getTextOrNull("UI_BetterContainers_Options_enableCustomizer")
                                    or "Enable Container Button Customizer"
    local enableCustomizerTooltip  = getTextOrNull("UI_BetterContainers_Options_enableCustomizer_Tooltip")
                                    or "When enabled will allow the customizing of inventory container buttons"

    config.enableCustomizer = panel:addTickBox(
        "enableCustomizer",
        enableCustomizerTitle,
        Options.enableCustomizer,
        enableCustomizerTooltip
    )

    local enableCustomizerSubMenuTitle  = getTextOrNull("UI_BetterContainers_Options_enableCustomizerSubMenu")
                                    or "Enable Customizer Sub-Menu"
    local enableCustomizerSubMenuTooltip  = getTextOrNull("UI_BetterContainers_Options_enableCustomizerSubMenu_Tooltip")
                                    or "When enabled will move the customizer options into a sub-menu"

    config.enableCustomizerSubMenu = panel:addTickBox(
        "enableCustomizerSubMenu",
        enableCustomizerSubMenuTitle,
        Options.enableCustomizerSubMenu,
        enableCustomizerSubMenuTooltip
    )

    panel:addSeparator()

    -- NESTED
    panel:addDescription(
        getTextOrNull("UI_BetterContainers_Options_NestedTitle")
            or "Nested Containers"
    )

    config.enableNestedContainers_Player = panel:addTickBox(
        "enableNestedContainers_Player",
        getTextOrNull("UI_BetterContainers_Options_enableNestedContainers_Player")
            or "Enable Player Nested Containers",
        Options.enableNestedContainers_Player,
        getTextOrNull("UI_BetterContainers_Options_enableNestedContainers_Player_tooltip")
            or "When enabled, containers inside the player inventory are shown as additional container buttons."
    )

    config.enableNestedContainers_Loot = panel:addTickBox(
        "enableNestedContainers_Loot",
        getTextOrNull("UI_BetterContainers_Options_enableNestedContainers_Loot")
            or "Enable Loot Nested Containers",
        Options.enableNestedContainers_Loot,
        getTextOrNull("UI_BetterContainers_Options_enableNestedContainers_Loot_tooltip")
            or "When enabled, containers inside loot inventories are shown as additional container buttons."
    )

    config.nestedContainersDepth = panel:addSlider(
        "nestedContainersDepth",
        getTextOrNull("UI_BetterContainers_Options_nestedContainersDepth")
            or "Nested Container Depth",
        1,
        10,
        1,
        Options.nestedContainersDepth
    )

    config.showNestedContainerParentIcon = panel:addTickBox(
        "showNestedContainerParentIcon",
        getTextOrNull("UI_BetterContainers_Options_showNestedContainerParentIcon")
            or "Show Parent Container Icon",
        Options.showNestedContainerParentIcon,
        getTextOrNull("UI_BetterContainers_Options_showNestedContainerParentIcon_tooltip")
            or "When enabled, nested container buttons show the icon of the container they are inside."
    )

    config.nestedContainersPlayerFilter = panel:addComboBox(
        "nestedContainersPlayerFilter",
        getTextOrNull("UI_BetterContainers_Options_nestedContainersPlayerFilter")
            or "Player Inventory Filter"
    )
    config.nestedContainersPlayerFilter:addItem(
        getTextOrNull("UI_BetterContainers_Options_nestedContainersPlayerFilter_Everything")
            or "Everything",
        Options.nestedContainersPlayerFilter == 1
    )
    config.nestedContainersPlayerFilter:addItem(
        getTextOrNull("UI_BetterContainers_Options_nestedContainersPlayerFilter_OnlyPockets")
            or "Inventory Only",
        Options.nestedContainersPlayerFilter == 2
    )
    config.nestedContainersPlayerFilter:addItem(
        getTextOrNull("UI_BetterContainers_Options_nestedContainersPlayerFilter_OnlyEquipped")
            or "Equipped Containers Only",
        Options.nestedContainersPlayerFilter == 3
    )

    panel:addSeparator()

    -- PROXIMITY
    panel:addDescription(
        getTextOrNull("UI_BetterContainers_Options_ProximityTitle")
        or "Proximity Inventory"
    )

    config.enableProximity = panel:addTickBox(
        "enableProximity",
        getTextOrNull("UI_BetterContainers_Options_enableProximity")
            or "Enable Proximity Inventory",
        Options.enableProximity,
        getTextOrNull("UI_BetterContainers_Options_enableProximity_tooltip")
            or "Enables/Disables the Proximity Inventory feature"
    )

    config.proximityIncludeNestedContainers = panel:addTickBox(
        "proximityIncludeNestedContainers",
        getTextOrNull("UI_BetterContainers_Options_proximityIncludeNestedContainers")
            or "Include Nested Containers",
        Options.proximityIncludeNestedContainers,
        getTextOrNull("UI_BetterContainers_Options_proximityIncludeNestedContainers_tooltip")
            or "Active when Loot Nested Containers is enabled"
    )

    config.enableProximityKeybind = panel:addKeyBind(
        "enableProximityKeybind",
        getTextOrNull("UI_BetterContainers_Options_enableProximityKeybind")
            or "Proximity Inventory Keybind",
        Options.enableProximityKeybind,
        getTextOrNull("UI_BetterContainers_Options_enableProximityKeybind_tooltip")
            or "Keybind used to toggle Proximity Inventory feature"
    )

    config.forceProximityLockKeybind = panel:addKeyBind(
        "forceProximityLockKeybind",
        getTextOrNull("UI_BetterContainers_Options_forceProximityLockKeybind")
            or "Lock Proximity Inventory",
        Options.forceProximityLockKeybind,
        getTextOrNull("UI_BetterContainers_Options_forceProximityLockKeybind_tooltip")
            or "Keybind used to force lock Proximity Inventory"
    )

    config.enableProximityHighlight = panel:addTickBox(
        "enableProximityHighlight",
        getTextOrNull("UI_BetterContainers_Options_enableProximityHighlight")
            or "Highlight for Bodies and Containers",
        Options.enableProximityHighlight,
        getTextOrNull("UI_BetterContainers_Options_enableProximityHighlight_tooltip")
            or "Enables/Disables Highlighting containers and corpses"
    )

    config.enableCorpseOnly = panel:addTickBox(
        "enableCorpseOnly",
        getTextOrNull("UI_BetterContainers_Options_enableCorpseOnly")
            or "Corpses Only Mode",
        Options.enableCorpseOnly,
        getTextOrNull("UI_BetterContainers_Options_enableCorpseOnly_tooltip")
            or "Enables/Disables Proximity Inventory in Corpse Only mode"
    )

    config.enableDualMode = panel:addTickBox(
        "enableDualMode",
        getTextOrNull("UI_BetterContainers_Options_enableDualMode")
            or "Dual Mode",
        Options.enableDualMode,
        getTextOrNull("UI_BetterContainers_Options_enableDualMode_tooltip")
            or "Shows both Proximity and Corpses Only. Auto-Lock prefers corpses while any are nearby. Corpse Only mode takes priority if both modes are enabled."
    )

    config.showCorpsesOnlyWhenNearby = panel:addTickBox(
        "showCorpsesOnlyWhenNearby",
        getTextOrNull("UI_BetterContainers_Options_showCorpsesOnlyWhenNearby")
            or "Show Corpses Only When Nearby",
        Options.showCorpsesOnlyWhenNearby,
        getTextOrNull("UI_BetterContainers_Options_showCorpsesOnlyWhenNearby_tooltip")
            or "In Dual Mode, hides the Corpses Only button when no corpses are nearby. The Proximity button remains available."
    )

    config.hideIndividualCorpseContainers = panel:addTickBox(
        "hideIndividualCorpseContainers",
        getTextOrNull("UI_BetterContainers_Options_hideIndividualCorpseContainers")
            or "Hide Individual Corpse Containers",
        Options.hideIndividualCorpseContainers,
        getTextOrNull("UI_BetterContainers_Options_hideIndividualCorpseContainers_tooltip")
            or "When Corpses Only or Dual Mode is active, hides individual corpse buttons and uses the Corpses Only inventory instead."
    )

    config.corpseOnlyModeKeybind = panel:addKeyBind(
        "corpseOnlyModeKeybind",
        getTextOrNull("UI_BetterContainers_Options_corpseOnlyModeKeybind")
            or "Corpses Only Keybind",
        Options.corpseOnlyModeKeybind,
        getTextOrNull("UI_BetterContainers_Options_corpseOnlyModeKeybind_tooltip")
            or "Keybind used to force Corpse Only mode"
    )

    panel:addSeparator()

    panel:addDescription(
        getTextOrNull("UI_BetterContainers_Options_enableAutoLockHeader")
            or "CAUTION: Auto-Locking Functionality - Overrides Default Behaviour"
    )

    config.enableAutoLock = panel:addTickBox(
        "enableAutoLock",
        getTextOrNull("UI_BetterContainers_Options_enableAutoLock")
            or "Enable Auto-Lock",
        Options.enableAutoLock,
        getTextOrNull("UI_BetterContainers_Options_enableAutoLock_tooltip")
            or "When enabled, locking is automatic. Players can browse other inventories until moving away or the configured delay expires."
    )

    config.autoLockDelaySeconds = panel:addSlider(
        "autoLockDelaySeconds",
        getTextOrNull("UI_BetterContainers_Options_autoLockDelaySeconds")
            or "Auto-Lock Delay (seconds)",
        5,
        60,
        5,
        Options.autoLockDelaySeconds,
        getTextOrNull("UI_BetterContainers_Options_autoLockDelaySeconds_tooltip")
            or "How long a browsed inventory remains selected during active gameplay before snapping back to the Proximity/Corpse inventory. Paused time is not counted."
    )

    panel:addSeparator()

    panel:addDescription(
        getTextOrNull("UI_BetterContainers_Options_Upgrades_title")
            or "Additional UI Features"
    )

    config.enableSearchBar = panel:addTickBox(
        "enableSearchBar",
        getTextOrNull("UI_BetterContainers_Options_enableSearchBar")
            or "Enable Search Bar",
        Options.enableSearchBar,
        getTextOrNull("UI_BetterContainers_Options_enableSearchBar_tooltip")
            or "Disable the Search bar feature of the Inventory UI (useful if installing other UI overhauls)"
    )

    config.inventoryLeft_Player = panel:addTickBox(
        "inventoryLeft_Player",
        getTextOrNull("UI_BetterContainers_Options_inventoryLeft_Player")
            or "Player Inventory Left",
        Options.inventoryLeft_Player,
        getTextOrNull("UI_BetterContainers_Options_inventoryLeft_Player_tooltip")
            or "Move Player Inventory Buttons to the Left hand side"
    )

    config.inventoryLeft_Loot = panel:addTickBox(
        "inventoryLeft_Loot",
        getTextOrNull("UI_BetterContainers_Options_inventoryLeft_Loot")
            or "Loot Inventory Left",
        Options.inventoryLeft_Loot,
        getTextOrNull("UI_BetterContainers_Options_inventoryLeft_Loot_tooltip")
            or "Move Loot Inventory Buttons to the Left hand side"
    )

    config.enableLockInventory = panel:addTickBox(
        "enableLockInventory",
        getTextOrNull("UI_BetterContainers_Options_enableLockInventory")
            or "Allow Locking Inventory Window",
        Options.enableLockInventory,
        getTextOrNull("UI_BetterContainers_Options_enableLockInventory_tooltip")
            or "Lock button also prevents Moving/Resizing the inventory window"
    )

    config.showFavouritesOnPlayerInventories = panel:addTickBox(
        "showFavouritesOnPlayerInventories",
        getTextOrNull("UI_BetterContainers_Options_showFavouritesOnPlayerInventories")
            or "Show Pinned Item Types on Player Inventory",
        Options.showFavouritesOnPlayerInventories,
        getTextOrNull("UI_BetterContainers_Options_showFavouritesOnPlayerInventories_Tooltip")
            or "When enabled, pinned item types are also shown on the player inventory."
    )

    config.showEquippedAttachedSection = panel:addTickBox(
        "showEquippedAttachedSection",
        getTextOrNull("UI_BetterContainers_Options_showEquippedAttachedSection")
            or "Show Equipped / Attached Section",
        Options.showEquippedAttachedSection,
        getTextOrNull("UI_BetterContainers_Options_showEquippedAttachedSection_Tooltip")
            or "When enabled, worn, held, attached hotbar items, and keyrings are grouped into one collapsible section in the player inventory."
    )

    config.preserveInventoryWindowsAfterPause = panel:addTickBox(
        "preserveInventoryWindowsAfterPause",
        getTextOrNull("UI_BetterContainers_Options_preserveInventoryWindowsAfterPause")
            or "Preserve Inventory Windows After Pause",
        Options.preserveInventoryWindowsAfterPause,
        getTextOrNull("UI_BetterContainers_Options_preserveInventoryWindowsAfterPause_Tooltip")
            or "When enabled, inventory windows that were open before entering the pause menu are restored after returning to the game."
    )

    config.showWeightColumn = panel:addTickBox(
        "showWeightColumn",
        getTextOrNull("UI_BetterContainers_Options_showWeightColumn") or "Show Weight Column",
        Options.showWeightColumn,
        getTextOrNull("UI_BetterContainers_Options_showWeightColumn_Tooltip")
            or "Show stack and individual weights in inventory lists. Click the weight header to change sort direction."
    )

    config.showFoodFreshnessBar = panel:addTickBox(
        "showFoodFreshnessBar",
        getTextOrNull("UI_BetterContainers_Options_showFoodFreshnessBar")
            or "Show Freshness Bar for Spoilable Food",
        Options.showFoodFreshnessBar,
        -- getTextOrNull("UI_BetterContainers_Options_showFoodFreshnessBar_Tooltip")
        --     or "Shows remaining freshness from 100% fresh to 0% rotten, with a marker at the stale threshold."
        "UI_BetterContainers_Options_showFoodFreshnessBar_Tooltip"
    )

    config.showFoodFreshnessPercentage = panel:addTickBox(
        "showFoodFreshnessPercentage",
        getTextOrNull("UI_BetterContainers_Options_showFoodFreshnessPercentage")
            or "Show Freshness Percentage for Spoilable Food",
        Options.showFoodFreshnessPercentage,
        getTextOrNull("UI_BetterContainers_Options_showFoodFreshnessPercentage_Tooltip")
            or "Shows the remaining freshness percentage on hover and permanently for individual items in expanded stacks."
    )

    -- Apply handler (BGI pattern)
    panel.apply = function()
        applyOptions()
    end
end

-- Initialize immediately (BGI style), and re-apply on menu enter
initConfig()
Events.OnMainMenuEnter.Add(function() applyOptions() end)

local function refreshBackpacks()
    ISInventoryPage.dirtyUI()
end

Events[Helpers.OPTIONS_APPLIED].Add(refreshBackpacks)
Events.OnGameStart.Add(
    updateOptions
)

function Options.OnToggle()
    if config.enableProximity and config.enableProximity.setValue then
        config.enableProximity:setValue(not Options.enableProximity)
        applyOptions()
    end
end

function Options.OnToggleMode()
    if config.enableCorpseOnly and config.enableCorpseOnly.setValue then
        config.enableCorpseOnly:setValue(not Options.enableCorpseOnly)
        applyOptions()
    end
end

function Options.OnToggleHideIndividualCorpseContainers()
    if config.hideIndividualCorpseContainers and config.hideIndividualCorpseContainers.setValue then
        config.hideIndividualCorpseContainers:setValue(not Options.hideIndividualCorpseContainers)
        applyOptions()
    end
end

function Options.OnToggleAutoLock()
    if config.enableAutoLock and config.enableAutoLock.setValue then
        config.enableAutoLock:setValue(not Options.enableAutoLock)
        applyOptions()
    end
end

return Options
