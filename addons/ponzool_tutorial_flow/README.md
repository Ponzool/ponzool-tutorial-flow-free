# Ponzool Tutorial Flow

This folder is the installable Godot addon.

1. Keep it at `res://addons/ponzool_tutorial_flow/`.
2. Enable **Ponzool Tutorial Flow** in Project Settings → Plugins.
3. Create a `PonzoolTutorialCatalog` and call `TutorialFlow.set_catalog(catalog)`.
4. Trigger a registered ID with `TutorialFlow.trigger("tutorial_id")`.

The complete guide and demo are available in the source repository. Version 0.1.0 has been verified with Godot 4.7.

For non-blocking objectives, live UI and world markers, and real-action completion, see [Ponzool Tutorial Flow Pro](https://ponzool.itch.io/ponzool-tutorial-flow-pro).

License: [MIT](LICENSE), Copyright (c) 2026 PONZOOL.
