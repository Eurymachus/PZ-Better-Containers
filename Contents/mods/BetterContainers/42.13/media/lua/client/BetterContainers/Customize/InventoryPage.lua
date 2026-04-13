local CustomizeInventoryPage = {}

CustomizeInventoryPage.install = function()
    local EC = require("BetterContainers/Helpers")
    local CC = require("BetterContainers/Customize/ContextMenu")
    local Customizer = require("BetterContainers/Customize/Customizer")
    local OPTS = require("BetterContainers/_Options")

    require "ISUI/ISInventoryPage"

    -- ---------------------------------------------------------
    -- Patch refreshBackpacks: vanilla overwrites button backgrounds here.
    -- Re-apply our customization after vanilla sets selected/unselected.
    -- ---------------------------------------------------------
    if not ISInventoryPage._bcCustomizePatchedRefreshBackpacks then
        ISInventoryPage._bcCustomizePatchedRefreshBackpacks = true

        local _old_refreshBackpacks = ISInventoryPage.refreshBackpacks
        function ISInventoryPage:refreshBackpacks()
            _old_refreshBackpacks(self)

            if not OPTS.enableCustomizer then return end

            -- Re-apply customization on ALL buttons after vanilla bg assignment.
            for _, btn in ipairs(self.backpacks or {}) do
                if btn and btn.inventory then
                    local parent = EC.getParent(btn.inventory)
                    local isCorpse = instanceof and instanceof(parent, "IsoDeadBody")
                    if parent and not isCorpse then
                        local isSelected = (self.selectedButton == btn)
                        Customizer.applyToButton(btn, self, parent, isSelected)
                    end
                end
            end
        end
    end

    -- ---------------------------------------------------------
    -- Patch right-click on container buttons to inject Customize menu
    -- ---------------------------------------------------------
    local _old_onBackpackRightMouseDown = ISInventoryPage.onBackpackRightMouseDown
    function ISInventoryPage:onBackpackRightMouseDown(x, y)
        _old_onBackpackRightMouseDown(self, x, y)

        if not OPTS.enableCustomizer then return end

        local page = self.parent and self.parent.parent or self.parent or self
        if not page then return end
        if page.onCharacter then return end

        for _, button in ipairs(page.backpacks) do
            if button and button.inventory then
                local parent = EC.getParent(button.inventory)
                local isCorpse = instanceof and instanceof(parent, "IsoDeadBody")
                if button.mouseOver and parent and not isCorpse then
                    ISInventoryPage.onBackpackClick(page, button)
                    CC.handleCustomiserOptions(page, button, parent)
                    break
                end
            end
        end
    end
end

return CustomizeInventoryPage