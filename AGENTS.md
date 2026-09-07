# Project Notes for Codex Agents

This workspace is the source for Better Containers for Project Zomboid.

## Workspace

- Mod workspace: `E:\LocalProfiles\Eurymachus\GameData\Zomboid\Workshop\Better Containers`
- Primary editable mod content lives under `Contents/`.
- Mod versions currently live under `Contents/mods/BetterContainers/`.
- Current and only working mod version: `Contents/mods/BetterContainers/42.20/`.
- Make implementation changes only in `42.20/`. Treat all earlier version folders as read-only historical references unless the user explicitly requests otherwise.
- Treat this workspace as the normal place to make changes.

## Reference Paths

Use these local paths when tracing Lua behavior, mod dependencies, or Project Zomboid internals:

- Steam workshop mods: `C:\Games\Steam\steamapps\workshop\content\108600`
- Local workshop mods / style references: `C:\Users\refle\Zomboid\Workshop`
- Project Zomboid install: `C:\Games\Steam\steamapps\common\ProjectZomboid`
- Versioned decompiled Java root: `C:\Games\Steam\steamapps\common\ProjectZomboid\tgsrr_decompiled`
- Legacy decompiled Java reference: `C:\Games\Steam\steamapps\common\PZJava`

## Runtime Logs

Use these local logs when debugging live game behavior, Lua errors, load order, or mod interactions:

- Main Project Zomboid console log: `E:\LocalProfiles\Eurymachus\GameData\Zomboid\console.txt`
- Project Zomboid logs folder: `E:\LocalProfiles\Eurymachus\GameData\Zomboid\Logs`

Treat runtime logs as read-only diagnostic references unless the user explicitly asks to clean, archive, or modify them.

## Working Rules

- Do not edit files outside this mod workspace unless the user explicitly asks for that.
- Use external workshop, local workshop, Project Zomboid, and Java paths as read-only references by default.
- Preserve existing mod structure and Project Zomboid conventions.
- Never use Lua `next()`. Use `pairs()` or `ipairs()` iteration, including when checking whether a table is empty.
