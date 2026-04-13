local Const = require("BetterContainers/Reorder/Constants")
local ModData = require("BetterContainers/Reorder/ModData")

local function onClientCommand(module, command, playerObj, args)
    if not module or module ~= Const.MODULEID then return end
    if not args then return end
    if command == Const.Commands.SaveOrder then
        if args.kind then
            ModData.applyPriority(playerObj, args)
        end
    end

    if command == Const.Commands.SetLock then
        ModData.setLock(playerObj, args.onCharacter, args.value)
    end

    if command == Const.Commands.SetSortLoot then
        ModData.setSortLootWindow(playerObj, args.value)
    end
end

Events.OnClientCommand.Add(onClientCommand)