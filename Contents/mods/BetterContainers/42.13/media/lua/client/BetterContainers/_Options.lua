local Helpers = require("BetterContainers/Helpers")
local Permissions = require("BetterContainers/Permissions")
local ModOptionsTooltipPatch = require("BetterContainers/_Patches/ModOptionsTooltipPatch")

ModOptionsTooltipPatch.install()

local Options = {
    -- REORDER
    allowReorderingContainers = true,

    -- CATEGORIZE
    showAdvancedDisplayCategories = true,
    showFavouritesOnPlayerInventories = false,

    -- CUSTOMIZE
    enableCustomizer = true,
    enableCustomizerSubMenu = true,

    -- PROXIMITY
    enableProximity = true,
    enableProximityKeybind = Keyboard.KEY_NUMPAD1,
    forceProximityLockKeybind = Keyboard.KEY_NUMPAD0,
    enableProximityHighlight = true,
    enableCorpseOnly = false,
    corpseOnlyModeKeybind = Keyboard.KEY_NUMPAD3,
    enableAutoLock = false,
}

local config = {
    allowReorderingContainers = nil,
    showAdvancedDisplayCategories = nil,
    showFavouritesOnPlayerInventories = nil,
    enableCustomizer = nil,
    enableCustomizerSubMenu = nil,
    enableProximity = nil,
    enableProximityKeybind = nil,
    forceProximityLockKeybind = nil,
    enableProximityHighlight = nil,
    enableCorpseOnly = nil,
    corpseOnlyModeKeybind = nil,
    enableAutoLock = nil,
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
    _applyUi("enableCorpseOnly", config.corpseOnlyModeKeybind)
    _applyUi("toggleLock", config.forceProximityLockKeybind)
    _applyUi("enableProximity", config.enableProximityHighlight)
    _applyUi("enableAutoLock", config.enableAutoLock)
end

local function applyOptions()
    local opts = PZAPI and PZAPI.ModOptions and PZAPI.ModOptions:getOptions(Helpers.MODULE_ID)
    if not opts then
        Helpers.dlog("ModOptions not ready; keeping defaults.")
        return
    end

    --Options.allowReorderingContainers  = opts:getOption("allowReorderingContainers"):getValue()

    -- CATEGORIZE
    Options.showAdvancedDisplayCategories  = opts:getOption("showAdvancedDisplayCategories"):getValue()
    Options.showFavouritesOnPlayerInventories  = opts:getOption("showFavouritesOnPlayerInventories"):getValue()

    -- CUSTOMIZE
    Options.enableCustomizer  = opts:getOption("enableCustomizer"):getValue()
    Options.enableCustomizerSubMenu  = opts:getOption("enableCustomizerSubMenu"):getValue()

    -- PROXIMITY
    Options.enableProximity = opts:getOption("enableProximity"):getValue()
    Options.enableProximityKeybind = opts:getOption("enableProximityKeybind"):getValue()
    Options.forceProximityLockKeybind = opts:getOption("forceProximityLockKeybind"):getValue()
    Options.enableProximityHighlight = opts:getOption("enableProximityHighlight"):getValue()
    Options.enableCorpseOnly = opts:getOption("enableCorpseOnly"):getValue()
    Options.corpseOnlyModeKeybind = opts:getOption("corpseOnlyModeKeybind"):getValue()
    Options.enableAutoLock = opts:getOption("enableAutoLock"):getValue()

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

    local showFavTitle  = getTextOrNull("UI_BetterContainers_Options_showFavouritesOnPlayerInventories")
                                    or "Show Favourited Category Items on Player Inventory"
    local showFavTooltip  = getTextOrNull("UI_BetterContainers_Options_showFavouritesOnPlayerInventories_Tooltip")
                                    or "When enabled will also show favourited category items on player inventory"

    config.showFavouritesOnPlayerInventories = panel:addTickBox(
        "showFavouritesOnPlayerInventories",
        showFavTitle,
        Options.showFavouritesOnPlayerInventories,
        showFavTooltip
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
            or "When enabled lock keybind is ignored and locking is automatic. Players can browse inventories and when moving away or after 10 ingame minutes the selected inventory snaps back to Proximity/Corpse inventory."
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

return Options
