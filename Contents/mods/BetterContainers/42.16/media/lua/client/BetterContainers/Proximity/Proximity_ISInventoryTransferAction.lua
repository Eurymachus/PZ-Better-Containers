local Proximity = require("BetterContainers/Proximity")

local ProximityInventoryTransferAction = {}

ProximityInventoryTransferAction._installed = false

function ProximityInventoryTransferAction.install()
    if ProximityInventoryTransferAction._installed then return end
    ProximityInventoryTransferAction._installed = true

    local old_ISInventoryTransferAction_start = ISInventoryTransferAction.start
    function ISInventoryTransferAction:start(...)
        local playerNum = self.character and self.character:getPlayerNum()
        if playerNum ~= nil then
            Proximity.setTransferRunning(playerNum, true)
        end

        if old_ISInventoryTransferAction_start then
            return old_ISInventoryTransferAction_start(self, ...)
        end
    end

    local old_ISInventoryTransferAction_perform = ISInventoryTransferAction.perform
    function ISInventoryTransferAction:perform(...)
        local playerNum = self.character and self.character:getPlayerNum()

        local ret
        if old_ISInventoryTransferAction_perform then
            ret = old_ISInventoryTransferAction_perform(self, ...)
        end

        if playerNum ~= nil and (self.started == false or not self.queueList or #self.queueList == 0) then
            Proximity.setTransferRunning(playerNum, false)
        end

        return ret
    end

    local old_ISInventoryTransferAction_stop = ISInventoryTransferAction.stop
    function ISInventoryTransferAction:stop(...)
        local playerNum = self.character and self.character:getPlayerNum()
        if playerNum ~= nil then
            Proximity.setTransferRunning(playerNum, false)
        end

        if old_ISInventoryTransferAction_stop then
            return old_ISInventoryTransferAction_stop(self, ...)
        end
    end
end

return ProximityInventoryTransferAction
