local Upgrades = {}

Upgrades.install = function()
    if Upgrades._installed then return end
    Upgrades._installed =  true
    local SearchBar = require("BetterContainers/Upgrades/SearchBar")
    local SwitchSides = require("BetterContainers/Upgrades/SwitchSides")
    local UtilityPanel = require("BetterContainers/Upgrades/UtilityPanel")
    local LockInventory = require("BetterContainers/Upgrades/LockInventory")
    local PinnedItems = require("BetterContainers/Upgrades/PinnedItems")
    local EquippedAttachedSection = require("BetterContainers/Upgrades/EquippedAttachedSection")
    local PreserveInventoryWindows = require("BetterContainers/Upgrades/PreserveInventoryWindows")

    EquippedAttachedSection.install()
    PreserveInventoryWindows.install()
    SearchBar.install()
    SwitchSides.install()
    UtilityPanel.install()
    LockInventory.install()
    PinnedItems.install()
end

return Upgrades
