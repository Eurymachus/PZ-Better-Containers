return {

    -- Alcohol
    FoodA = {
        "Base.Beer*",
        "Base.Wine*",
        "Base.Whiskey*",
    },

    -- Beverages / liquids
    FoodB = {
        -- Generic drinks
        "Base.Pop*",
        "Base.JuiceBox",
        "Base.Coffee",
        "Base.HotDrink*",
        "Base.ColdDrink*",

        -- Water containers
        "Base.Water*",
        "Base.BeerWaterFull",
        "Base.WineWaterFull",
        "Base.WhiskeyWaterFull",

        -- Containers with water
        "Base.BucketWaterFull",
        "Base.FullKettle",
        "Base.Mug*",
        "Base.Teabag*",
        "Base.WaterTeacup",

        -- Farming liquids
        "farming.*WaterFull",
    },

    -- Non-perishable food
    FoodN = {
        -- Canned (closed)
        "Base.Canned*",
        "Base.Tinned*",
        "Base.TunaTin*",
        "Base.Dogfood*",

        -- Dry staples
        "Base.Rice",
        "Base.Pasta",
        "Base.OatsRaw",
        "Base.Cereal",
        "Base.Macandcheese",
        "Base.Ramen",

        -- Snacks & sweets
        "Base.Crisps*",
        "Base.Candy*",
        "Base.Chocolate*",
        "Base.CookiesSugar",
        "Base.Popcorn",
        "Base.Gum",
        "Base.Marshmallows",
        "Base.Pretzel",
        "Base.GranolaBar",

        -- Preserved proteins
        "Base.BeefJerky",
        "Base.DehydratedMeat*",
        "Base.PeanutButter",
        "Base.Peanut*",

        -- Seeds / nuts / herbs
        "Base.SunflowerSeeds",
        "Base.Allsorts",
        "Base.Basil",
        "Base.Chives",
        "Base.Cilantro",
        "Base.Parsley",
        "Base.Rosemary",
        "Base.Sage",
        "Base.Thyme",
        "Base.Oregano",

        -- Bugs (non-perishable)
        "Base.*Caterpillar",
        "Base.*Centipede*",
        "Base.*Millipede*",
        "Base.Pillbug",
        "Base.Termites",
        "Base.Snail",
        "Base.Slug*",
        "Base.Worm",
        "Base.Cockroach",
        "Base.Cricket",
        "Base.Grasshopper",
    },

    -- Perishable food
    FoodP = {
        -- Canned (open)
        "Base.Canned*Open",
        "Base.Tinned*Open",
        "Base.TunaTin*Open",
        "Base.Dogfood*Open",
        -- Fresh produce
        "Base.Apple",
        "Base.Banana",
        "Base.Orange",
        "Base.Pear",
        "Base.Peaches",
        "Base.Grapes",
        "Base.Berry*",
        "Base.Mushroom*",
        "Base.Lettuce",
        "Base.Onion",
        "Base.Potato",
        "Base.Tomato",
        "Base.Zucchini",
        "Base.Broccoli",
        "Base.Cabbage",
        "Base.Carrot*",
        "Base.Leek",
        "Base.Corn",
        "Base.Pepper*",
        "Base.Pumpkin",
        "Base.Watermelon*",

        -- Meat & fish
        "Base.*meat",
        "Base.*Meat",
        "Base.Fish*",
        "Base.Salmon",
        "Base.Trout",
        "Base.Pike",
        "Base.Perch",
        "Base.Bass",
        "Base.Catfish",
        "Base.Crappie",

        -- Dairy & eggs
        "Base.Milk",
        "Base.Cheese*",
        "Base.Egg*",
        "Base.Yoghurt",

        -- Bread & dough
        "Base.Bread*",
        "Base.Dough*",
        "Base.Bagel*",
        "Base.Baguette*",

        -- Cooked meals / prepared food
        "Base.Burger*",
        "Base.Pizza",
        "Base.Sandwich*",
        "Base.Soup*",
        "Base.Stew*",
        "Base.Pasta*",
        "Base.Rice*",
        "Base.Cake*",
        "Base.Cookie*",
        "Base.Muffin*",
        "Base.Pancakes*",
        "Base.Pie*",
        "Base.Taco*",
        "Base.Burrito*",
        "Base.Sushi*",
        "Base.Onigiri",
        "Base.Springroll",
        "Base.Dumpling*",

        -- Farming perishables
        "farming.*",
    },

}
