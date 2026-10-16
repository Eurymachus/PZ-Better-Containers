local Reorder = require("BetterContainers/Reorder")
local Proximity = require("BetterContainers/Proximity")
local Nested = require("BetterContainers/Nested")
local Customize = require("BetterContainers/Customize")
local Categorize = require("BetterContainers/Categorize")
local Upgrades = require("BetterContainers/Upgrades")

Reorder.install()
Nested.install()
-- Discover BC nested buttons before proximity aggregates their contents.
Proximity.install()
Customize.install()
Categorize.install()
Upgrades.install()
