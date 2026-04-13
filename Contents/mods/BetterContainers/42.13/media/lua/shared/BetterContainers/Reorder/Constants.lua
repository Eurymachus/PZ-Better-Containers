local Constants = {}

Constants.MODULEID = "BetterContainers"

Constants.SORT_KEY = "ReorderContainers_Sort"
Constants.SET_MANUALLY = "ReorderContainers_SetManually"

Constants.INV_LOCK = "ReorderContainers_InvLock"
Constants.LOOT_LOCK = "ReorderContainers_LootLock"
Constants.LOOT_SORT = "ReorderContainers_LootSort"

Constants.Commands = {
    SaveOrder = "SaveOrder",
    SetLock = "SetLock",
    SetSortLoot = "SetSortLoot",
}

Constants.Icons = {
    Locked = "media/ui/BetterContainers/Reorder/locked.png",
    Unlocked = "media/ui/BetterContainers/Reorder/unlocked.png",
    Sorting = "media/ui/BetterContainers/Reorder/sorticon.png",
}

Constants.Icons.Loaded = {
    Locked = getTexture(Constants.Icons.Locked),
    Unlocked = getTexture(Constants.Icons.Unlocked),
    Sorting = getTexture(Constants.Icons.Sorting),
}

return Constants
