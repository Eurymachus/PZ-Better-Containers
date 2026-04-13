local EC = require("BetterContainers/Helpers")

local IconCatalogue = {}

IconCatalogue._cache = nil
IconCatalogue._dirty = true

local function trim(s)
    if s == nil then return "" end
    s = tostring(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _stripModule(fullType)
    if type(fullType) ~= "string" then return "" end
    return (fullType:gsub("^.-%.", ""))
end

local function _getModule(fullType)
    if type(fullType) ~= "string" then return "?" end
    local mod = fullType:match("^([^%.]+)%.")
    return mod or "?"
end

local function _makeSearchTextEx(label, variant, fullType)
    local fullTypeStr = tostring(fullType or "")
    local module = _getModule(fullTypeStr)
    local typePart = _stripModule(fullTypeStr)
    return string.lower(trim(tostring(label or "")) .. " " ..
        trim(tostring(variant or "")) .. " " ..
        trim(tostring(fullTypeStr)) .. " " ..
        trim(tostring(module)) .. " " ..
        trim(tostring(typePart)))
end

local function _buildVariant(iconRef)
    if not iconRef then return nil end
    local s = tostring(iconRef)
    local suffix = s:match("^.*_([^_]+)$")
    if not suffix or suffix == "" then
        return nil
    end
    if suffix:match("^%d+$") then
        return nil
    end
    return suffix
end

local function _build()
    local allItems = getAllItems and getAllItems() or nil
    if not allItems then
        return {
            groupsByKey = {},
            groupsSorted = {},
        }
    end

    local q1 = getTexture and getTexture("Question_On") or nil
    local q2 = getTexture and getTexture("Question_Off") or nil

    local groupsByKey = {}
    local groupsSorted = {}

    for i = 0, allItems:size() - 1 do
        local item = allItems:get(i)
        if item and (not item:getObsolete()) and (not item:isHidden()) then
            local fullType = item.getFullName and item:getFullName() or nil
            if type(fullType) == "string" and fullType ~= "" then
                -- If the ScriptItem has IconsForTexture, index EVERY entry by using fullType:idx.
                -- EC.getIconTexture(fullType) is deterministic and only uses index 0 unless :idx is supplied.
                local iconRefs = nil

                if item.getIconsForTexture then
                    local icons = item:getIconsForTexture()
                    if icons and icons.size and icons:size() > 0 then
                        iconRefs = {}
                        for idx = 0, icons:size() - 1 do
                            iconRefs[#iconRefs + 1] = fullType .. ":" .. tostring(idx)
                        end
                    end
                end

                -- Fallback: normal items (or items without IconsForTexture)
                if not iconRefs then
                    iconRefs = { fullType }
                end

                for r = 1, #iconRefs do
                    local iconRef = iconRefs[r]
                    local tex, iconId = EC.getIconTexture(iconRef)

                    if tex and tex ~= q1 and tex ~= q2 then
                        local groupKey = tostring(tex)
                        local group = groupsByKey[groupKey]

                        if not group then
                            local name = item:getDisplayName()
                            local displayCat = item.getDisplayCategory and item:getDisplayCategory() or nil
                            if displayCat == "" then displayCat = nil end
                            if type(displayCat) == "string" then
                                displayCat = displayCat:lower()
                            end

                            group = {
                                kind = "group",
                                groupKey = groupKey,
                                tex = tex,
                                id  = iconId,

                                key  = iconRef, -- representative iconRef/fullType
                                name = name,
                                label = name,
                                variant = _buildVariant(iconId),

                                module = _getModule(iconRef),

                                displayCategory = displayCat,

                                children = {},
                                _childSet = {},
                                _childNameSet = {},
                                _fullTypeCount = 0,
                            }

                            groupsByKey[groupKey] = group
                        end

                        if not group._childSet[iconRef] then
                            group._childSet[iconRef] = true
                            group._fullTypeCount = (group._fullTypeCount or 0) + 1

                            local childName = item:getDisplayName()
                            local nameKey = tostring(childName or ""):lower()

                            local existing = group._childNameSet[nameKey]
                            if existing then
                                existing._aliasSet = existing._aliasSet or {}
                                if not existing._aliasSet[iconRef] then
                                    existing._aliasSet[iconRef] = true
                                    existing._aliasList = existing._aliasList or {}
                                    existing._aliasList[#existing._aliasList + 1] = iconRef
                                end
                            else
                                local child = {
                                    kind = "child",
                                    parentKey = group.groupKey,
                                    tex = group.tex,
                                    id  = group.id,

                                    key  = iconRef,
                                    name = childName,
                                    label = childName,
                                    variant = _buildVariant(group.id),

                                    module = _getModule(iconRef),

                                    displayCategory = group.displayCategory,

                                    _aliasSet = { [iconRef] = true },
                                    _aliasList = { iconRef },
                                }

                                group._childNameSet[nameKey] = child
                                table.insert(group.children, child)
                            end
                        end
                    end
                end
            end
        end
    end

    for _, group in pairs(groupsByKey) do
        group._childSet = nil
        group._childNameSet = nil

        local visibleChildCount = 0
        for c = 1, #group.children do
            local child = group.children[c]
            local isHeaderChild = child and child._aliasSet and group.key and child._aliasSet[group.key]
            if child and (not isHeaderChild) then
                visibleChildCount = visibleChildCount + 1
            end
        end

        group.canExpand = (visibleChildCount > 0)

        group.searchText = _makeSearchTextEx(group.label, group.variant, group.key)

        for i = 1, #group.children do
            local c = group.children[i]
            local blob = ""
            if c._aliasList and #c._aliasList > 0 then
                blob = table.concat(c._aliasList, " ")
            else
                blob = tostring(c.key or "")
            end

            c.searchText = string.lower(trim(tostring(c.label or "")) .. " " ..
                trim(tostring(c.variant or "")) .. " " ..
                trim(blob))
        end

        groupsSorted[#groupsSorted + 1] = group
    end

    table.sort(groupsSorted, function(a, b)
        return tostring(a.name or ""):lower() < tostring(b.name or ""):lower()
    end)

    return {
        groupsByKey = groupsByKey,
        groupsSorted = groupsSorted,
    }
end

function IconCatalogue.invalidate()
    IconCatalogue._dirty = true
end

function IconCatalogue.getCatalogue()
    if IconCatalogue._cache == nil or IconCatalogue._dirty then
        IconCatalogue._cache = _build()
        IconCatalogue._dirty = false
    end
    return IconCatalogue._cache
end

function IconCatalogue.getItemsForDisplayCategory(catKey)
    local cat = tostring(catKey or ""):lower()
    if cat == "" then return {} end

    local out = {}
    local catData = IconCatalogue.getCatalogue()
    local list = catData and catData.groupsSorted or nil
    if not list then return out end

    for i = 1, #list do
        local g = list[i]
        if g and g.displayCategory and g.displayCategory == cat then
            out[#out + 1] = g
        end
    end
    return out
end

return IconCatalogue
