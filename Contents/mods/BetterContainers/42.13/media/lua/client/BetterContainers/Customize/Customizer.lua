local Helpers = require("BetterContainers/Helpers")
local Network = require("BetterContainers/Customize/Network")
local ModData = require("BetterContainers/Customize/ModData")

local Customizer = {}

Customizer.Icons = {
    Customize = "media/ui/BetterContainers/Customize/customize.png",
    Presets = "media/ui/BetterContainers/Customize/presets.png",
}

Customizer.Icons.Loaded = {
    Customize = getTexture(Customizer.Icons.Customize),
    Presets = getTexture(Customizer.Icons.Presets),
}

-- ---------------------------------------------------------
-- Clipboard (client-only)
-- ---------------------------------------------------------

Customizer._clipboard = nil

local function _deepCopy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            out[k] = _deepCopy(v)
        else
            out[k] = v
        end
    end
    return out
end

local function _copyPayload(payload)
    if type(payload) ~= "table" then return nil end
    -- Normalize to our contract (name/icon/color only), and deep-copy so we don't alias modData tables.
    local clean = ModData.sanitize(payload)
    if not clean then return nil end
    if clean.name == nil and clean.icon == nil and clean.color == nil then
        return nil
    end
    return _deepCopy(clean)
end

Customizer.hasClipboard = function()
    return Customizer._clipboard ~= nil
end

-- Copy effective customization (user > _global) from this container
Customizer.copy = function(page, parent)
    if not (page and parent) then return end

    local playerObj = getSpecificPlayer(page.player or 0)
    if not playerObj then return end

    local username = playerObj:getUsername()
    local effective = ModData.getEffective(parent, username)

    Customizer._clipboard = _copyPayload(effective)

    if Customizer._clipboard then
        Helpers.dlog("Customize Copy ok")
    else
        Helpers.dlog("Customize Copy empty")
    end
end

-- Paste clipboard into target container as per-user customization
Customizer.paste = function(button, page, parent)
    if not (button and page and parent) then return end
    if not Customizer._clipboard then return end

    local playerObj = getSpecificPlayer(page.player or 0)
    if not playerObj then return end

    local username = playerObj:getUsername()

    Network.applyPayload(playerObj, parent, Customizer._clipboard)

    -- Immediate local refresh for UX
    local isSelectedNow = (page and page.selectedButton == button) or false
    Customizer.applyToButton(button, page, parent, isSelectedNow)
    page:refreshBackpacks()
end

-- ---------------------------------------------------------
-- Public getter helpers (UI-facing)
-- ---------------------------------------------------------

-- Returns the per-user customization node, or nil
Customizer.getUserData = function(page, parent)
    if not (page and parent) then
        return nil
    end

    local playerObj = getSpecificPlayer(page.player or 0)
    if not playerObj then
        return nil
    end

    local username = playerObj:getUsername()
    return ModData.getUser(parent, username)
end

-- Returns the per-user customization node, or nil
Customizer.getGlobalData = function(parent)
    if not (parent) then
        return nil
    end
    return ModData.getGlobal(parent)
end

Customizer.getEffectiveData = function(page, parent)
    if not (page and parent) then
        return nil
    end

    local playerObj = getSpecificPlayer(page.player or 0)
    if not playerObj then
        return nil
    end

    local username = playerObj:getUsername()
    return ModData.getEffective(parent, username)
end

Customizer.hasData = function(page, parent)
    return Customizer.getEffectiveData(page, parent) ~= nil
end

Customizer.getPayload = function(button, page, parent)
    if not (button and page and parent) then
        return nil
    end

    local playerObj = getSpecificPlayer(page.player or 0)
    if not playerObj then
        return nil
    end

    local username = playerObj:getUsername()
    local effective = ModData.getEffective(parent, username)

    local clean = _copyPayload(effective)
    if clean then
        return clean
    end

    -- Fallback: "no customization" but UI still needs a baseline name.
    return {
        name  = button.name or "",
        icon  = nil,
        color = nil,
    }
end

-- ---------------------------------------------------------
-- Color helpers
-- ---------------------------------------------------------

local function _lerpToWhite(v, amt)
    return v + (1 - v) * amt
end

local function _lightenRGBA(r, g, b, a, amt)
    -- amt 0..1
    if amt < 0 then amt = 0 elseif amt > 1 then amt = 1 end
    return _lerpToWhite(r, amt), _lerpToWhite(g, amt), _lerpToWhite(b, amt), a
end

local function _copyColor(c)
    if type(c) ~= "table" then return nil end
    return { r = c.r, g = c.g, b = c.b, a = c.a }
end

local function _normColor(rgba)
    if type(rgba) ~= "table" then return nil end

    local r = tonumber(rgba.r)
    local g = tonumber(rgba.g)
    local b = tonumber(rgba.b)
    local a = tonumber(rgba.a)

    if not (r and g and b) then
        return nil
    end

    -- Treat values > 1 as 0..255
    if r > 1 or g > 1 or b > 1 or (a and a > 1) then
        r = r / 255
        g = g / 255
        b = b / 255
        if a ~= nil then a = a / 255 end
    end

    if a == nil then a = 1 end

    -- Clamp
    if r < 0 then r = 0 elseif r > 1 then r = 1 end
    if g < 0 then g = 0 elseif g > 1 then g = 1 end
    if b < 0 then b = 0 elseif b > 1 then b = 1 end
    if a < 0 then a = 0 elseif a > 1 then a = 1 end

    return r, g, b, a
