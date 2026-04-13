BetterContainers_Const = BetterContainers_Const or {}

BetterContainers_Const.MODULEID = "BetterContainers"

BetterContainers_Const.SORT_KEY = "ReorderContainers_Sort"
BetterContainers_Const.SET_MANUALLY = "ReorderContainers_SetManually"
-- For special containers that aren't "real"
BetterContainers_Const.SPECIAL_SORT_KEYS_BY_INV_TYPE = {
    ["floor"] = "ReorderContainers_Sort_Floor",

    -- SpiffUI
    ["SpiffBodies"] = "Reorder_SpiffBodies",
    ["SpiffContainer"] = "Reorder_SpiffContainer",
    ["SpiffPack"] = "Reorder_SpiffPack",
    ["SpiffEquip"] = "Reorder_SpiffEquip",

    -- Proximity Inventory
    ["proxInv"] = "ReorderContainers_Sort_proxInv",
    ["twistInv"] = "ReorderContainers_Sort_twistInv"
}

BetterContainers_Const.INV_LOCK = "ReorderContainers_InvLock"
BetterContainers_Const.LOOT_LOCK = "ReorderContainers_LootLock"
BetterContainers_Const.LOOT_SORT = "ReorderContainers_LootSort"

BetterContainers_Const.Commands = {
    SaveOrder = "SaveOrder",
    SetLock = "SetLock",
    SetSortLoot = "SetSortLoot",
}

BetterContainers_Const.Icons = {
    Locked = "media/ui/BetterContainers/locked.png",
    Unlocked = "media/ui/BetterContainers/unlocked.png",
    Sorting = "media/ui/BetterContainers/sorticon.png",
}

BetterContainers_Const.Icons.Loaded = {
    Locked = getTexture(BetterContainers_Const.Icons.Locked),
    Unlocked = getTexture(BetterContainers_Const.Icons.Unlocked),
    Sorting = getTexture(BetterContainers_Const.Icons.Sorting),
}

return BetterContainers_Const
