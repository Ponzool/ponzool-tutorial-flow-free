# API reference

Verified runtime: Godot 4.7.

## Setup

```gdscript
var errors := TutorialFlow.set_catalog(tutorial_catalog)
```

Registers a `PonzoolTutorialCatalog`. It returns validation messages for an absent Catalog, empty or duplicate IDs, missing pages, and pages without text or an image. Invalid definitions are warned; the first valid occurrence of an ID remains available.

```gdscript
TutorialFlow.set_popup_theme(custom_theme)
```

Applies a Godot `Theme` to the built-in popup and removes its default panel style override. Full scene replacement is not supported in this preview.

## Display

```gdscript
TutorialFlow.trigger("first_enemy_encounter")
TutorialFlow.trigger("first_enemy_encounter", {"force": true})
```

Returns `true` when queued. `force` ignores display history but never duplicates an ID already visible or queued.

```gdscript
TutorialFlow.dismiss_current()
TutorialFlow.skip_current()
TutorialFlow.get_current_id()
TutorialFlow.get_current_page_index()
TutorialFlow.get_queue_ids()
```

The current tutorial is marked seen when dismissed or skipped.

## History

```gdscript
TutorialFlow.has_seen("first_enemy_encounter")
TutorialFlow.mark_seen("first_enemy_encounter")
TutorialFlow.reset("first_enemy_encounter")
TutorialFlow.mark_unseen("first_enemy_encounter") # reset() alias
TutorialFlow.reset_all()
```

`GLOBAL` history is saved to `user://ponzool_tutorials.cfg`. `SESSION` history remains in memory. `ALWAYS` intentionally makes `has_seen()` return false.

## External save integration

```gdscript
save_data["tutorials"] = TutorialFlow.export_state()

var accepted := TutorialFlow.import_state(
    save_data.get("tutorials", {})
)
```

The exported Dictionary contains schema `version = 1` and GLOBAL IDs. Import rejects unknown versions, non-array history, and non-string IDs without changing the current state.

## Signals

```gdscript
signal tutorial_started(id: StringName)
signal tutorial_finished(id: StringName)
signal tutorial_skipped(id: StringName)
signal queue_emptied
```

`tutorial_finished` and `tutorial_skipped` are mutually exclusive for one display. `queue_emptied` fires when no queued tutorial remains.

## Pause contract

The popup processes while the tree is paused. When the first paused tutorial in a sequence starts, Ponzool captures `SceneTree.paused`. Consecutive paused tutorials retain the pause. The captured value is restored when the next tutorial does not pause or the queue becomes empty.

An external system changing `SceneTree.paused` during this ownership window is not coordinated; the captured start value still wins at restoration.
