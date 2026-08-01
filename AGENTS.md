# Project Notes for Codex Agents

This workspace is the source for Better Containers for Project Zomboid.

## Workspace

- Mod workspace: `E:\LocalProfiles\Eurymachus\GameData\Zomboid\Workshop\Better Containers`
- Primary editable mod content lives under `Contents/`.
- Mod versions currently live under `Contents/mods/BetterContainers/`.
- Current working mod version: `Contents/mods/BetterContainers/42.19/`.
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

- Prefer `rg` for searches across Lua, Java references, `mod.info`, media scripts, recipes, translations, and workshop dependencies.
- When investigating behavior, search in this order unless the task suggests otherwise:
  1. Better Containers workspace.
  2. Relevant version folders under `Contents/mods/BetterContainers/`.
  3. Local workshop mods under `C:\Users\refle\Zomboid\Workshop` when code style or established Eurymachus patterns matter.
  4. Steam workshop mods when checking compatibility or comparable mod behavior.
  5. Project Zomboid game files.
  6. The matching authoritative versioned Java decompile under `ProjectZomboid\tgsrr_decompiled`.
  7. Legacy decompiled Java references in `PZJava` when legacy comparison is useful.
- Do not edit files outside this mod workspace unless the user explicitly asks for that.
- Use external workshop, local workshop, Project Zomboid, and Java paths as read-only references by default.
- Preserve existing mod structure and Project Zomboid conventions.
- Keep edits focused and avoid unrelated refactors.
