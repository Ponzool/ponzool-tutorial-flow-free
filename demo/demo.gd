extends Control

@export var catalog: PonzoolTutorialCatalog

@onready var event_log: RichTextLabel = %EventLog
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var errors := TutorialFlow.set_catalog(catalog)
	TutorialFlow.tutorial_started.connect(_on_tutorial_started)
	TutorialFlow.tutorial_finished.connect(_on_tutorial_finished)
	TutorialFlow.tutorial_skipped.connect(_on_tutorial_skipped)
	TutorialFlow.queue_emptied.connect(_on_queue_emptied)
	if errors.is_empty():
		_log_event("Catalog ready — choose a demo event.")
	else:
		_log_event("Catalog has %d error(s)." % errors.size())

	var arguments := OS.get_cmdline_user_args()
	if arguments.has("--auto-demo"):
		call_deferred("_run_auto_demo")
	elif arguments.has("--capture-store-media"):
		call_deferred("_capture_store_media")


func _on_enemy_pressed() -> void:
	_request(&"first_enemy_encounter")


func _on_item_pressed() -> void:
	_request(&"first_item_pickup")


func _on_queue_pressed() -> void:
	_request(&"first_item_pickup", true)
	_request(&"inventory_unlocked", true)


func _on_reset_pressed() -> void:
	TutorialFlow.reset_all()
	status_label.text = "History reset"
	_log_event("Display history was reset.")


func _request(id: StringName, force := false) -> void:
	var accepted := TutorialFlow.trigger(id, {"force": force})
	status_label.text = "%s: %s" % [id, "queued" if accepted else "ignored"]
	_log_event("trigger(\"%s\") → %s" % [id, accepted])


func _on_tutorial_started(id: StringName) -> void:
	status_label.text = "Showing: %s" % id
	_log_event("Started %s; game tree paused = %s" % [id, get_tree().paused])


func _on_tutorial_finished(id: StringName) -> void:
	_log_event("Finished %s" % id)


func _on_tutorial_skipped(id: StringName) -> void:
	_log_event("Skipped %s" % id)


func _on_queue_emptied() -> void:
	status_label.text = "Ready"
	_log_event("Queue empty; game tree paused = %s" % get_tree().paused)


func _log_event(message: String) -> void:
	event_log.append_text("• %s\n" % message)
	event_log.scroll_to_line(event_log.get_line_count())


func _run_auto_demo() -> void:
	TutorialFlow.reset_all()
	_request(&"first_enemy_encounter")
	await get_tree().process_frame
	if TutorialFlow.get_current_id() != &"first_enemy_encounter":
		_fail_auto_demo("enemy tutorial did not start")
		return
	TutorialFlow.skip_current()
	await get_tree().process_frame
	_on_queue_pressed()
	await get_tree().process_frame
	if TutorialFlow.get_current_id() != &"first_item_pickup":
		_fail_auto_demo("priority queue did not start item tutorial first")
		return
	TutorialFlow.dismiss_current()
	await get_tree().process_frame
	if TutorialFlow.get_current_id() != &"inventory_unlocked":
		_fail_auto_demo("inventory tutorial did not follow item tutorial")
		return
	TutorialFlow.dismiss_current()
	await get_tree().process_frame
	print("DEMO PASSED")
	get_tree().quit(0)


func _fail_auto_demo(reason: String) -> void:
	printerr("DEMO FAILED: %s" % reason)
	get_tree().paused = false
	get_tree().quit(1)


func _capture_store_media() -> void:
	TutorialFlow.reset_all()
	_request(&"first_enemy_encounter", true)
	for frame in 3:
		await get_tree().process_frame
	if not _save_viewport_capture("ponzool-tutorial-flow-demo.webp"):
		get_tree().quit(1)
		return
	TutorialFlow.skip_current()
	await get_tree().process_frame
	_on_queue_pressed()
	for frame in 2:
		await get_tree().process_frame
	if not _save_viewport_capture("ponzool-tutorial-flow-queue.webp"):
		get_tree().quit(1)
		return
	TutorialFlow.dismiss_current()
	await get_tree().process_frame
	TutorialFlow.dismiss_current()
	for frame in 2:
		await get_tree().process_frame
	if not _save_viewport_capture("ponzool-tutorial-flow-overview.webp"):
		get_tree().quit(1)
		return
	print("MEDIA CAPTURE COMPLETE")
	get_tree().quit(0)


func _save_viewport_capture(filename: String) -> bool:
	var texture := get_viewport().get_texture()
	var image: Image
	if texture != null:
		image = texture.get_image()
	if image == null or image.is_empty() or image.get_width() < 1280 or image.get_height() < 720:
		printerr("MEDIA CAPTURE FAILED: viewport image is unavailable or too small")
		return false
	var directory := ProjectSettings.globalize_path("res://docs/store-listings/media")
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join(filename)
	var error := image.save_webp(path, true, 0.82)
	if error != OK:
		printerr("MEDIA CAPTURE FAILED: %s" % error_string(error))
		return false
	print("MEDIA CAPTURED: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	return true
