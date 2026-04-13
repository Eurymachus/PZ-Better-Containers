local Const = require("BetterContainers/Constants")
local ModData = require("BetterContainers/Reorder/ModData")

local function onClientCommand(module, command, playerObj, args)
    if not module or module ~= Const.MODULEID then return end
    if not args then return end
    if command == Const.Commands.SaveOrder then
        if args.kind then
            ModData.applyPriority(playerObj, args)
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)