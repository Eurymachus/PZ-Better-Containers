local Target = {}

-- Describe the outer owner, retaining the customized bag's stable item ID.
function Target.describe(player, item)
    local target = { itemId = item:getID() }
    local outer = item
    for depth = 1, 16 do
        local world = outer:getWorldItem()
        if world and world:getSquare() then
            local square = world:getSquare()
            target.kind = "ground"
            target.x, target.y, target.z = square:getX(), square:getY(), square:getZ()
            return target
        end
        local container = outer:getContainer()
        if not container then return nil end
        local containing = container:getContainingItem()
        if containing then
            outer = containing
        else
            if container == player:getInventory() then
                target.kind = "player"
                target.playerId = player:getOnlineID()
                return target
            end
            local part = container:getVehiclePart()
            if part then
                local vehicle = part:getVehicle()
                if not vehicle then return nil end
                target.kind, target.vehicleId, target.partId = "vehicle", vehicle:getId(), part:getId()
                return target
            end
            local parent = container:getParent()
            local square = parent and parent:getSquare()
            if not square then return nil end
            target.kind = "world"
            target.x, target.y, target.z = square:getX(), square:getY(), square:getZ()
            return target
        end
    end
end

local function find(container, id, depth)
    if not container or depth > 16 then return nil end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:getID() == id then return item end
        if instanceof(item, "InventoryContainer") then
            local found = find(item:getInventory(), id, depth + 1)
            if found then return found end
        end
    end
end

local function nearby(player, object)
    return object and math.abs(player:getX() - object:getX()) <= 10
        and math.abs(player:getY() - object:getY()) <= 10
        and math.abs(player:getZ() - object:getZ()) < 2
end

-- On the server, only resolve the sender's inventory or nearby loaded owners.
function Target.resolve(target, player)
    if type(target) ~= "table" or type(target.itemId) ~= "number" then return nil end
    if target.kind == "player" then
        local owner = player or getPlayerByOnlineID(target.playerId)
        if not owner then return nil end
        return find(owner:getInventory(), target.itemId, 1)
    end
    if target.kind == "vehicle" then
        if type(target.vehicleId) ~= "number" or type(target.partId) ~= "string" then return nil end
        local vehicle = getVehicleById(target.vehicleId)
        if not vehicle or (player and not nearby(player, vehicle)) then return nil end
        local part = vehicle:getPartById(target.partId)
        return find(part and part:getItemContainer(), target.itemId, 1), vehicle
    end
    if target.kind ~= "ground" and target.kind ~= "world" then return nil end
    if type(target.x) ~= "number" or type(target.y) ~= "number" or type(target.z) ~= "number" then return nil end
    local square = getCell():getGridSquare(target.x, target.y, target.z)
    if not square or (player and not nearby(player, square)) then return nil end
    local objects = target.kind == "ground" and square:getWorldObjects() or square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if target.kind == "ground" then
            local item = object:getItem()
            if item then
                if item:getID() == target.itemId then return item, object end
                if instanceof(item, "InventoryContainer") then
                    local found = find(item:getInventory(), target.itemId, 1)
                    if found then return found, object end
                end
            end
        else
            for index = 0, object:getContainerCount() - 1 do
                local found = find(object:getContainerByIndex(index), target.itemId, 1)
                if found then return found, object end
            end
        end
    end
end

return Target
