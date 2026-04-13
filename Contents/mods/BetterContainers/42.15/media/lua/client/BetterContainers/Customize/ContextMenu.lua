local EC = require("BetterContainers/Helpers")
local Options = require("BetterContainers/_Options")
local Presets = require("BetterContainers/Customize/Presets")
local SavedPresets = require("BetterContainers/Customize/SavedPresets")
local Customizer = require("BetterContainers/Customize/Customizer")
local CustomizeUI = require("BetterContainers/Customize/ui/CustomizeUI")

local CustomizeContextMenu = {}

-- ---------------------------------------------------------
-- Local helpers (kept local so we don't leak API surface)
-- ---------------------------------------------------------

local function removeVanillaRename(context)
    if context and context.removeOptionByName then
        context:removeOptionByName(getText("ContextMenu_RenameBag"))
        context:removeOptionByName("Rename")
    end
end

local function addCustomizerOption(context, page, button, parent)
    if not (context and context.addOption) then return end

    local opt = context:addOption(getTextOrNull("ContextMenu_BC_Customizer") or "Customizer...",
        button,
        CustomizeUI.open,
        page,
        parent
    )

    opt.iconTexture = Customizer.Icons.Loaded.Customize
end

local function _t(key, fallback)
    if key and getText then
        local ok, txt = pcall(getText, key)
        if ok and txt and txt ~= key then
            return txt
        end
    end
    return fallback or key or ""
end

local function _applyOptionIcon(opt, fullType)
    if not opt then return end
    local tex = EC.getIconTexture(fullType)
    if tex then
        opt.iconTexture = tex
    end
end

local function _applyPresetPayload(button, page, parent, payload)
    Customizer.applyPayload(button, page, parent, payload)
    page:refreshBackpacks()
end

local function _addPresetOption(menu, page, button, parent, preset)
    local label = _t(preset.nameKey, preset.payload and preset.payload.name or preset.id)
    local opt = menu:addOption(label, button, _applyPresetPayload, page, parent, preset.payload)
    if preset and preset.payload then
        _applyOptionIcon(opt, preset.payload.icon)
    end
end

-- ---------------------------------------------------------
-- Meta access (tolerate meta/Meta casing)
-- ---------------------------------------------------------

local function _getMeta()
    return Presets and (Presets.meta or Presets.Meta) or nil
end

local function _getCatMeta(catId)
    local m = _getMeta()
    local cats = m and (m.Categories or m.categories) or nil
    return cats and cats[catId] or nil
end

local function _getSubMeta(subId)
    local m = _getMeta()
    local subs = m and (m.Subs or m.subs) or nil
    return subs and subs[subId] or nil
end

local function _orderOfCat(catId)
    local meta = _getCatMeta(catId)
    return meta and meta.order or 999
end

local function _orderOfSub(subId)
    local meta = _getSubMeta(subId)
    return meta and meta.order or 999
end

local function _labelOfCat(catId)
    local meta = _getCatMeta(catId)
    return _t(meta and meta.nameKey or nil, catId)
end

local function _labelOfSub(subId)
    local meta = _getSubMeta(subId)
    return _t(meta and meta.nameKey or nil, subId)
end

local function _iconOfCat(catId, fallbackFullType)
    local meta = _getCatMeta(catId)
    return (meta and meta.icon) or fallbackFullType
end

local function _iconOfSub(subId, fallbackFullType)
    local meta = _getSubMeta(subId)
    return (meta and meta.icon) or fallbackFullType
end

local function _presetSortName(p)
    if not p then return "" end
    if p.payload and p.payload.name then return tostring(p.payload.name) end
    if p.id then return tostring(p.id) end
    return ""
end

local function addDefaultPresets(menu, page, button, parent)
    if not (menu and menu.getNew and menu.addOption and menu.addSubMenu) then
        return
    end

    local list = Presets and (Presets.listArray or Presets._listArray) or nil
    if type(list) ~= "table" then
        menu:addOption("No presets", nil, nil)
        return
    end

    local root = {}
    local cats = {}
    local catIds = {}

    for _, p in ipairs(list) do
        if p and p.payload then
            local catId = p.cat
            local subId = p.sub

            if not catId or catId == "" then
                root[#root + 1] = p
            else
                local catNode = cats[catId]
                if not catNode then
                    catNode = { catOnly = {}, subs = {}, subIds = {}, firstIcon = nil }
                    cats[catId] = catNode
                    catIds[#catIds + 1] = catId
                end

                if not catNode.firstIcon then
                    catNode.firstIcon = p.payload and p.payload.icon or nil
                end

                if not subId or subId == "" then
                    catNode.catOnly[#catNode.catOnly + 1] = p
                else
                    local subNode = catNode.subs[subId]
                    if not subNode then
                        subNode = { presets = {}, firstIcon = nil }
                        catNode.subs[subId] = subNode
                        catNode.subIds[#catNode.subIds + 1] = subId
                    end

                    if not subNode.firstIcon then
                        subNode.firstIcon = p.payload and p.payload.icon or nil
                    end

                    subNode.presets[#subNode.presets + 1] = p
                end
            end
        end
    end

    table.sort(catIds, function(a, b)
        local oa, ob = _orderOfCat(a), _orderOfCat(b)
        if oa ~= ob then return oa < ob end
        return tostring(a) < tostring(b)
    end)

    for _, catId in ipairs(catIds) do
        local catNode = cats[catId]
        local catLabel = _labelOfCat(catId)

        local catSub = menu:getNew(menu)
        local catOpt = menu:addOption(catLabel, nil, nil)
        _applyOptionIcon(catOpt, _iconOfCat(catId, catNode.firstIcon))
        menu:addSubMenu(catOpt, catSub)

        table.sort(catNode.subIds, function(a, b)
            local oa, ob = _orderOfSub(a), _orderOfSub(b)
            if oa ~= ob then return oa < ob end
            return tostring(a) < tostring(b)
        end)

        for _, subId in ipairs(catNode.subIds) do
            local subNode = catNode.subs[subId]
            local subLabel = _labelOfSub(subId)

            local subSub = catSub:getNew(catSub)
            local subOpt = catSub:addOption(subLabel, nil, nil)
            _applyOptionIcon(subOpt, _iconOfSub(subId, subNode.firstIcon))
            catSub:addSubMenu(subOpt, subSub)

            table.sort(subNode.presets, function(a, b)
                return _presetSortName(a) < _presetSortName(b)
            end)

            for _, p in ipairs(subNode.presets) do
                _addPresetOption(subSub, page, button, parent, p)
            end
        end

        table.sort(catNode.catOnly, function(a, b)
            return _presetSortName(a) < _presetSortName(b)
        end)

        for _, p in ipairs(catNode.catOnly) do
            _addPresetOption(catSub, page, button, parent, p)
        end
    end

    table.sort(root, function(a, b)
        return _presetSortName(a) < _presetSortName(b)
    end)

    for _, p in ipairs(root) do
        _addPresetOption(menu, page, button, parent, p)
    end
end

local function addSavedPresets(savedMenu, page, button, parent)
    if not savedMenu then return end

    local presets = SavedPresets.loadAll()
    if not presets or #presets == 0 then
        savedMenu:addOption(getTextOrNull("ContextMenu_BC_NoSavedPresets") or "No saved presets", nil, nil)
        return
    end

    -- Flat list: saved presets are "quick picks"
    for _, p in ipairs(presets) do
        local label = tostring(p.name or p.id or "Preset")

        local opt = savedMenu:addOption(label, button, _applyPresetPayload, page, parent, p.payload)
        _applyOptionIcon(opt, p.payload and p.payload.icon)
    end
end

local function addPresetOptions(context, page, button, parent)
    if not (context and context.getNew and context.addOption and context.addSubMenu) then
        return
    end

    -- Presets ▶ (shipped)
    local presetsSub = context:getNew(context)
    local presetsOpt = context:addOption(getTextOrNull("ContextMenu_BC_Presets") or "Presets", nil, nil)
    presetsOpt.iconTexture = Customizer.Icons.Loaded.Presets
    context:addSubMenu(presetsOpt, presetsSub)
    addDefaultPresets(presetsSub, page, button, parent)

    -- Saved Presets ▶ (player INI)
    local savedSub = context:getNew(context)
    local savedOpt = context:addOption(getTextOrNull("ContextMenu_BC_SavedPresets") or "Saved Presets", nil, nil)
    savedOpt.iconTexture = EC.Icons.Loaded.Save
    context:addSubMenu(savedOpt, savedSub)
    addSavedPresets(savedSub, page, button, parent)
end

local function addCopyPasteOptions(context, page, button, parent)
    if not (context and context.addOption) then return end

    if Customizer.hasData(button, page, parent) then
        context:addOption(getTextOrNull("ContextMenu_BC_Copy") or "Copy",
            button,
            function()
                Customizer.copy(button, page, parent)
            end
        )
    end

    if Customizer.hasClipboard and Customizer.hasClipboard() then
        context:addOption(getTextOrNull("ContextMenu_BC_Paste") or "Paste",
            button,
            function()
                Customizer.paste(button, page, parent)
            end
        )
    end
end

local function addResetOption(context, page, button, parent)
    if not (context and context.addOption) then return end
    if not (page and button and parent) then return end

    local label = getTextOrNull("ContextMenu_BC_Reset") or "Reset"

    local opt = context:addOption(label, button, function()
        Customizer.reset(button, page, parent)
    end)

    local data = Customizer.getEffectiveData(button, page, parent)
    if not data then
        opt.notAvailable = true
    end
end

CustomizeContextMenu.handleCustomiserOptions = function(page, button, parent)
    if not (page and button and parent) then return end

    local playerNumber = page.player or 0

    local context = getPlayerContextMenu(playerNumber)
    if not context or (context.numOptions and context.numOptions <= 1) then
        context = ISContextMenu.get(playerNumber, getMouseX(), getMouseY())
    end
    if not context then return end

    removeVanillaRename(context)

    local targetMenu = context

    if Options and Options.enableCustomizerSubMenu then
        local customizeSubMenu = context:getNew(context)

        local customizeRootOpt = context:addOption(
            getTextOrNull("ContextMenu_BC_Customize") or "Customize",
            nil,
            nil
        )
        
        customizeRootOpt.iconTexture = Customizer.Icons.Loaded.Customize

        context:addSubMenu(customizeRootOpt, customizeSubMenu)
        targetMenu = customizeSubMenu
    end

    -- Order:
    addCustomizerOption(targetMenu, page, button, parent)
    addPresetOptions(targetMenu, page, button, parent)
    addCopyPasteOptions(targetMenu, page, button, parent)
    addResetOption(targetMenu, page, button, parent)
end

return CustomizeContextMenu