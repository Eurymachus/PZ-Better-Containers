import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaThread;

// Run from the workspace root with the installed game's jars on the classpath.
class RowCategoryIntegrationTest {
    public static void main(String[] args) throws Exception {
        var platform = J2SEPlatform.getInstance();
        var environment = platform.newTable();
        environment.rawset("_G", environment);
        se.krka.kahlua.stdlib.BaseLib.register(environment);
        se.krka.kahlua.stdlib.TableLib.register(platform, environment);
        se.krka.kahlua.stdlib.StringLib.register(platform, environment);
        se.krka.kahlua.stdlib.CoroutineLib.register(platform, environment);
        se.krka.kahlua.j2se.MathLib.register(platform, environment);
        var thread = new KahluaThread(platform, environment);
        thread.debugOwnerThread = Thread.currentThread();
        thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[0], "stdlib.lua")),
            "stdlib", environment), new Object[0]);
        var root = Path.of("Contents/mods/BetterContainers/42.21");
        var testRoot = Path.of("tests");
        int compiled = 0;
        try (var files = Files.walk(root.resolve("media/lua"))) {
            for (Path file : files.filter(p -> p.toString().endsWith(".lua")).toList()) {
                LuaCompiler.loadstring(Files.readString(file), file.toString(), environment);
                compiled++;
            }
        }
        environment.rawset("loadMod", LuaCompiler.loadstring(Files.readString(root.resolve(
            "media/lua/client/BetterContainers/Categorize/InventoryPaneRender.lua")), "InventoryPaneRender", environment));
        String renderer = Files.readString(root.resolve("media/lua/client/BetterContainers/Categorize/InventoryPaneRender.lua"));
        int drawStart = renderer.indexOf("if item:getJobDelta() > 0  then");
        String categoryDraw = renderer.substring(drawStart, renderer.indexOf("if self.selected ~= nil", drawStart));
        environment.rawset("loadCategoryDraw", LuaCompiler.loadstring(
            "return function(InventoryCategory, self, item, v) local count=1 local doDragged=false " +
            "local xoff,yoff,y,textDY=0,0,0,0 " + categoryDraw + " end", "categoryDraw", environment));
        Path cleanPane = Path.of(args[0]).resolve("../../workshop/content/108600/3437629766/mods/CleanUI/42.19/media/lua/client/ISUI/ISInventoryPane.lua").normalize();
        String cleanSource = Files.readString(cleanPane);
        int cleanSortStart = cleanSource.indexOf("    local searchMode =", cleanSource.indexOf("function ISInventoryPane:refreshContainer()"));
        int cleanSortEnd = cleanSource.indexOf("    -- Add the first item", cleanSortStart);
        environment.rawset("loadCleanSort", LuaCompiler.loadstring(
            "return function(self, CleanUI_itemMatchesNameSearch, CleanUI_itemMatchesCategorySearch) " +
            "local CleanUI_shouldSuppressEquippedItemsHeader=function() return true end\n" +
            cleanSource.substring(cleanSortStart, cleanSortEnd) + "\nend", "CleanUISort", environment));
        for (String host : new String[]{"Vanilla", "CleanUI"}) {
            String source = Files.readString(host.equals("Vanilla")
                ? Path.of(args[0], "media/lua/client/ISUI/ISInventoryPane.lua") : cleanPane);
            var matcher = java.util.regex.Pattern.compile(
                "ISInventoryPane.itemSortByCat(?:Inc|Desc) = function\\(a,b\\).*?\\nend", java.util.regex.Pattern.DOTALL).matcher(source);
            String comparators = "";
            int count = 0;
            while (matcher.find()) { comparators += matcher.group() + "\n"; count++; }
            if (count != 2) throw new AssertionError("Missing " + host + " comparators");
            environment.rawset("load" + host + "Comparators", LuaCompiler.loadstring(comparators, host + "Comparators", environment));
        }
        for (String name : new String[]{"PinnedItems", "EquippedAttachedSection"}) {
            environment.rawset("load" + name, LuaCompiler.loadstring(Files.readString(root.resolve(
                "media/lua/client/BetterContainers/Upgrades/" + name + ".lua")), name, environment));
        }
        var test = LuaCompiler.loadstring(Files.readString(testRoot.resolve(
            "row_category_integration.lua")), "row_category_integration", environment);
        var result = thread.pcall(test, new Object[0]);
        if (!Boolean.TRUE.equals(result[0])) {
            throw new AssertionError(java.util.Arrays.toString(result));
        }
        System.out.println("PASS row category integration");
        String[][] fixtures = {
            {"loadHelpers", "shared/BetterContainers/Helpers.lua", ""},
            {"loadSwitchSides", "client/BetterContainers/Upgrades/SwitchSides.lua", ""},
            {"loadCategoryStore", "client/BetterContainers/Categorize/CategoryStore.lua", ""},
            {"loadInventoryCategory", "client/BetterContainers/Categorize/InventoryCategory.lua", ""},
            {"loadCategoryFilters", "client/BetterContainers/Categorize/CategoryFilters.lua", "{module=CategoryFilters, entries=_buildCategoryEntries}"},
            {"loadSearchBar", "client/BetterContainers/Upgrades/SearchBar.lua", "{matches=_stackMatchesQuery}"},
            {"loadNested", "client/BetterContainers/Nested.lua", ""},
            {"loadCategorize", "client/BetterContainers/Categorize.lua", "{module=Categorize, blacklist=_bcIsDisplayCategoryBlacklisted, load=loadCategories, update=updateCategories}"},
            {"loadCategoryUI", "client/BetterContainers/Categorize/ui/CategoryManagerUI.lua", "{name=scriptItemName, hidden=isScriptItemHidden}"},
            {"loadContextMenu", "client/BetterContainers/Customize/ContextMenu.lua", "{text=_t}"},
            {"loadSmartDeposit", "client/BetterContainers/Proximity/Proximity_SmartDeposit.lua",
                "{module=ProximitySmartDeposit, type=getContainerType, fullType=getItemFullType, weight=getItemWeight, locked=isLockedForPlayer, room=hasRoomForPlannedItem, plan=getSmartDepositPlan}"}
        };
        for (String[] fixture : fixtures) {
            String source = Files.readString(root.resolve("media/lua/" + fixture[1]));
            if (!fixture[2].isEmpty()) {
                // Expose local functions only in the test copy, never in shipped Lua.
                source = source.substring(0, source.lastIndexOf("\nreturn ")) + "\nreturn " + fixture[2];
            }
            environment.rawset(fixture[0], LuaCompiler.loadstring(source, fixture[1], environment));
        }
        var categoryLoaders = platform.newTable();
        var categoryRoot = root.resolve("media/lua/client/BetterContainers/Categorize/Categories");
        try (var files = Files.walk(categoryRoot)) {
            for (Path file : files.filter(p -> p.toString().endsWith(".lua")).toList()) {
                String name = "BetterContainers/Categorize/Categories/" + categoryRoot.relativize(file)
                    .toString().replace('\\', '/').replaceAll("\\.lua$", "");
                categoryLoaders.rawset(name, LuaCompiler.loadstring(Files.readString(file), name, environment));
            }
        }
        environment.rawset("categoryLoaders", categoryLoaders);
        var cleanupTests = LuaCompiler.loadstring(Files.readString(testRoot.resolve(
            "direct_calls.lua")), "direct_calls", environment);
        result = thread.pcall(cleanupTests, new Object[0]);
        if (!Boolean.TRUE.equals(result[0])) throw new AssertionError(java.util.Arrays.toString(result));
        System.out.println("PASS direct calls and UI isolation; compiled " + compiled + " shipped Lua files");
    }
}
