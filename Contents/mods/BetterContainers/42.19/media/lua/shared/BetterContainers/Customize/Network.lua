local Helpers = require("BetterContainers/Helpers")
local ModData = require("BetterContainers/Customize/ModData")

local Network = {}

Network.syncModData = function(player, parent, payload)
    if parent.transmitModData then
        parent:transmitModData()
    elseif instanceof(parent, "InventoryItem") then
        -- TODO Send ModData to Server for Items
    end
end

Network.applyPayload = function(player, parent, payload, containerIndex)
    if not (player and parent and payload) then
        return
    end

    local username = player:getUsername()

    ModData.setUser(parent, username, payload, containerIndex)
    ModData.setGlobal(parent, payload, containerIndex)

    Network.syncModData(player, parent, payload)

    Helpers.dlog("Customize applied user=" .. tostring(username) .. " idx=" .. tostring(containerIndex or 0))
end

Network.clearUser = function(player, parent, containerIndex)
    if not (player and parent) then
        return
    end

    local username = player:getUsername()

    ModData.clearUser(parent, username, containerIndex)

    Network.syncModData(player, parent, { kind = "user" })

    Helpers.dlog("Customize reset user=" .. tostring(username) .. " idx=" .. tostring(containerIndex or 0))
end

Network.clearGlobal = function(player, parent, containerIndex)
    if not (player and parent) then
        return
    end

    ModData.clearGlobal(parent, containerIndex)

    Network.syncModData(player, parent, { kind = "global" })

    Helpers.dlog("Customize reset global idx=" .. tostring(containerIndex or 0))
end

return Network