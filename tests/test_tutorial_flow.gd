extends SceneTree

const FlowScript := preload("res://addons/ponzool_tutorial_flow/tutorial_flow.gd")

var _failed := 0
var _service: CanvasLayer
var _test_save_path := "user://ponzool_tutorial_flow_test.cfg"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(_test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_save_path))
	_service = FlowScript.new()
	_service.storage_path = _test_save_path
	root.add_child(_service)
	await process_frame

	var catalog := _make_catalog()
	_check(_service.set_catalog(catalog).is_empty(), "valid catalog is accepted")
	await _test_session_history_and_pause()
	await _test_priority_queue_and_deduplication()
	await _test_global_state_round_trip()
	await _test_existing_pause_is_restored()
	_test_catalog_validation()
	await _test_saved_state_version_is_rejected()

	_service.queue_free()
	paused = false
	if FileAccess.file_exists(_test_save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_save_path))
	if _failed == 0:
		print("TESTS PASSED")
		quit(0)
	else:
		printerr("TESTS FAILED: %d" % _failed)
		quit(1)


func _test_session_history_and_pause() -> void:
	_check(_service.trigger(&"session"), "session tutorial is queued")
	await process_frame
	_check(_service.get_current_id() == &"session", "session tutorial starts")
	_check(paused, "tree pauses while tutorial is visible")
	_check(_service.dismiss_current(), "visible tutorial can be dismissed")
	await process_frame
	_check(not paused, "tree pause state is restored")
	_check(_service.has_seen(&"session"), "dismissed session tutorial is marked seen")
	_check(not _service.trigger(&"session"), "seen session tutorial does not queue again")


func _test_priority_queue_and_deduplication() -> void:
	_service.reset_all()
	_check(_service.trigger(&"session"), "first tutorial starts a sequence")
	await process_frame
	_check(_service.trigger(&"low"), "low priority tutorial queues")
	_check(_service.trigger(&"high"), "high priority tutorial queues")
	_check(not _service.trigger(&"high", {"force": true}), "force does not duplicate queued ID")
	_check(_service.get_queue_ids() == [&"high", &"low"], "queue is priority ordered with stable IDs")
	_service.dismiss_current()
	await process_frame
	_check(_service.get_current_id() == &"high", "high priority tutorial starts next")
	_check(paused, "pause is retained between paused tutorials")
	_service.dismiss_current()
	await process_frame
	_check(_service.get_current_id() == &"low", "remaining queued tutorial starts")
	_service.dismiss_current()
	await process_frame
	_check(not paused, "pause is restored after queue empties")


func _test_global_state_round_trip() -> void:
	_service.reset_all()
	_check(_service.mark_seen(&"global"), "global tutorial can be marked seen")
	var state: Dictionary = _service.export_state()
	_check(state.get("version") == 1, "export includes schema version")
	_check(state.get("seen", []).has("global"), "export includes global history")
	_service.reset(&"global")
	_check(not _service.has_seen(&"global"), "global history can be reset")
	_check(_service.import_state(state), "valid state imports")
	_check(_service.has_seen(&"global"), "import restores global history")
	_check(not _service.import_state({"version": 999, "seen": []}), "unknown state version is rejected")
	_check(not _service.import_state({"version": 1, "seen": [42]}), "invalid state IDs are rejected")


func _test_existing_pause_is_restored() -> void:
	paused = true
	_check(_service.trigger(&"global", {"force": true}), "forced global tutorial queues")
	await process_frame
	_check(paused, "existing pause remains while tutorial is visible")
	_service.dismiss_current()
	await process_frame
	_check(paused, "existing pause remains after tutorial closes")
	paused = false


func _test_catalog_validation() -> void:
	var invalid := PonzoolTutorialCatalog.new()
	var empty := PonzoolTutorial.new()
	var broken := PonzoolTutorial.new()
	broken.id = &"broken"
	var duplicate_a := _tutorial(&"duplicate", 0, PonzoolTutorial.Scope.SESSION)
	var duplicate_b := _tutorial(&"duplicate", 0, PonzoolTutorial.Scope.SESSION)
	invalid.tutorials = [empty, broken, duplicate_a, duplicate_b]
	var errors: PackedStringArray = _service.validate_catalog(invalid)
	_check(errors.size() >= 3, "catalog validation reports empty ID, empty pages, and duplicate ID")
	_service.set_catalog(invalid)
	_check(not _service.trigger(&"broken"), "structurally invalid tutorial is not triggerable")


func _test_saved_state_version_is_rejected() -> void:
	var incompatible_path := "user://ponzool_tutorial_flow_incompatible_test.cfg"
	var config := ConfigFile.new()
	config.set_value("tutorials", "version", 999)
	config.set_value("tutorials", "seen", ["global"])
	_check(config.save(incompatible_path) == OK, "incompatible state fixture is written")
	var isolated_service := FlowScript.new()
	isolated_service.storage_path = incompatible_path
	root.add_child(isolated_service)
	await process_frame
	isolated_service.set_catalog(_make_catalog())
	_check(not isolated_service.has_seen(&"global"), "unsupported saved-state version is ignored")
	isolated_service.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(incompatible_path))


func _make_catalog() -> PonzoolTutorialCatalog:
	var catalog := PonzoolTutorialCatalog.new()
	catalog.tutorials = [
		_tutorial(&"session", 0, PonzoolTutorial.Scope.SESSION),
		_tutorial(&"low", 0, PonzoolTutorial.Scope.ALWAYS),
		_tutorial(&"high", 100, PonzoolTutorial.Scope.ALWAYS),
		_tutorial(&"global", 10, PonzoolTutorial.Scope.GLOBAL),
	]
	return catalog


func _tutorial(id: StringName, priority: int, scope: PonzoolTutorial.Scope) -> PonzoolTutorial:
	var page := PonzoolTutorialPage.new()
	page.body = "Test page for %s" % id
	page.continue_label = "Close"
	var tutorial := PonzoolTutorial.new()
	tutorial.id = id
	tutorial.title = str(id).capitalize()
	tutorial.pages = [page]
	tutorial.priority = priority
	tutorial.scope = scope
	return tutorial


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		_failed += 1
		printerr("FAIL: %s" % label)
