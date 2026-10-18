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
        environment.rawset("loadMod", LuaCompiler.loadstring(Files.readString(root.resolve(
            "media/lua/client/BetterContainers/Categorize/InventoryPaneRender.lua")), "InventoryPaneRender", environment));
        var test = LuaCompiler.loadstring(Files.readString(root.resolve(
            "tests/row_category_integration.lua")), "row_category_integration", environment);
        var result = thread.pcall(test, new Object[0]);
        if (!Boolean.TRUE.equals(result[0])) {
            throw new AssertionError(java.util.Arrays.toString(result));
        }
        System.out.println("PASS row category integration");
    }
}
