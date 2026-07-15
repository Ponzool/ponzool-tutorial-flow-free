extends CanvasLayer

## Event-driven popup tutorial runtime.

signal tutorial_started(id: StringName)
signal tutorial_finished(id: StringName)
signal tutorial_skipped(id: StringName)
signal queue_emptied

const STATE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://ponzool_tutorials.cfg"

var storage_path := DEFAULT_SAVE_PATH

var _catalog: PonzoolTutorialCatalog
var _tutorials: Dictionary = {}
var _queue: Array[StringName] = []
var _current: PonzoolTutorial
var _current_page_index := 0
var _session_seen: Dictionary = {}
var _global_seen: Dictionary = {}
var _pause_owned := false
var _pause_state_before_sequence := false

var _overlay: Control
var _panel: PanelContainer
var _title_label: Label
var _page_label: Label
var _image_rect: TextureRect
var _body_label: RichTextLabel
var _previous_button: Button
var _next_button: Button
var _close_button: Button
var _skip_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_popup()
	_load_state()


func set_catalog(catalog: PonzoolTutorialCatalog) -> PackedStringArray:
	_catalog = catalog
	_tutorials.clear()
	var errors := validate_catalog(catalog)
	if catalog != null:
		for tutorial in catalog.tutorials:
			if _is_tutorial_runtime_valid(tutorial) and not _tutorials.has(tutorial.id):
				_tutorials[tutorial.id] = tutorial
	for error in errors:
		push_warning("Ponzool Tutorial Flow: %s" % error)
	return errors


func _is_tutorial_runtime_valid(tutorial: PonzoolTutorial) -> bool:
	if tutorial == null or tutorial.id.is_empty() or tutorial.pages.is_empty():
		return false
	for page in tutorial.pages:
		if page == null or (page.body.strip_edges().is_empty() and page.image == null):
			return false
	return true


func set_popup_theme(theme: Theme) -> void:
	_overlay.theme = theme
	if theme != null:
		_panel.remove_theme_stylebox_override("panel")


func validate_catalog(catalog: PonzoolTutorialCatalog = _catalog) -> PackedStringArray:
	var errors := PackedStringArray()
	if catalog == null:
		errors.append("Catalog is not set.")
		return errors
	var known_ids: Dictionary = {}
	for index in catalog.tutorials.size():
		var tutorial := catalog.tutorials[index]
		if tutorial == null:
			errors.append("Tutorial at index %d is empty." % index)
			continue
		if tutorial.id.is_empty():
			errors.append("Tutorial at index %d has an empty ID." % index)
		elif known_ids.has(tutorial.id):
			errors.append("Duplicate tutorial ID: %s" % tutorial.id)
		else:
			known_ids[tutorial.id] = true
		if tutorial.pages.is_empty():
			errors.append("Tutorial '%s' has no pages." % tutorial.id)
		for page_index in tutorial.pages.size():
			var page := tutorial.pages[page_index]
			if page == null:
				errors.append("Tutorial '%s' page %d is empty." % [tutorial.id, page_index + 1])
			elif page.body.strip_edges().is_empty() and page.image == null:
				errors.append("Tutorial '%s' page %d has no body or image." % [tutorial.id, page_index + 1])
	return errors


func trigger(id: StringName, options: Dictionary = {}) -> bool:
	if not _tutorials.has(id):
		push_warning("Ponzool Tutorial Flow: unknown tutorial ID '%s'." % id)
		return false
	if (_current != null and _current.id == id) or _queue.has(id):
		return false
	var force := bool(options.get("force", false))
	if not force and has_seen(id):
		return false
	_insert_by_priority(id)
	if _current == null:
		call_deferred("_show_next")
	return true


func has_seen(id: StringName) -> bool:
	var tutorial: PonzoolTutorial = _tutorials.get(id)
	if tutorial == null:
		return false
	match tutorial.scope:
		PonzoolTutorial.Scope.SESSION:
			return _session_seen.has(id)
		PonzoolTutorial.Scope.GLOBAL:
			return _global_seen.has(id)
		_:
			return false


