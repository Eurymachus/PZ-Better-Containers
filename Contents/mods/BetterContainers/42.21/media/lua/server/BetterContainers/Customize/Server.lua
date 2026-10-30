local Target = require("BetterContainers/Customize/ItemTarget")
local ModData = require("BetterContainers/Customize/ModData")

local function onClientCommand(module, command, player, args)
    if module ~= "BetterContainers" or command ~= "CustomizeItem" then return end
    if not player or type(args) ~= "table" then return end
    if args.action ~= "apply" and args.action ~= "user" and args.action ~= "global" then return end
    if args.action == "apply" and type(args.payload) ~= "table" then return end
    local item, owner = Target.resolve(args.target, player)
    if not item or not instanceof(item, "InventoryContainer") then return end

    local username = player:getUsername()
    if args.action == "apply" then
        local payload = ModData.sanitize(args.payload)
        ModData.setUser(item, username, payload, 0)
        ModData.setGlobal(item, payload, 0)
    elseif args.action == "user" then
        ModData.clearUser(item, username, 0)
    else
        ModData.clearGlobal(item, 0)
    end
    ModData.setVanillaName(item:getInventory(), item, ModData.getEffective(item, username, 0), 0)
    -- Persist the changed item inside its owning world object or vehicle chunk.
    if owner then owner:flagForHotSave() end

    if args.target.kind == "player" then args.target.playerId = player:getOnlineID() end
    sendServerCommand("BetterContainers", "CustomizeItemSaved", {
        target = args.target,
        username = username,
        user = ModData.getUser(item, username, 0),
        global = ModData.getGlobal(item, 0),
    })
end

Events.OnClientCommand.Add(onClientCommand)