end

-- ---------------------------------------------------------
-- Button skinning
-- ---------------------------------------------------------

local function _captureBaseVisuals(button)
    if not button or button._bcBaseCaptured then return end

    button._bcBaseCaptured = true

    button._bcBaseName = button.name
    button._bcBaseTooltip = button.tooltip

    -- Texture/image varies across ISButton wrappers.
    button._bcBaseTexture = button.texture or button.image or button.icon or nil

    -- Background colors (tables on ISButton).
    button._bcBaseBGMO = _copyColor(button.backgroundColorMouseOver)
end

local function _applyTexture(button, tex)
    if not (button and tex) then return end

    if button.setImage then
        button:setImage(tex)
        return
    end

    -- Fallbacks: assign common fields.
    button.texture = tex
    button.image = tex
    button.icon = tex
end

local function _restoreTexture(button)
    if not (button and button._bcBaseCaptured) then return end
    local tex = button._bcBaseTexture
    if not tex then return end
    _applyTexture(button, tex)
end

local function _applyBG(button, r, g, b, a)
    if not button then return end

    if button.setBackgroundRGBA then
        button:setBackgroundRGBA(r, g, b, a)
    else
        button.backgroundColor = { r = r, g = g, b = b, a = a }
    end
end

local function _applyBGMO(button, r, g, b, a)
    if not button then return end

    if button.setBackgroundColorMouseOverRGBA then
        button:setBackgroundColorMouseOverRGBA(r, g, b, a)
    else
        button.backgroundColorMouseOver = { r = r, g = g, b = b, a = a }
    end
end

local function _restoreBG(button)
    if not (button and button._bcBaseCaptured) then return end

    -- DO NOT restore backgroundColor here. Vanilla refreshBackpacks() sets it every refresh
    -- (selected highlight + unselected transparency). Restoring cached BG causes “every other”
    -- selection artifacts and breaks selected/scrolled-to highlight for skinned/no-color buttons.
    if button._bcBaseBGMO then
        _applyBGMO(button, button._bcBaseBGMO.r, button._bcBaseBGMO.g, button._bcBaseBGMO.b, button._bcBaseBGMO.a)
    end
end

-- Apply effective modData (user > _global) to an existing container button.
-- isSelected influences the base/hover backgrounds we assign.
Customizer.applyToButton = function(button, page, parent, isSelected)
    if not (button and page and parent) then
        return
    end

    _captureBaseVisuals(button)

    local playerObj = getSpecificPlayer(page.player or 0)
    if not playerObj then
        return
    end

    local username = playerObj:getUsername()
    local payload = ModData.getEffective(parent, username)

    if not payload then
        return
    end

    -- Name + tooltip
    if payload.name and payload.name ~= "" then
        button.name = payload.name
        button.tooltip = payload.name
    else
        button.name = button._bcBaseName
        button.tooltip = button._bcBaseTooltip
    end

    --   "Base.Item" or "Base.Item:idx" (0-based IconsForTexture)
    if payload.icon then
        local iconRef = tostring(payload.icon)
        local tex = Helpers.getIconTexture(iconRef)

        if tex then
            _applyTexture(button, tex)
        else
            _restoreTexture(button)
        end
    else
        _restoreTexture(button)
    end

    -- Background color
    if isSelected then
        -- Leave backgroundColor as vanilla set it this refresh.
        -- Ensure BGMO isn't left as a stale custom color.
        _restoreBG(button)
    else
        if payload.color then
            local r, g, b, a = _normColor(payload.color)
            if r then
                local hoverAmt = 0.15
                local hr, hg, hb, ha = _lightenRGBA(r, g, b, a, hoverAmt)

                -- Unselected custom slot color (this is your feature)
                _applyBG(button, r, g, b, a)
                _applyBGMO(button, hr, hg, hb, ha)
            else
                -- Bad payload: revert BGMO only; let vanilla keep BG.
                _restoreBG(button)
            end
        else
            -- No custom color: leave BG as vanilla (unselected transparent); restore BGMO only.
            _restoreBG(button)
        end
    end
end

-- ---------------------------------------------------------
-- Context menu selection entrypoint
-- ---------------------------------------------------------
Customizer.applyPayload = function(button, page, parent, payload)
    if not (button and page and parent and payload) then
        return
    end

    local playerObj = getSpecificPlayer(page.player or 0)
    if not playerObj then
        return
    end

    if button.inventory then
        ModData.setVanillaName(button.inventory, parent, payload)
    end
    Network.applyPayload(playerObj, parent, payload)

    local isSelectedNow = (page and page.selectedButton == button) or false
    Customizer.applyToButton(button, page, parent, isSelectedNow)
end

Customizer.reset = function(button, page, parent)
    if not (button and page and parent) then
        return
    end

    local playerObj = getSpecificPlayer(page.player or 0)
    if not playerObj then
        return
    end

    if button.inventory then
        ModData.setVanillaName(button.inventory, parent, nil)
    end

    Network.clearUser(playerObj, parent)
    -- Clear global for now
    Network.clearGlobal(playerObj, parent)

    Customizer.applyToButton(button, page, parent)
    page:refreshBackpacks()
end

return Customizer