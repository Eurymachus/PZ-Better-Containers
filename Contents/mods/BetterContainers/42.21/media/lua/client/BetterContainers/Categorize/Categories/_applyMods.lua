-- Generated: data-driven mod pack loader
-- This file contains ONLY mod-id -> category pack mapping + a small loader loop.

local MODPACKS = {
    {
        mods = { "AdditionalBooks2" },
        path = "additionalbooks2_items",
    },
    {
        mods = { "AAApoc" },
        path = "allamericanapocalypse_items",
    },
    {
        mods = { "AllSkillBooks" },
        path = "allskillbooks_items",
    },
    {
        mods = { "ammocraft", "ammocraftfirearms" },
        path = "ammocraft_items",
    },
    {
        mods = { "Brita", "Brita_2" },
        path = "arsenal-brita_items",
    },
    {
        mods = { "ATCGbyWulf" },
        path = "atcg_items",
    },
    {
        mods = { "ClothesBoxRedux" },
        path = "clothesbox_items",
    },
    {
        mods = { "2412050672" },
        path = "cornerstore_items",
    },
    {
        mods = { "Better Belts", "ScrapArmor(new version)", "ScrapGuns(new version)", "ScrapWeapons(new version)", "TheWorkshop(new version)" },
        path = "djvirus_items",
    },
    {
        mods = { "DLTS" },
        path = "dlts_items",
    },
    {
        mods = { "Pitstop", "PitstopLegacy", "TheWorkshop(new version)" },
        path = "dylans_items",
    },
    {
        mods = { "EasyPacking", "EasyPackingAmmo", "EasyPackingHC" },
        path = "easypacking_items",
    },
    {
        mods = { "eggonsAllDoorsAreYours" },
        path = "eggonsalldoors_items",
    },
    {
        mods = { "Fantasy Workshop VS" },
        path = "fantasy_workshop_items",
    },
    {
        mods = { "FRUsedCars" },
        path = "filibuster_items",
    },
    {
        mods = { "UndeadSuvivor" },
        path = "fluffy_items",
    },
    {
        mods = { "iMeds" },
        path = "immersivemedicine_items",
    },
    {
        mods = { "jiggasAddictionMod", "jiggasGreenfireMod" },
        path = "jiggasgreenfiremod_items",
    },
    {
        mods = { "TKCM" },
        path = "kcmcrossbow_items",
    },
    {
        mods = { "49powerWagon", "59meteor", "67commando", "69mini", "70barracuda", "70dodge", "74amgeneralM151A2", "78amgeneralM35A2", "80kz1000", "82jeepJ10", "82oshkoshM911", "83amgeneralM923", "84merc", "85merc", "86fordE150", "86oshkoshP19A", "87cruiser", "88chevyS10", "89def110", "89def90", "89fordBronco", "89trooper", "90fordF350ambulance", "90pierceArrow", "91range", "92amgeneralM998", "92fordCVPI", "92nissanGTR", "93fordElgin", "93townCar", "97bushmaster", "99fordCVPI", "ECTO1", "isoContainers" },
        path = "ki5_items",
    },
    {
        mods = { "LCFAV2" },
        path = "lastcall_items",
    },
    {
        mods = { "Literature&Magazines" },
        path = "literatureandmagazines_items",
    },
    {
        mods = { "LY_Skillbooks_agility", "LY_Skillbooks_firearms", "LY_Skillbooks_lockpicking", "LY_Skillbooks_melee", "LY_Skillbooks_passive" },
        path = "littleyoschisskillbooks_items",
    },
    {
        mods = { "MDXakiermachete", "MDXelgorcampaxe", "MDXragerbaseballbat", "Max" },
        path = "madax_items",
    },
    {
        mods = { "MoreBooks" },
        path = "morebooks_items",
    },
    {
        mods = { "MoreBrews", "MoreBrewsWineMeUp" },
        path = "morebrews_items",
    },
    {
        mods = { "MCMGreenfire", "MCMLitter", "MoreCigsMod" },
        path = "morecigsmod_items",
    },
    {
        mods = { "MoreMaps" },
        path = "moremaps_items",
    },
    {
        mods = { "MoreSkillBooks" },
        path = "moreskillbooks_items",
    },
    {
        mods = { "1521582441" },
        path = "mre_xiii_items",
    },
    {
        mods = { "newcontainers" },
        path = "newcontainers_items",
    },
    {
        mods = { "NukaColaCollection" },
        path = "nukacolacollection_items",
    },
    {
        mods = { "OccupationsExpertises" },
        path = "occupationsexpertises_items",
    },
    {
        mods = { "ForkMJdairy", "ForkMJfoodWild", "ForkMJjarMeat", "LockpickingOnly", "OGSN_Orphan_OrganizedStorage", "OGSN_Orphan_RodsStore", "TieOnSpearheads", "TieOnSpearheads_Crafting", "TieOnSpearheads_MP", "VFFogsn", "VFFogsn_herbsNoRot" },
        path = "ogsn_items",
    },
    {
        mods = { "ImprovisedCabinetry", "ImprovisedFlooring", "ImprovisedFlooringPlus", "ImprovisedGlass", "ImprovisedPaint" },
        path = "orcs_items",
    },
    {
        mods = { "PaintYourRide" },
        path = "paintyourride_items",
    },
    {
        mods = { "PantryPacking" },
        path = "pantrypacking_items",
    },
    {
        mods = { "ADVANCEDGEAR", "GearedZombies", "Keytool", "SlimJimLockoutTool" },
        path = "planetalgol_items",
    },
    {
        mods = { "PLLoot", "PLLootF", "PLLootG", "PLLoot_Patch" },
        path = "plloot_items",
    },
    {
        mods = { "Ramen" },
        path = "ramen_items",
    },
    {
        mods = { "RuggedRecipes" },
        path = "ruggedrecipes_items",
    },
    {
        mods = { "seifuku" },
        path = "schoolsout_items",
    },
    {
        mods = { "BRDM2", "CSPT", "CytSB", "ExpandedHelicopterEvents", "FJ75C", "IFAV", "SCKCO", "SLEO", "SMUI", "XM93" },
        path = "shark-cyts_items",
    },
    {
        mods = { "1537876121", "2207313208", "2211423190", "4ColorBicPen", "4ColorBicPenFix", "AAS", "AnaLGiNs_RenewableFoodResources", "AntiserumHC", "AntiserumHCSelfTestKit", "ArmoredVests", "AutoGate", "BCGRareWeapons", "BCGTools", "BedfordFalls", "BetterFlashlights", "BogaPizza", "CanRepairDoors", "Computer", "ComputerClassicsGamePack", "ComputerCorporalsGamePack", "ComputerGTAGamePack", "CoolBag", "CrashedCarsMod", "DBDA", "DRK_1", "Defecation", "DrivingSkill", "EliazFitnessStrengthBooks", "EssentialCrafting", "ExamineCorpses", "ExamineCorpsesPLUS", "FencingKits", "ForScience", "FuelAPI", "FunctionalChainsaw", "Helicopter", "ISA_41", "KACB", "KCMcrossbowCompatibility", "KMISCCB", "KMMCB", "LactoseCrossbow", "Ladders", "MANYBAGS", "MCM", "MattSimpleAddonsFriuts", "MilPoncho", "Onifurniture", "PSurvival", "PertsPartyTiles", "PlayerTraps", "PwSleepingbags", "RDC_Z777", "RS_WaterCistern", "RS_WaterCistern_FR_Overwrite", "RS_WaterCistern_KI5_Addon", "RadioToGrid", "SAPPHEATER", "SavottaBackpacks", "ScavengingSkill", "SecretZ", "SecretZ_v2", "SecretZ_v3", "Silencer", "SimplePowderedMilk", "SkillRecoveryJournal", "SlingMod", "SlingModFix", "SpecialEmergencyVehiclesFRsm", "TheyKnew", "ToadTraits", "ToadTraitsDisablePrepared", "ToadTraitsDisableSpec", "TowingCar", "VPR_RecyclingCenter", "VehicleRepairOverhaul", "WaterDispenser", "XnerTree", "ahzclothing", "antiserum", "antiserum_beta", "betterLockpicking", "eggonsFannyPackBalancing", "eggonsSharpenYourBlades", "icecreammaker", "nattachments", "rSemiTruck", "rWaterTrailer", "rWaterTrailerSemi", "smokinjoessmokes", "spraypaintEDIT", "tactorgsol", "ttr-CorpseStudy", "waterPipes", "zReBetterLockpicking" },
        path = "smallmod_items",
    },
    {
        mods = { "Smoker" },
        path = "smoker_items",
    },
    {
        mods = { "AliceSPack", "AmmoMaker", "BatesMetalicosRevived", "CustomMapBridge", "FuelTanksMod", "LeGourmetRevolution", "MilitaryComplex", "Riverside Gunstore", "SkillsMag", "SnakeClothingMod", "SnakeMansion", "SnakeUtilsPack", "TableSaw", "TallerMecanico", "WPA" },
        path = "snakesmodpack_items",
    },
    {
        mods = { "BeautifyingTime", "BuildingTime", "ClearingTime", "CookingTime", "DressingTime", "DrinkingTime", "ExploringTime", "FarmingTime", "ForagingTime", "FreezingTime", "LearningTime", "PhotographingTime", "RelaxingTime", "SoulFilchersBeautifyingTime", "SoulFilchersBuildingTime", "SoulFilchersClearingTime", "SoulFilchersCookingTime", "SoulFilchersDressingTime", "SoulFilchersDrinkingTime", "SoulFilchersExploringTime", "SoulFilchersFarmingTime", "SoulFilchersForagingTime", "SoulFilchersFreezingTime", "SoulFilchersLearningTime", "SoulFilchersPhotographingTime", "SoulFilchersRelaxingTime" },
        path = "soulfilchers_items",
    },
    {
        mods = { "SpnCloth", "SpnClothVanilla", "SpnOpenCloth" },
        path = "spongie_items",
    },
    {
        mods = { "Swatpack" },
        path = "swatpackredux_items",
    },
    {
        mods = { "SpiffoTrueMusic" },
        path = "truemusicaddonmod_items",
    },
    {
        mods = { "ATA_Bus", "ATA_Dadge", "ATA_Jeep", "ATA_Jeep_x10", "ATA_Jeep_x2", "ATA_Jeep_x4", "ATA_Luton", "ATA_Mustang", "ATA_Mustang_x2", "ATA_Mustang_x4", "ATA_Petyarbuilt", "ATA_Samara", "ATA_VanDeRumba", "AquatsarYachtClub", "TMC_Trolley", "TrueActionsDancing", "agrotsar", "amclub", "autotsartrailers", "truemusic", "tsarslib" },
        path = "tsarmods_items",
    },
    {
        mods = { "Cosplaywa" },
        path = "unknownclothingstore_items",
    },
    {
        mods = { "VDK" },
        path = "vacsdrinks_items",
    },
    {
        mods = { "VFExpansion1", "VFExpansion2" },
        path = "vfe_items",
    },
    {
        mods = { "VGC_Addon_GameBoyGames", "Video_Game_Consoles" },
        path = "videogameconsoles_items",
    },
    {
        mods = { "VileM113APC" },
        path = "vilem113apc_items",
    },
    {
        mods = { "DemoniusZombieVirusVaccine", "VaccinDrReapers", "VaccinDrReapersMP" },
        path = "zombievirusvaccine_items",
    },
}

return function(loadCategoryFile, dlog)
    local mods = getActivatedMods()
    local loaded = {}

    for i = 1, #MODPACKS do
        local rec = MODPACKS[i]
        local enable = false

        for j = 1, #rec.mods do
            if mods:contains(rec.mods[j]) then
                enable = true
                break
            end
        end

        if enable and not loaded[rec.path] then
            loaded[rec.path] = true
            loadCategoryFile("mods/" .. rec.path)
            if dlog then dlog('Loaded category pack ' .. rec.path) end
        end
    end
end