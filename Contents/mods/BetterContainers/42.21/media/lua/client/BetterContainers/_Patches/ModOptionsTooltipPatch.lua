local Patch = {}

local function _getElement(option)
    local el = option and option.element
    if type(el) == "table" and el.btn then
        -- keybind: option.element becomes keyTextElement, real control is .btn
        return el.btn
    end
    return el
end

local function _setTooltipOnElement(el, text)
    if not (el and text) then return end

    -- ISButton etc
    if el.setTooltip then
        el:setTooltip(text)
        return
    end

    -- Many controls just expose .tooltip
    el.tooltip = text
end

-- Applies tooltip suffix if available. Safe to call anytime.
function Patch.apply(option)
    if not option then return end
    if not option._bcTooltipSuffix or option._bcTooltipSuffix == "" then return end

    local el = _getElement(option)
    if not el then return end

    -- Vanilla uses getText(option.tooltip) during build; mirror that here
    local base = ""
    if option.tooltip then
        base = getText(option.tooltip)
    end

    local full
    if base ~= "" then
        -- avoid double-append
        if string.find(base, option._bcTooltipSuffix, 1, true) then
            full = base
        else
            full = base .. "\n" .. option._bcTooltipSuffix
        end
    else
        full = option._bcTooltipSuffix
    end

    _setTooltipOnElement(el, full)
end

function Patch.install()
    if Patch._installed then return end
    Patch._installed = true

    require("OptionScreens/MainOptions")

    local _old = MainOptions.addModOptionsPanel
    if not _old then return end

    MainOptions.addModOptionsPanel = function(self, ...)
        _old(self, ...)

        -- After vanilla builds all mod options and assigns option.element,
        -- apply suffixes to any BetterContainers options (or any option that set _bcTooltipSuffix).
        if PZAPI and PZAPI.ModOptions and PZAPI.ModOptions.Data then
            for _, group in ipairs(PZAPI.ModOptions.Data) do
                for _, opt in ipairs(group.data) do
                    if opt and opt._bcTooltipSuffix then
                        Patch.apply(opt)
                    end
                end
            end
        end
    end
end

return Patch
