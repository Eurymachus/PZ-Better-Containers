local EC = require("BetterContainers/Helpers")

local Customize = {}

Customize.install = function()
    if Customize._installed then return end
    Customize._installed = true
    local CustomizeInventoryPage = require("BetterContainers/Customize/Customize_ISInventoryPage")

    CustomizeInventoryPage.install()
end

return Customize