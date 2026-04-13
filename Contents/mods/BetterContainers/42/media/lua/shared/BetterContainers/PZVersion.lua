local PZVersion = {}

-- Cached parsed values
local _major, _minor, _patch

local function parseVersion()
    if _major then
        return
    end

    local v = getCore():getVersion() or ""
    local maj, min, pat = v:match("(%d+)%.(%d+)%.?(%d*)")

    _major = tonumber(maj) or 0
    _minor = tonumber(min) or 0
    _patch = tonumber(pat) or 0
end

-- True if exactly 42.12.x
function PZVersion.is12()
    parseVersion()
    return _major == 42 and _minor == 12
end

-- True if exactly 42.13.x (any patch)
function PZVersion.is13()
    parseVersion()
    return _major == 42 and _minor == 13
end

-- True if exactly 42.13.1
function PZVersion.is13_1()
    parseVersion()
    return _major == 42 and _minor == 13 and _patch == 1
end

-- Generic helper (major/minor only)
function PZVersion.isAtLeast(major, minor)
    parseVersion()
    return (_major > major) or (_major == major and _minor >= minor)
end

-- Optional: full compare including patch
function PZVersion.isAtLeastFull(major, minor, patch)
    parseVersion()
    patch = patch or 0

    if _major ~= major then
        return _major > major
    end
    if _minor ~= minor then
        return _minor > minor
    end
    return _patch >= patch
end

return PZVersion
