local Permissions = {}

local function _getSandboxBC()
    return (SandboxVars and SandboxVars.BetterContainers) or {}
end

-- Normalized BetterContainers sandbox policy with safe defaults.
-- Defaults must match media/sandbox-options.txt.
function Permissions.getSandbox()
    local sb = _getSandboxBC()
    return {
        ProximityEnabled     = (sb.ProximityEnabled ~= false),
        ForceCorpseOnly      = (sb.ForceCorpseOnly == true),
        AllowToggleProximity = (sb.AllowToggleProximity ~= false),
        AllowSwitchMode      = (sb.AllowSwitchMode ~= false),
        AutoLockEnabled      = (sb.AutoLockEnabled ~= false),
        AllowToggleAutoLock  = (sb.AllowToggleAutoLock ~= false),
    }
end

-- Compute effective behaviour + UI gating from sandbox policy and local options.
-- Pass in BetterContainers/_Options Options table.
function Permissions.compute(options)
    options = options or {}
    local sb = Permissions.getSandbox()

    local eff = {
        sandbox = sb,
        ui = {},
    }

    -- Proximity
    eff.allowToggleProximity = (sb.ProximityEnabled and sb.AllowToggleProximity) or false
    eff.proximityActive = (sb.ProximityEnabled == true) and (
        (sb.AllowToggleProximity == false) or (options.enableProximity == true)
    )

    -- Corpse-only mode
    eff.allowSwitchMode = (sb.ProximityEnabled == true)
        and (sb.ForceCorpseOnly == false)
        and (sb.AllowSwitchMode == true)

    eff.corpseOnly = (sb.ForceCorpseOnly == true) or (
        (sb.ForceCorpseOnly == false) and (sb.AllowSwitchMode == true) and (options.enableCorpseOnly == true)
    )

    -- Auto-lock (local pref key is Options.enableAutoLock)
    eff.allowToggleAutoLock = (sb.ProximityEnabled == true)
        and (sb.AutoLockEnabled == true)
        and (sb.AllowToggleAutoLock == true)

    -- Auto-lock forced ON when enabled by server and player toggling is disallowed.
    eff.autoLockForced = (sb.ProximityEnabled == true)
        and (sb.AutoLockEnabled == true)
        and (sb.AllowToggleAutoLock == false)

    if sb.AutoLockEnabled == true then
        if sb.AllowToggleAutoLock == true then
            eff.autoLock = (options.enableAutoLock == true)
        else
            eff.autoLock = true
        end
    else
        eff.autoLock = false
    end

    -- Proximity lock / force-selected toggle:
    -- Only gated when auto-lock is forced ON (otherwise keep existing behaviour).
    -- Also blocked when proximity isn't effectively active.
    eff.allowToggleLock = (sb.ProximityEnabled == true)
        and (eff.proximityActive == true)
        and (eff.autoLockForced == false)

    -- UI gating reasons (fallback to literal if you don't add translations)
    local REASON_SANDBOX_CONTROLLED = getTextOrNull("UI_SandboxControlledForThisSession") or "Sandbox controlled for this session"
    local REASON_DISABLED_BY_SANDBOX = getTextOrNull("UI_DisabledBySandboxForThisSession") or "Disabled by Sandbox for this session"
    local REASON_FORCED_BY_SANDBOX = getTextOrNull("UI_ForcedBySandboxForThisSession") or "Forced by Sandbox for this session"

    -- enableProximity
    if sb.ProximityEnabled == false then
        eff.ui.enableProximity = { enabled = false, reason = REASON_DISABLED_BY_SANDBOX }
    elseif sb.AllowToggleProximity == false then
        eff.ui.enableProximity = { enabled = false, reason = REASON_SANDBOX_CONTROLLED }
    else
        eff.ui.enableProximity = { enabled = true }
    end

    -- enableCorpseOnly
    if sb.ProximityEnabled == false then
        eff.ui.enableCorpseOnly = { enabled = false, reason = REASON_DISABLED_BY_SANDBOX }
    elseif sb.ForceCorpseOnly == true then
        eff.ui.enableCorpseOnly = { enabled = false, reason = REASON_FORCED_BY_SANDBOX }
    elseif sb.AllowSwitchMode == false then
        eff.ui.enableCorpseOnly = { enabled = false, reason = REASON_SANDBOX_CONTROLLED }
    else
        eff.ui.enableCorpseOnly = { enabled = true }
    end

    -- enableAutoLock (UI key reserved; you’ll add the actual option later)
    if sb.ProximityEnabled == false then
        eff.ui.enableAutoLock = { enabled = false, reason = REASON_DISABLED_BY_SANDBOX }
    elseif sb.AutoLockEnabled == false then
        eff.ui.enableAutoLock = { enabled = false, reason = REASON_DISABLED_BY_SANDBOX }
    elseif sb.AllowToggleAutoLock == false then
        eff.ui.enableAutoLock = { enabled = false, reason = REASON_SANDBOX_CONTROLLED }
    else
        eff.ui.enableAutoLock = { enabled = true }
    end

     -- lock / force-selected keybind
    if sb.ProximityEnabled == false then
        eff.ui.toggleLock = { enabled = false, reason = REASON_DISABLED_BY_SANDBOX }
    elseif eff.proximityActive == false then
        eff.ui.toggleLock = { enabled = false, reason = REASON_DISABLED_BY_SANDBOX }
    elseif eff.autoLockForced == true then
        eff.ui.toggleLock = { enabled = false, reason = REASON_SANDBOX_CONTROLLED }
    else
        eff.ui.toggleLock = { enabled = true }
    end

    return eff
end

return Permissions
