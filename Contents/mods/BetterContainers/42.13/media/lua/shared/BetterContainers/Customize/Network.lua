local Helpers = require("BetterContainers/Helpers")
local ModData = require("BetterContainers/Customize/ModData")

local Network = {}

-- Vanilla MP-safe path:
--   client writes Parent modData
--   client calls Parent:transmitModData()
-- Server distributes modData to other clients.

Network.syncModData = function(player, parent, payload)
    -- Vanilla sync to server/clients
    if parent.transmitModData then
        parent:transmitModData()
    elseif instanceof(parent, "InventoryItem") then
        -- payload is table and contains either kind = user/global or regular payload
        -- TODO Send ModData to Server for Items
    end
end

Network.applyPayload = function(player, parent, payload)
    if not (player and parent and payload) then
        return
    end

    local username = player:getUsername()

    -- Per-user customization (sanitizes; clears if empty)
    ModData.setUser(parent, username, payload)

    -- Set Global for now
    ModData.setGlobal(parent, payload)

    Network.syncModData(player, parent, payload)

    Helpers.dlog("Customize applied user=" .. tostring(username))
end

-- ---------------------------------------------------------
-- Clear per-user customization + vanilla sync
-- ---------------------------------------------------------
Network.clearUser = function(player, parent)
    if not (player and parent) then
        return
    end

    local username = player:getUsername()

    ModData.clearUser(parent, username)

    Network.syncModData(player, parent, { kind = "user" })

    Helpers.dlog("Customize reset user=" .. tostring(username))
end

Network.clearGlobal = function(player, parent)
    if not (player and parent) then
        return
    end

    ModData.clearGlobal(parent)

    Network.syncModData(player, parent, { kind = "global" })

    Helpers.dlog("Customize reset global")
end

return Network