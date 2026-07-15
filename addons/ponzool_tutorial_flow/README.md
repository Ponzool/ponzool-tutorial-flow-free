# Ponzool Tutorial Flow

This folder is the installable Godot addon.

1. Keep it at `res://addons/ponzool_tutorial_flow/`.
2. Enable **Ponzool Tutorial Flow** in Project Settings → Plugins.
3. Create a `PonzoolTutorialCatalog` and call `TutorialFlow.set_catalog(catalog)`.
4. Trigger a registered ID with `TutorialFlow.trigger("tutorial_id")`.

The complete guide and demo are available in the source repository. This development preview has only been verified with Godot 4.7.

License status: **not selected**. Do not redistribute this preview until the repository contains an approved `LICENSE` or `LICENSE.md` with a copyright holder.
