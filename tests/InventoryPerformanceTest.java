import java.nio.file.*;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.*;

// Standalone Kahlua fixture. No game saves or installed files are modified.
class InventoryPerformanceTest {
    public static void main(String[] args) throws Exception {
        Path game = Path.of(args[0]);
        Path root = Path.of("Contents/mods/BetterContainers/42.21");
        Path testRoot = Path.of("tests");
        var platform = J2SEPlatform.getInstance();
        var env = platform.newTable();
        env.rawset("_G", env);
        se.krka.kahlua.stdlib.BaseLib.register(env);
        se.krka.kahlua.stdlib.TableLib.register(platform, env);
        se.krka.kahlua.stdlib.StringLib.register(platform, env);
        se.krka.kahlua.stdlib.CoroutineLib.register(platform, env);
        se.krka.kahlua.j2se.MathLib.register(platform, env);
        var thread = new KahluaThread(platform, env);
        thread.debugOwnerThread = Thread.currentThread();
        thread.call(LuaCompiler.loadstring(Files.readString(game.resolve("stdlib.lua")), "stdlib", env), new Object[0]);
        env.rawset("milliseconds", (JavaFunction)(frame, n) -> {
            frame.push(System.nanoTime() / 1000000.0); return 1;
        });
        env.rawset("print", (JavaFunction)(frame, n) -> {
            System.out.println(frame.get(0)); return 0;
        });
        String vanilla = Files.readString(game.resolve("media/lua/client/ISUI/ISInventoryPane.lua"));
        String refresh = vanilla.substring(vanilla.indexOf("function ISInventoryPane:refreshContainer()"), vanilla.indexOf("ISInventoryPane.highlightItem = nil;"));
        String render = vanilla.substring(vanilla.indexOf("function ISInventoryPane:renderdetails(doDragged)"), vanilla.indexOf("function ISInventoryPane:isLiteratureRead"));
        env.rawset("loadVanilla", LuaCompiler.loadstring("local normalTextColor={r=.7,g=.7,b=.7,a=1} local unwantedTextColor=normalTextColor\n" + refresh + render, "vanilla", env));
        env.rawset("loadRightClick", LuaCompiler.loadstring(vanilla.substring(vanilla.indexOf("function ISInventoryPane:onRightMouseUp(x, y)"), vanilla.indexOf("function ISInventoryPane:onMouseDown(x, y)")), "rightClick", env));
        String context = Files.readString(game.resolve("media/lua/client/ISUI/ISInventoryPaneContextMenu.lua"));
        env.rawset("loadCraftingSubmenu", LuaCompiler.loadstring(context.substring(context.indexOf("ISInventoryPaneContextMenu.addNewCraftingDynamicalContextMenu = function"), context.indexOf("ISInventoryPaneContextMenu.addToolTip = function")), "craftingSubmenu", env));
        env.rawset("loadContextContainers", LuaCompiler.loadstring(context.substring(context.indexOf("ISInventoryPaneContextMenu.getContainers = function"), context.indexOf("ISInventoryPaneContextMenu.addFixerSubOption = function")), "contextContainers", env));
        env.rawset("loadActualItems", LuaCompiler.loadstring(vanilla.substring(vanilla.indexOf("function ISInventoryPane.getActualItems(items)"), vanilla.indexOf("function ISInventoryPane.getActualUniqueItems(items)")), "actualItems", env));
        for (String name : new String[]{"Categorize/InventoryPaneRender", "Upgrades/FoodFreshness"}) {
            env.rawset(name.contains("Food") ? "loadFreshness" : "loadCategories", LuaCompiler.loadstring(Files.readString(root.resolve("media/lua/client/BetterContainers/" + name + ".lua")), name, env));
        }
        env.rawset("loadProbe", LuaCompiler.loadstring(Files.readString(testRoot.resolve("live_inventory_probe.lua")), "probe", env));
        if (args.length > 1 && args[1].equals("category")) {
            env.rawset("loadComparators", LuaCompiler.loadstring(vanilla.substring(vanilla.indexOf("ISInventoryPane.itemSortByNameInc ="), vanilla.indexOf("function ISInventoryPane:sortByName")), "comparators", env));
            for (String name : new String[]{"InventoryCategory", "CategoryStore"}) {
                env.rawset("load" + name, LuaCompiler.loadstring(Files.readString(root.resolve("media/lua/client/BetterContainers/Categorize/" + name + ".lua")), name, env));
            }
            String setup = Files.readString(testRoot.resolve("inventory_performance.lua"));
            setup = setup.substring(0, setup.indexOf("for _, variant in ipairs"));
            var benchmark = thread.pcall(LuaCompiler.loadstring(setup + Files.readString(testRoot.resolve("category_sort_benchmark.lua")), "categoryBenchmark", env), new Object[0]);
            if (!Boolean.TRUE.equals(benchmark[0])) throw new AssertionError(java.util.Arrays.toString(benchmark));
            return;
        }
        var result = thread.pcall(LuaCompiler.loadstring(Files.readString(testRoot.resolve("inventory_performance.lua")), "fixture", env), new Object[0]);
        if (!Boolean.TRUE.equals(result[0])) throw new AssertionError(java.util.Arrays.toString(result));
        for (String name : new String[]{"Proximity", "Proximity/Proximity_ISInventoryPage", "Reorder/Reorder_ISInventoryPage"}) {
            env.rawset("load_" + name.replace('/', '_'), LuaCompiler.loadstring(Files.readString(root.resolve("media/lua/client/BetterContainers/" + name + ".lua")), name, env));
        }
        env.rawset("loadSortData", LuaCompiler.loadstring(Files.readString(root.resolve("media/lua/shared/BetterContainers/Reorder/ModData.lua")), "sortData", env));
        String controls = Files.readString(root.resolve("media/lua/client/BetterContainers/Proximity/Proximity_ISLootWindowContainerControls.lua"));
        env.rawset("loadDropVisibility", LuaCompiler.loadstring("return function(Proximity, BlacklistCompat) local MoveToFloor={}\n" + controls.substring(controls.indexOf("local function canMoveItemToFloor"), controls.indexOf("function MoveToFloor:perform()")) + "\nreturn MoveToFloor.shouldBeVisible end", "dropVisibility", env));
        env.rawset("loadProximityControls", LuaCompiler.loadstring(controls, "proximityControls", env));
        String page = Files.readString(game.resolve("media/lua/client/ISUI/ISInventoryPage.lua"));
        env.rawset("loadWheel", LuaCompiler.loadstring(page.substring(page.indexOf("function ISInventoryPage:onMouseWheel(del)"), page.indexOf("ISInventoryPage.dirtyUI = function")), "wheel", env));
        String sides = Files.readString(root.resolve("media/lua/client/BetterContainers/Upgrades/SwitchSides.lua"));
        env.rawset("loadSidesWheel", LuaCompiler.loadstring(sides.substring(sides.indexOf("local _old_onMouseWheel ="), sides.indexOf("ISInventoryPage._BetterContainers_SwitchSides_installed = true")), "sidesWheel", env));
        result = thread.pcall(LuaCompiler.loadstring(Files.readString(testRoot.resolve("proximity_lifecycle.lua")), "proximity_lifecycle", env), new Object[0]);
        if (!Boolean.TRUE.equals(result[0])) throw new AssertionError(java.util.Arrays.toString(result));
    }
}
