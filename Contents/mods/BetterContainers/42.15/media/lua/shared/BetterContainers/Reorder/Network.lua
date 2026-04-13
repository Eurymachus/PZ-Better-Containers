local Constants = require("BetterContainers/Constants")
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

return Network