local root = "Contents/mods/BetterContainers/42.21/media/lua/"
package.path = root .. "shared/?.lua;" .. package.path
package.loaded["BetterContainers/Helpers"] = {
    dlog = function() end,
    getModDataRoot = function(md, create)
        if create then md.BetterContainers = md.BetterContainers or {} end
        return md.BetterContainers
    end,
}
function instanceof(o, class) return o and o.class == class or (class == "InventoryItem" and o and o.class == "InventoryContainer") end
function isClient() return true end
function getTextOrNull() return nil end
local handlers = {}
Events = {
    OnClientCommand = {Add = function(fn) handlers.server = fn end},
    OnServerCommand = {Add = function(fn) handlers.client = fn end},
}
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end
local function list(values)
    return {size = function() return #values end, get = function(_, i) return values[i + 1] end}
end
local function container(items)
    local c = {getItems = function() return list(items) end,
        getContainingItem = function(self) return self.containing end,
        getVehiclePart = function(self) return self.part end,
        getParent = function(self) return self.parent end}
    for _, item in ipairs(items) do item.container = c end
    return c
end
local function bag(id)
    local b = {class = "InventoryContainer", md = {unrelated = "preserved"}, name = "Bag"}
    b.getID = function() return id end
    b.getModData = function(self) return self.md end
    b.getWorldItem = function(self) return self.world end
    b.getContainer = function(self) return self.container end
    b.getInventory = function(self) return self.inventory end
    b.getScriptItem = function() return {getDisplayName = function() return "Bag" end} end
    b.setName = function(self, name) self.name = name end
    b.setCustomName = function(self, custom) self.custom = custom end
    b.inventory = container({})
    b.inventory.containing = b
    return b
end
local function position(o)
    o.getX, o.getY, o.getZ = function() return 4 end, function() return 5 end, function() return 0 end
    o.flagForHotSave = function(self) self.dirty = true end
    return o
end
local function fixture(kind, nested)
    local item = bag(42)
    local outer = item
    if nested then
        outer = bag(41)
        outer.inventory = container({item})
        outer.inventory.containing = outer
    end
    local player = position({getUsername = function() return "Alice" end, getOnlineID = function() return 7 end})
    player.inventory = container({})
    player.getInventory = function(self) return self.inventory end
    local owner = position({})
    local square = position({})
    owner.getSquare = function() return square end
    if kind == "ground" then
        outer.world = owner
        owner.getItem = function() return outer end
        square.getWorldObjects = function() return list({owner}) end
    elseif kind == "vehicle" then
        local c = container({outer})
        local part = {getId = function() return "TruckBed" end, getVehicle = function() return owner end,
            getItemContainer = function() return c end}
        c.part = part
        owner.getId = function() return 12 end
        owner.getPartById = function(_, id) if id == "TruckBed" then return part end end
    elseif kind == "world" then
        local c = container({outer})
        c.parent = owner
        owner.getContainerCount = function() return 1 end
        owner.getContainerByIndex = function() return c end
        square.getObjects = function() return list({owner}) end
    else
        player.inventory = container({outer})
    end
    return {item = item, player = player, owner = owner, square = square}
end
local active
function getCell() return {getGridSquare = function(_, x, y, z)
    if x == 4 and y == 5 and z == 0 then return active.square end
end} end
function getVehicleById(id) if id == 12 then return active.owner end end
function getPlayerByOnlineID(id) if id == 7 then return active.player end end
local queue, reply
function sendClientCommand(player, module, command, args)
    queue[#queue + 1] = {module, command, copy(args)}
end
function sendServerCommand(module, command, args) reply = {module, command, copy(args)} end
local Network = require("BetterContainers/Customize/Network")
local Data = require("BetterContainers/Customize/ModData")
local Target = require("BetterContainers/Customize/ItemTarget")
dofile(root .. "server/BetterContainers/Customize/Server.lua")
dofile(root .. "client/BetterContainers/Customize/ItemSync.lua")
local payload = {name = "Tools", icon = {kind = "item", value = "Base.Hammer"}, color = {r = 0.2, g = 0.4, b = 0.6, a = 1}}
local cases = 0
for _, kind in ipairs({"ground", "vehicle", "world", "player"}) do
    for _, nested in ipairs({false, true}) do
        local client, server = fixture(kind, nested), fixture(kind, nested)
        queue, reply, active = {}, nil, client
        Network.applyPayload(client.player, client.item, payload, 0)
        assert(#queue == 1, "missing command: " .. kind)
        assert(Data.getGlobal(server.item, 0) == nil, "client and server must be independent")
        active = server
        handlers.server(queue[1][1], queue[1][2], server.player, queue[1][3])
        assert(reply, "server did not acknowledge " .. kind)
        assert(server.item.name == "Tools")
        if kind ~= "player" then assert(server.owner.dirty, "owner not marked for saving") end
        -- A fresh object loaded from server state must retain all customization.
        local reloaded = bag(42)
        reloaded.md = copy(server.item.md)
        local saved = Data.getEffective(reloaded, "Alice", 0)
        assert(saved.name == "Tools" and saved.icon.value == "Base.Hammer" and saved.color.g == 0.4)
        assert(reloaded.md.unrelated == "preserved")
        local observer = fixture(kind, nested)
        active = observer
        handlers.client(reply[1], reply[2], reply[3])
        assert(Data.getGlobal(observer.item, 0).name == "Tools")
        assert(observer.item.name == "Tools")
        -- Reset both overrides, as the UI does, and retain unrelated mod data.
        active, queue = client, {}
        Network.clearUser(client.player, client.item, 0)
        Network.clearGlobal(client.player, client.item, 0)
        active = server
        for _, request in ipairs(queue) do handlers.server(request[1], request[2], server.player, request[3]) end
        assert(Data.getEffective(server.item, "Alice", 0) == nil)
        assert(server.item.name == "Bag" and server.item.custom == false)
        assert(server.item.md.unrelated == "preserved")
        active = observer
        handlers.client(reply[1], reply[2], reply[3])
        assert(Data.getEffective(observer.item, "Alice", 0) == nil)
        cases = cases + 1
    end
end
active = fixture("vehicle", false)
local target = Target.describe(active.player, active.item)
active.player.getX = function() return 1000 end
assert(Target.resolve(target, active.player) == nil, "remote mutation allowed")
active.player.getX = function() return 4 end
target.itemId = 999
assert(Target.resolve(target, active.player) == nil, "wrong item matched")
target.partId = "Missing"
assert(Target.resolve(target, active.player) == nil)
assert(Target.resolve({kind = "ground", itemId = 42, x = "bad"}, active.player) == nil)
print("PASS: " .. cases .. " independent client/server apply, restore, broadcast and reset cases; invalid target checks")
