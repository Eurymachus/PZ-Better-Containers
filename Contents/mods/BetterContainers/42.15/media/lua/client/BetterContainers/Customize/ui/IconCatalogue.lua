local EC = require("BetterContainers/Helpers")

local IconCatalogue = {}

IconCatalogue._cache = nil
IconCatalogue._dirty = true

local function trim(s)
    if s == nil then return "" end
    s = tostring(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _getModule(fullType)
    if type(fullType) ~= "string" then return "?" end
    local mod = fullType:match("^([^%.]+)%.")
    return mod or "?"
end

local function _makeIcon(kind, value)
    return {
        kind = tostring(kind),
        value = tostring(value),
    }
end

local function _iconKey(icon)
    if type(icon) ~= "table" then return nil end
    local kind = tostring(icon.kind or "")
    local value = tostring(icon.value or "")
    if kind == "" or value == "" then return nil end
    return kind .. "|" .. value
end

local function _makeSearchTextEx(label, variant, key, sourceBucket, displayCat, displayCatText)
    return string.lower(
        trim(tostring(label or "")) .. " " ..
        trim(tostring(variant or "")) .. " " ..
        trim(tostring(key or "")) .. " " ..
        trim(tostring(sourceBucket or "")) .. " " ..
        trim(tostring(displayCat or "")) .. " " ..
        trim(tostring(displayCatText or ""))
    )
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

local function _prettyContainerLabel(key)
    local s = tostring(key or "")
    s = s:gsub("([a-z])([A-Z])", "%1 %2")
    s = s:gsub("_", " ")
    s = s:gsub("%s+", " ")
    s = trim(s)
    if s == "" then
        return "Container"
    end
    return (s:gsub("^%l", string.upper))
end

local function _buildItemGroups(groupsByKey, q1, q2)
    local allItems = getAllItems and getAllItems() or nil
    if not allItems then return end

    for i = 0, allItems:size() - 1 do
        local item = allItems:get(i)
        if item and (not item:getObsolete()) and (not item:isHidden()) then
            local fullType = item.getFullName and item:getFullName() or nil
            if type(fullType) == "string" and fullType ~= "" then
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

                if not iconRefs then
                    iconRefs = { fullType }
                end

                for r = 1, #iconRefs do
                    local iconRef = iconRefs[r]
                    local iconDef = _makeIcon("item", iconRef)
                    local tex, iconId = EC.getIconTexture(iconDef)

                    if tex and tex ~= q1 and tex ~= q2 then
                        local groupKey = "item|" .. tostring(tex)
                        local group = groupsByKey[groupKey]

                        if not group then
                            local name = item:getDisplayName()
                            local displayCat = item.getDisplayCategory and item:getDisplayCategory() or nil
                            if displayCat == "" then displayCat = nil end
                            if type(displayCat) == "string" then
                                displayCat = displayCat:lower()
                            end

                            local displayCatText = nil
                            if displayCat and displayCat ~= "" then
                                displayCatText = getTextOrNull("IGUI_ItemCat_" .. displayCat) or displayCat
                            end

                            group = {
                                kind = "group",
                                groupKey = groupKey,
                                tex = tex,
                                id  = iconId,

                                icon = iconDef,
                                key  = iconRef,
                                name = name,
                                label = name,
                                variant = _buildVariant(iconId),

                                module = _getModule(iconRef),
                                sourceBucket = "items",
                                displayCategory = displayCat,
                                displayCategoryText = displayCatText,

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
                                local displayCatText = nil
                                if group.displayCategory and group.displayCategory ~= "" then
                                    displayCatText = getTextOrNull("IGUI_ItemCat_" .. group.displayCategory) or group.displayCategory
                                end
                                local child = {
                                    kind = "child",
                                    parentKey = group.groupKey,
                                    tex = group.tex,
                                    id  = group.id,

                                    icon = _makeIcon("item", iconRef),
                                    key  = iconRef,
                                    name = childName,
                                    label = childName,
                                    variant = _buildVariant(group.id),

                                    module = _getModule(iconRef),
                                    sourceBucket = "items",
                                    displayCategory = group.displayCategory,
                                    displayCategoryText = displayCatText,

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
end

local function _buildContainerGroups(groupsByKey, groupsSorted)
    if type(ContainerButtonIcons) ~= "table" then
        return
    end

    local seen = {}

    for key, tex in pairs(ContainerButtonIcons) do
        if key and tex and not seen[key] then
            seen[key] = true

            local iconDef = _makeIcon("container", key)
            local groupKey = "container|" .. tostring(key)

            local group = {
                kind = "group",
                groupKey = groupKey,
                tex = tex,
                id = tostring(key),

                icon = iconDef,
                key = tostring(key),
                name = _prettyContainerLabel(key),
                label = _prettyContainerLabel(key),
                variant = nil,

                module = "container",
                sourceBucket = "vanilla_containers",
                displayCategory = "vanilla containers",
                displayCategoryText = "Container",

                children = {},
                _childSet = {},
                _childNameSet = {},
                _fullTypeCount = 1,
                canExpand = false,
            }

            groupsByKey[groupKey] = group
            groupsSorted[#groupsSorted + 1] = group
        end
    end
end

local function _build()
    local q1 = getTexture and getTexture("Question_On") or nil
    local q2 = getTexture and getTexture("Question_Off") or nil

    local groupsByKey = {}
    local groupsSorted = {}

    _buildItemGroups(groupsByKey, q1, q2)
    _buildContainerGroups(groupsByKey, groupsSorted)

    local iconToGroupIcon = {}
    local iconToGroupKey = {}
    local visibleTargetByIconKey = {}

    for _, group in pairs(groupsByKey) do
        group._childSet = nil
        group._childNameSet = nil

        if group.sourceBucket == "items" then
            local visibleChildCount = 0
            for c = 1, #group.children do
                local child = group.children[c]
                local isHeaderChild = child and child._aliasSet and group.key and child._aliasSet[group.key]
                if child and (not isHeaderChild) then
                    visibleChildCount = visibleChildCount + 1
                end
            end
            group.canExpand = (visibleChildCount > 0)
        end

        group.searchText = _makeSearchTextEx(group.label, group.variant, group.key, group.sourceBucket, group.displayCategory, group.displayCategoryText)

        for i = 1, #group.children do
            local c = group.children[i]
            local blob = ""
            if c._aliasList and #c._aliasList > 0 then
                blob = table.concat(c._aliasList, " ")
            else
                blob = tostring(c.key or "")
            end

            c.searchText = _makeSearchTextEx(c.label, c.variant, blob, c.sourceBucket, c.displayCategory, c.displayCategoryText)
        end

        local gIconKey = _iconKey(group.icon)
        if gIconKey then
            iconToGroupIcon[gIconKey] = group.icon
            iconToGroupKey[gIconKey] = group.groupKey
        end

        for i = 1, #group.children do
            local c = group.children[i]
            local cIconKey = c and _iconKey(c.icon) or nil
            if cIconKey then
                iconToGroupIcon[cIconKey] = group.icon
                iconToGroupKey[cIconKey] = group.groupKey
            end
        end

        -- Visible-target cache:
        -- for any semantic icon identity, record the visible picker target that
        -- should represent it.
        local function registerVisible(iconDef, targetIcon, targetKind)
            local k = _iconKey(iconDef)
            if not k then return end

            visibleTargetByIconKey[k] = {
                icon = targetIcon,
                groupKey = group.groupKey,
                targetKind = targetKind, -- "group" or "child"
            }
        end

        -- Group icon is always represented by the group itself.
        registerVisible(group.icon, group.icon, "group")

        for i = 1, #group.children do
            local c = group.children[i]
            local isHeaderChild = c and c._aliasSet and group.key and c._aliasSet[group.key]

            if c then
                local targetIcon = isHeaderChild and group.icon or c.icon
                local targetKind = isHeaderChild and "group" or "child"

                if isHeaderChild then
                    -- This child is folded into the header/alias row.
                    registerVisible(c.icon, targetIcon, targetKind)
                else
                    -- This child has its own visible row in list view.
                    registerVisible(c.icon, targetIcon, targetKind)
                end

                if c._aliasList and #c._aliasList > 0 then
                    for a = 1, #c._aliasList do
                        local aliasRef = c._aliasList[a]
                        if aliasRef and aliasRef ~= "" then
                            local aliasIcon = _makeIcon("item", aliasRef)

                            registerVisible(aliasIcon, targetIcon, targetKind)

                            local aliasKey = _iconKey(aliasIcon)
                            if aliasKey then
                                iconToGroupIcon[aliasKey] = group.icon
                                iconToGroupKey[aliasKey] = group.groupKey
                            end
                        end
                    end
                end
            end
        end

        -- Container groups are already inserted when built.
        -- Item groups are only stored in groupsByKey, so add them here.
        if group.sourceBucket == "items" then
            groupsSorted[#groupsSorted + 1] = group
        end
    end

    table.sort(groupsSorted, function(a, b)
        local ab = tostring(a.sourceBucket or ""):lower()
        local bb = tostring(b.sourceBucket or ""):lower()
        if ab ~= bb then
            return ab < bb
        end

        local ad = tostring(a.displayCategoryText or ""):lower()
        local bd = tostring(b.displayCategoryText or ""):lower()
        if ad ~= bd then
            return ad < bd
        end

        local an = tostring(a.name or a.label or ""):lower()
        local bn = tostring(b.name or b.label or ""):lower()
        return an < bn
    end)

    return {
        groupsByKey = groupsByKey,
        groupsSorted = groupsSorted,
        iconToGroupIcon = iconToGroupIcon,
        iconToGroupKey = iconToGroupKey,
        visibleTargetByIconKey = visibleTargetByIconKey,
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