local Target = require("BetterContainers/Customize/ItemTarget")
local ModData = require("BetterContainers/Customize/ModData")

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "BetterContainers" or command ~= "CustomizeItemSaved" then return end
    local item = Target.resolve(args.target)
    if not item or not instanceof(item, "InventoryContainer") then return end
    ModData.setUser(item, args.username, args.user, 0)
    ModData.setGlobal(item, args.global, 0)
    ModData.setVanillaName(item:getInventory(), item, args.user or args.global, 0)
end)
