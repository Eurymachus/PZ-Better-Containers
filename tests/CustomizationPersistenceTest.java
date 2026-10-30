import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaThread;

// Run with the installed game's jar on the classpath, passing its install path.
class CustomizationPersistenceTest {
    public static void main(String[] args) throws Exception {
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
        thread.call(LuaCompiler.loadstring(Files.readString(Path.of(args[0], "stdlib.lua")), "stdlib", env), new Object[0]);
        var loaders = platform.newTable();
        var root = Path.of("Contents/mods/BetterContainers/42.21/media/lua");
        for (String path : new String[]{"shared/BetterContainers/Customize/ItemTarget.lua",
                "shared/BetterContainers/Customize/Network.lua", "shared/BetterContainers/Customize/ModData.lua",
                "server/BetterContainers/Customize/Server.lua", "client/BetterContainers/Customize/ItemSync.lua"}) {
            loaders.rawset(path, LuaCompiler.loadstring(Files.readString(root.resolve(path)), path, env));
        }
        env.rawset("testLoaders", loaders);
        String setup = "package={loaded={}}; function require(name) if not package.loaded[name] then "
            + "package.loaded[name]=testLoaders['shared/'..name..'.lua']() end return package.loaded[name] end "
            + "function dofile(path) return testLoaders[string.sub(path, string.len('Contents/mods/BetterContainers/42.21/media/lua/')+1)]() end ";
        thread.call(LuaCompiler.loadstring(setup, "setup", env), new Object[0]);
        String test = Files.readString(Path.of("tests/customization_persistence.lua"))
            .replace("package.path = root .. \"shared/?.lua;\" .. package.path", "");
        var result = thread.pcall(LuaCompiler.loadstring(test, "customization_persistence", env), new Object[0]);
        if (!Boolean.TRUE.equals(result[0])) throw new AssertionError(java.util.Arrays.toString(result));
        System.out.println("PASS: customization persistence harness on the installed game's Kahlua runtime");
    }
}