func mark_seen(id: StringName) -> bool:
	var tutorial: PonzoolTutorial = _tutorials.get(id)
	if tutorial == null:
		return false
	match tutorial.scope:
		PonzoolTutorial.Scope.SESSION:
			_session_seen[id] = true
		PonzoolTutorial.Scope.GLOBAL:
			_global_seen[id] = true
			_save_state()
	return true


func reset(id: StringName) -> bool:
	var changed := _session_seen.erase(id)
	changed = _global_seen.erase(id) or changed
	if changed:
		_save_state()
	return changed


func mark_unseen(id: StringName) -> bool:
	return reset(id)


func reset_all() -> void:
	_session_seen.clear()
	_global_seen.clear()
	_save_state()


func export_state() -> Dictionary:
	return {
		"version": STATE_VERSION,
		"seen": _global_seen.keys().map(func(value: Variant) -> String: return str(value)),
	}


func import_state(state: Dictionary) -> bool:
	if state.get("version") != STATE_VERSION:
		push_warning("Ponzool Tutorial Flow: unsupported state version.")
		return false
	var seen: Variant = state.get("seen")
	if not seen is Array:
		push_warning("Ponzool Tutorial Flow: state 'seen' must be an Array.")
		return false
	var imported: Dictionary = {}
	for value in seen:
		if not value is String and not value is StringName:
			push_warning("Ponzool Tutorial Flow: state contains a non-string tutorial ID.")
			return false
		imported[StringName(value)] = true
	_global_seen = imported
	_save_state()
	return true


func get_current_id() -> StringName:
	return &"" if _current == null else _current.id


func get_current_page_index() -> int:
	return _current_page_index


func get_queue_ids() -> Array[StringName]:
	return _queue.duplicate()


func dismiss_current() -> bool:
	if _current == null:
		return false
	_finish_current(false)
	return true


func skip_current() -> bool:
	if _current == null:
		return false
	_finish_current(true)
	return true


func _insert_by_priority(id: StringName) -> void:
	var tutorial: PonzoolTutorial = _tutorials[id]
	for index in _queue.size():
		var queued: PonzoolTutorial = _tutorials.get(_queue[index])
		if queued != null and tutorial.priority > queued.priority:
			_queue.insert(index, id)
			return
	_queue.append(id)


func _show_next() -> void:
	if _current != null:
		return
	while not _queue.is_empty():
		var id := _queue.pop_front()
		var tutorial: PonzoolTutorial = _tutorials.get(id)
		if tutorial == null:
			continue
		_current = tutorial
		_current_page_index = 0
		if tutorial.pause_game:
			_acquire_pause()
		_refresh_popup()
		_overlay.show()
		tutorial_started.emit(tutorial.id)
		if _next_button.visible:
			_next_button.grab_focus()
		else:
			_close_button.grab_focus()
		return
	_release_pause()
	_overlay.hide()
	queue_emptied.emit()


func _finish_current(skipped: bool) -> void:
	var finished := _current
	if finished == null:
		return
	mark_seen(finished.id)
	_current = null
	_overlay.hide()
	if skipped:
		tutorial_skipped.emit(finished.id)
	else:
		tutorial_finished.emit(finished.id)
	var next: PonzoolTutorial
	if not _queue.is_empty():
		next = _tutorials.get(_queue.front())
	if next == null or not next.pause_game:
		_release_pause()
	if _queue.is_empty():
		queue_emptied.emit()
	else:
		call_deferred("_show_next")


func _acquire_pause() -> void:
	if _pause_owned:
		return
	_pause_state_before_sequence = get_tree().paused
	get_tree().paused = true
	_pause_owned = true


func _release_pause() -> void:
	if not _pause_owned:
		return
	get_tree().paused = _pause_state_before_sequence
	_pause_owned = false


