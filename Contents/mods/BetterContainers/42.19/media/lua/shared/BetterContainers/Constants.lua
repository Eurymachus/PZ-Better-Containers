local Constants = {}

Constants.MODULEID = "BetterContainers"

Constants.SORT_KEY = "ReorderContainers_Sort"
Constants.SET_MANUALLY = "ReorderContainers_SetManually"

Constants.Commands = {
    SaveOrder = "SaveOrder",
}

Constants.Icons = {
    Locked = "media/ui/BetterContainers/locked.png",
    Unlocked = "media/ui/BetterContainers/unlocked.png",
    Sorting = "media/ui/BetterContainers/sorticon.png",
    Encumbrance = "media/ui/Moodles/32/Status_HeavyLoad.png",
}

Constants.Icons.Loaded = {
    Locked = getTexture(Constants.Icons.Locked),
    Unlocked = getTexture(Constants.Icons.Unlocked),
    Sorting = getTexture(Constants.Icons.Sorting),
    Encumbrance = getTexture(Constants.Icons.Encumbrance),
}

return Constants
