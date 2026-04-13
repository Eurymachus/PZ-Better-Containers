-- Shipped presets (data-only).
--
-- Authoring format:
--   list = { Food = { nameKey=, cat=, sub=, payload={name,icon,color} }, ... }
--
-- Runtime format:
--   listArray[] = { id=, nameKey=, cat=, sub=, payload={name,icon,color} }
--   byId[id]    = preset
--
-- Menu grouping is generated on the fly by Customize/ContextMenu.lua.

local Presets = {}

local function C(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1 }
end

local function P(name, icon, color)
    -- Payload contract is strict (mirrors ModData): name/icon/color required.
    assert(name and icon and color, "Preset payload incomplete")
    return { name = name, icon = icon, color = color }
end

-- ---------------------------------------------------------
-- Meta (no duplication across presets)
-- ---------------------------------------------------------

Presets.Meta = {
    Categories = {
        Crafting   = { nameKey = "IGUI_BC_PresetCat_Crafting",   order = 10, icon = "Base.GardenSaw"  },
        Combat     = { nameKey = "IGUI_BC_PresetCat_Combat",   order = 20, icon = "Base.HuntingKnife"  },
        Equipment  = { nameKey = "IGUI_BC_PresetCat_Equipment",   order = 30, icon = "Base.Bag_ALICEpack"  },
        Survival   = { nameKey = "IGUI_BC_PresetCat_Survival", order = 40, icon = "Base.Base.TentBlue" },
        Storage    = { nameKey = "IGUI_BC_PresetCat_Storage",   order = 50, icon = "Base.Bag_BigHikingBag"  },
    },

    Subs = {
        -- Crafting
        Materials  = { nameKey = "IGUI_BC_PresetSub_Materials", order = 10, icon = "Base.LargePlank" },
        Skills     = { nameKey = "IGUI_BC_PresetSub_Skills", order = 20, icon = "Base.NutsBolts" },

        -- Combat
        Melee      = { nameKey = "IGUI_BC_PresetSub_Melee", order = 10, icon = "Base.HuntingKnife" },
        Ranged     = { nameKey = "IGUI_BC_PresetSub_Ranged", order = 20, icon = "Base.AssaultRifle" },
    },
}

-- ---------------------------------------------------------
-- Presets (keyed authoring)
-- ---------------------------------------------------------

Presets.List = {
    -- Survival
    Books = { nameKey = "IGUI_BC_Preset_Books",
        payload = P("Books", "Base.Book", C(0.45, 0.30, 0.20, 1)) },

    Cooking = { nameKey = "IGUI_BC_Preset_Cooking", cat = "Survival",
        payload = P("Cooking", "Base.PotForged", C(0.75, 0.20, 0.20, 1)) },

    Drinks = { nameKey = "IGUI_BC_Preset_Drinks", cat = "Survival",
        payload = P("Drinks", "Base.PopBottle", C(0.20, 0.45, 0.70, 1)) },

    Food = { nameKey = "IGUI_BC_Preset_Food",  cat = "Survival",
        payload = P("Food",  "Base.Pizza", C(0.25, 0.55, 0.25, 1)) },

    FirstAid = { nameKey = "IGUI_BC_Preset_FirstAid", cat = "Survival",
        payload = P("First Aid", "Base.Bandage", C(0.75, 0.20, 0.20, 1)) },

    Fishing = { nameKey = "IGUI_BC_Preset_Fishing", cat = "Survival",
        payload = P("Fishing", "Base.FishingHook_Forged", C(0.75, 0.20, 0.20, 1)) },

    -- Combat - Ranged
    Ammo = { nameKey = "IGUI_BC_Preset_Ammo", cat = "Combat", sub = "Ranged",
        payload = P("Ammo", "Base.Bullets9mm", C(0.55, 0.50, 0.20, 1)) },

    Guns = { nameKey = "IGUI_BC_Preset_Guns", cat = "Combat", sub = "Ranged",
        payload = P("Guns", "Base.DoubleBarrelShotgun", C(0.55, 0.50, 0.20, 1)) },

    -- Combat - Melee
    Blades = { nameKey = "IGUI_BC_Preset_Blades", cat = "Combat", sub = "Melee",
        payload = P("Blades", "Base.MacheteForged", C(0.35, 0.35, 0.35, 1)) },

    Blunts = { nameKey = "IGUI_BC_Preset_Blunts", cat = "Combat", sub = "Melee",
        payload = P("Blunts", "Base.ShortBat", C(0.35, 0.35, 0.35, 1)) },

    -- Equipment
    Clothing = { nameKey = "IGUI_BC_Preset_Clothing", cat = "Equipment",
        payload = P("Clothing", "Base.Tshirt_DefaultTEXTURE", C(0.55, 0.35, 0.60, 1)) },
        
    Armor = { nameKey = "IGUI_BC_Preset_Armor", cat = "Equipment",
        payload = P("Armor", "Base.Hat_RiotHelmet", C(0.55, 0.35, 0.60, 1)) },

    Bags = { nameKey = "IGUI_BC_Preset_Bags", cat = "Equipment",
        payload = P("Bags", "Base.Bag_WeaponBag", C(0.35, 0.35, 0.35, 1)) },

    -- Crafting / Tools
    Tools = { nameKey = "IGUI_BC_Preset_Tools", cat = "Crafting",
        payload = P("Tools", "Base.Hammer", C(0.30, 0.55, 0.55, 1)) },

    -- Crafting / Materials
    Materials = { nameKey = "IGUI_BC_Preset_Materials", cat = "Crafting",
        payload = P("Materials", "Base.NailsBox", C(0.50, 0.45, 0.35, 1)) },

    -- Crafting / Skills
    Electronics = { nameKey = "IGUI_BC_Preset_Electronics", cat = "Crafting", sub = "Skills",
        payload = P("Electronics", "Base.ElectronicsScrap", C(0.25, 0.50, 0.65, 1)) },

    Mechanics = { nameKey = "IGUI_BC_Preset_Mechanics", cat = "Crafting", sub = "Skills",
        payload = P("Mechanics", "Base.Wrench", C(0.35, 0.45, 0.55, 1)) },

    Blacksmithing = { nameKey = "IGUI_BC_Preset_Blacksmithing", cat = "Crafting", sub = "Skills",
        payload = P("Metalworking", "Base.BlacksmithAnvil", C(0.45, 0.45, 0.50, 1)) },

    Tailoring = { nameKey = "IGUI_BC_Preset_Tailoring", cat = "Crafting", sub = "Skills",
        payload = P("Tailoring", "Base.Needle", C(0.60, 0.45, 0.55, 1)) },

    -- Unclassified

    Junk = { nameKey = "IGUI_BC_Preset_Junk",
        payload = P("Junk", "Base.Bag_TrashBag", C(0.45, 0.40, 0.30, 1)) },

    Furniture = { nameKey = "IGUI_BC_Preset_Furniture",
        payload = P("Furniture", "Base.Mov_FancyLowTable", C(0.45, 0.40, 0.30, 1)) },
}

-- ---------------------------------------------------------
-- Normalize to stable array + byId lookup
-- ---------------------------------------------------------

Presets.listArray = {}
Presets.byId = {}

local ids = {}
for id, _ in pairs(Presets.List) do
    ids[#ids + 1] = id
end
table.sort(ids, function(a, b) return tostring(a) < tostring(b) end)

for _, id in ipairs(ids) do
    local p = Presets.List[id]
    if p then
        p.id = p.id or id
        Presets.listArray[#Presets.listArray + 1] = p
        Presets.byId[p.id] = p
    end
end

return Presets