func _load_state() -> void:
	if not FileAccess.file_exists(storage_path):
		return
	var config := ConfigFile.new()
	var error := config.load(storage_path)
	if error != OK:
		push_warning("Ponzool Tutorial Flow: could not load state (%s)." % error_string(error))
		return
	var version: Variant = config.get_value("tutorials", "version", null)
	if version != STATE_VERSION:
		push_warning("Ponzool Tutorial Flow: ignored saved state with unsupported version.")
		return
	var values: Variant = config.get_value("tutorials", "seen", [])
	if not values is Array:
		push_warning("Ponzool Tutorial Flow: ignored malformed saved state.")
		return
	for value in values:
		if value is String or value is StringName:
			_global_seen[StringName(value)] = true


func _save_state() -> void:
	var config := ConfigFile.new()
	config.set_value("tutorials", "version", STATE_VERSION)
	config.set_value("tutorials", "seen", export_state()["seen"])
	var error := config.save(storage_path)
	if error != OK:
		push_warning("Ponzool Tutorial Flow: could not save state (%s)." % error_string(error))


func _build_popup() -> void:
	_overlay = Control.new()
	_overlay.name = "TutorialOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.04, 0.09, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	_overlay.add_child(margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(640, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("15213d")
	panel_style.border_color = Color("4ecdc4")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 28
	panel_style.content_margin_top = 24
	panel_style.content_margin_right = 28
	panel_style.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	_panel.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	_title_label = Label.new()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 28)
	header.add_child(_title_label)
	_page_label = Label.new()
	_page_label.add_theme_color_override("font_color", Color("9fb3d9"))
	header.add_child(_page_label)

	_image_rect = TextureRect.new()
	_image_rect.custom_minimum_size = Vector2(0, 180)
	_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(_image_rect)

	_body_label = RichTextLabel.new()
	_body_label.custom_minimum_size = Vector2(0, 160)
	_body_label.fit_content = true
	_body_label.scroll_active = true
	_body_label.add_theme_font_size_override("normal_font_size", 20)
	content.add_child(_body_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	content.add_child(buttons)
	_skip_button = Button.new()
	_skip_button.text = "Skip"
	_skip_button.pressed.connect(skip_current)
	buttons.add_child(_skip_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	_previous_button = Button.new()
	_previous_button.text = "Previous"
	_previous_button.pressed.connect(_show_previous_page)
	buttons.add_child(_previous_button)
	_next_button = Button.new()
	_next_button.text = "Next"
	_next_button.pressed.connect(_show_next_page)
	buttons.add_child(_next_button)
	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.pressed.connect(dismiss_current)
	buttons.add_child(_close_button)
	_overlay.hide()


func _refresh_popup() -> void:
	if _current == null or _current.pages.is_empty():
		return
	var page := _current.pages[_current_page_index]
	_title_label.text = _current.title
	_page_label.text = "%d / %d" % [_current_page_index + 1, _current.pages.size()]
	_body_label.text = page.body
	_image_rect.texture = page.image
	_image_rect.visible = page.image != null
	_previous_button.disabled = _current_page_index == 0
	var is_last := _current_page_index == _current.pages.size() - 1
	_next_button.visible = not is_last
	_close_button.visible = is_last
	_skip_button.visible = _current.pages.size() > 1 and not is_last
	if not is_last:
		_next_button.text = page.continue_label if not page.continue_label.is_empty() else "Next"
	else:
		_close_button.text = page.continue_label if not page.continue_label.is_empty() else "Close"


func _show_previous_page() -> void:
	if _current == null or _current_page_index <= 0:
		return
	_current_page_index -= 1
	_refresh_popup()


func _show_next_page() -> void:
	if _current == null:
		return
	if _current_page_index >= _current.pages.size() - 1:
		dismiss_current()
		return
	_current_page_index += 1
	_refresh_popup()
	if _next_button.visible:
		_next_button.grab_focus()
	else:
		_close_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _current != null and event.is_action_pressed("ui_cancel"):
		dismiss_current()
		get_viewport().set_input_as_handled()
