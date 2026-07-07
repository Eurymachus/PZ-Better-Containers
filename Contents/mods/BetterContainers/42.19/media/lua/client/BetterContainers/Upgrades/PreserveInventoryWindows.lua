require "ISUI/ISInventoryPage"

local Options = require("BetterContainers/_Options")

local PreserveInventoryWindows = {}

local _installed = false
local _wasPaused = false
local _restoreInTicks = 0
local _lastUnpausedSnapshot = nil
local _restoreSnapshot = nil

local function isPaused()
    return isGamePaused and isGamePaused() == true
end

local function getPlayerCount()
    if getNumActivePlayers then
        return getNumActivePlayers()
    end
    return 1
end

local function pageIsVisible(page)
    return page and page.getIsVisible and page:getIsVisible() == true
end

local function snapshotInventoryWindows()
    local snapshot = {}

    for playerNum = 0, getPlayerCount() - 1 do
        local playerPage = getPlayerInventory and getPlayerInventory(playerNum) or nil
        local lootPage = getPlayerLoot and getPlayerLoot(playerNum) or nil

        snapshot[playerNum] = {
            player = pageIsVisible(playerPage),
            loot = pageIsVisible(lootPage),
        }
    end

    return snapshot
end

local function restorePage(page)
    if not page or pageIsVisible(page) then
        return false
    end

    page:setVisible(true)
    return true
end

local function restoreInventoryWindows()
    local snapshot = _restoreSnapshot
    _restoreSnapshot = nil

    if not snapshot then
        return
    end

    local restored = false

    for playerNum, state in pairs(snapshot) do
        if state.player then
            restored = restorePage(getPlayerInventory and getPlayerInventory(playerNum) or nil) or restored
        end

        if state.loot then
            restored = restorePage(getPlayerLoot and getPlayerLoot(playerNum) or nil) or restored
        end
    end

    if restored and ISInventoryPage and ISInventoryPage.dirtyUI then
        ISInventoryPage.dirtyUI()
    end
end

local function resetState()
    _wasPaused = isPaused()
    _restoreInTicks = 0
    _restoreSnapshot = nil
    _lastUnpausedSnapshot = nil
end

local function onTickEvenPaused()
    if Options.preserveInventoryWindowsAfterPause ~= true then
        resetState()
        return
    end

    local paused = isPaused()

    if paused then
        if not _wasPaused then
            _restoreSnapshot = _lastUnpausedSnapshot or snapshotInventoryWindows()
        end

        _wasPaused = true
        _restoreInTicks = 0
        return
    end

    if _wasPaused then
        _wasPaused = false
        _restoreInTicks = 2
        return
    end

    if _restoreInTicks > 0 then
        _restoreInTicks = _restoreInTicks - 1
        if _restoreInTicks == 0 then
            restoreInventoryWindows()
        end
        return
    end

    _lastUnpausedSnapshot = snapshotInventoryWindows()
end

function PreserveInventoryWindows.install()
    if _installed then
        return
    end
    _installed = true

    if Events.OnTickEvenPaused then
        Events.OnTickEvenPaused.Add(onTickEvenPaused)
    else
        Events.OnTick.Add(onTickEvenPaused)
    end
end

return PreserveInventoryWindows
