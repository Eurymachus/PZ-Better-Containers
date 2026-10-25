-- Optional diagnostic only, outside Contents/ so it is never shipped with the mod.
-- Paste this file into the in-game Lua debugger after loading a test save.
-- BCInventoryProbe.install(); reproduce; BCInventoryProbe.report();
-- BCInventoryProbe.stop() disables measurement and restores untouched hooks.
-- Timings are inclusive, so nested totals must not be added together.
BCInventoryProbe = BCInventoryProbe or {hooks={}, stats={}, active=false}
local probe = BCInventoryProbe

local function finish(stat, started, verbose, observe, ...)
    local elapsed = getTimestampMs() - started
    stat.completed = stat.completed + 1
    stat.total = stat.total + elapsed
    stat.maximum = math.max(stat.maximum, elapsed)
    if verbose then print('[BC perf] end ' .. stat.name .. ' ms=' .. elapsed) end
    if observe then observe(...) end
    return ...
end

local function hook(target, key, name, verbose, observe, accepts)
    if not target or type(target[key]) ~= 'function' then return end
    local original = target[key]
    local stat = {name=name, entered=0, completed=0, total=0, maximum=0}
    probe.stats[#probe.stats+1] = stat
    local wrapped = function(...)
        if not probe.active then return original(...) end
        if accepts and not accepts(...) then return original(...) end
        stat.entered = stat.entered + 1
        local started = getTimestampMs()
        if verbose then print('[BC perf] begin ' .. name) end
        return finish(stat, started, verbose, observe, original(...))
    end
    target[key] = wrapped
    probe.hooks[#probe.hooks+1] = {target=target,key=key,original=original,wrapped=wrapped}
end

local function describeContainers(containers)
    if not containers then return end
    local seen = {}
    local total, duplicates = 0, 0
    for i=0,containers:size()-1 do
        local container = containers:get(i)
        if seen[container] then duplicates=duplicates+1 end
        seen[container]=true
        total=total+container:getItems():size()
    end
    print('[BC perf] crafting containers=' .. containers:size()
        .. ' itemEntries=' .. total .. ' repeatedContainers=' .. duplicates)
end

function probe.install()
    if probe.active then return end
    probe.stats = {}
    probe.hooks = {}
    probe.active = true
    hook(ISInventoryPane, 'renderdetails', 'renderdetails (both passes)', false)
    hook(ISInventoryPane, 'refreshContainer', 'refreshContainer', false)
    hook(ISInventoryPane, 'update', 'pane update', false)
    hook(ISInventoryPage, 'refreshBackpacks', 'page rebuild', false)
    hook(ISInventoryPage, 'update', 'page update', false)
    hook(ISInventoryPage, 'dirtyUI', 'dirtyUI', false)
    hook(rawget(_G, 'ISLootWindowContainerControls'), 'arrange', 'loot controls arrange', false)
    local proximity = require('BetterContainers/Proximity')
    hook(proximity, 'OnButtonsAdded', 'proximity aggregation', false)
    hook(proximity, 'OnAutoLockTick', 'proximity auto-lock tick', false)
    hook(ISInventoryPane, 'onRightMouseUp', 'onRightMouseUp', true)
    hook(ISInventoryPaneContextMenu, 'createMenu', 'createMenu', true)
    hook(ISInventoryPaneContextMenu, 'getContainers', 'getContainers', true, describeContainers)
    hook(ISInventoryPaneContextMenu, 'addNewCraftingDynamicalContextMenu', 'crafting submenu', true)
    hook(_G, 'triggerEvent', 'inventory context callbacks', true, nil, function(event)
        return event == 'OnPreFillInventoryObjectContextMenu' or event == 'OnFillInventoryObjectContextMenu'
    end)
    print('[BC perf] installed; use report() after reproducing, then stop()')
end

function probe.report()
    for _, stat in ipairs(probe.stats) do
        print('[BC perf] ' .. stat.name .. ' entered=' .. stat.entered
            .. ' completed=' .. stat.completed .. ' totalMs=' .. stat.total
            .. ' maxMs=' .. stat.maximum)
    end
end

function probe.stop()
    probe.active = false
    for i=#probe.hooks,1,-1 do
        local entry = probe.hooks[i]
        if entry.target[entry.key] == entry.wrapped then
            entry.target[entry.key] = entry.original
        end
    end
    probe.hooks = {}
end
