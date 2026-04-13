local Constants = require("BetterContainers/Reorder/Constants")
local ModData = require("BetterContainers/Reorder/ModData")
local Helpers = require("BetterContainers/Helpers")

local Network = {}

function Network.sendPriority(playerObj, entry)
    if not entry then return end

    if isClient() then
        sendClientCommand(playerObj, Constants.MODULEID, Constants.Commands.SaveOrder, entry)
    end
end

Network.setSortPriority = function(player, inventory, priority, isManual)
    local entryOrTarget = ModData.setSortPriority(player, inventory, priority, isManual)

    if type(entryOrTarget) == "table" then
        Network.sendPriority(player, entryOrTarget)
    elseif entryOrTarget and entryOrTarget.transmitModData then
        entryOrTarget:transmitModData()
    else
        Helpers.dlog("Critical Error: could not setSortPriority")
    end
end

function Network.setSortLootWindow(playerObj, value)
    ModData.setSortLootWindow(playerObj, value)

    if isClient() then
        local args = {
            value = value
        }
        sendClientCommand(playerObj, Constants.MODULEID, Constants.Commands.SetSortLoot, args)
    end
end

function Network.setLock(playerObj, onCharacter, value)
    if not isClient() then return end
    local args = {
        onCharacter = onCharacter,
        value = value,
    }
    sendClientCommand(playerObj, Constants.MODULEID, Constants.Commands.SetLock, args)
end

function Network.toggleLock(playerObj, onCharacter)
    local newState = nil
    if onCharacter then
        newState = ModData.toggleInventoryLock(playerObj)
    else
        newState = ModData.toggleLootLock(playerObj)
    end
    Network.setLock(playerObj, onCharacter, newState)
end

return Network