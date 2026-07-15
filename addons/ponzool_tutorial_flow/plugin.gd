@tool
extends EditorPlugin

const AUTOLOAD_NAME := "TutorialFlow"
const AUTOLOAD_PATH := "res://addons/ponzool_tutorial_flow/tutorial_flow.gd"
const OWNERSHIP_SETTING := "ponzool_tutorial_flow/autoload_managed"


func _enable_plugin() -> void:
	if not ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
		ProjectSettings.set_setting(OWNERSHIP_SETTING, true)
		ProjectSettings.save()
	elif not _autoload_points_to_addon():
		ProjectSettings.set_setting(OWNERSHIP_SETTING, null)
		ProjectSettings.save()
		push_error(
			(
				"Ponzool Tutorial Flow cannot register its Autoload because '%s' already exists. "
				+ "Rename the existing Autoload or keep this plugin disabled."
			)
			% AUTOLOAD_NAME
		)


func _disable_plugin() -> void:
	var plugin_owns_autoload := bool(ProjectSettings.get_setting(OWNERSHIP_SETTING, false))
	if plugin_owns_autoload and _autoload_points_to_addon():
		remove_autoload_singleton(AUTOLOAD_NAME)
	ProjectSettings.set_setting(OWNERSHIP_SETTING, null)
	ProjectSettings.save()


func _autoload_points_to_addon() -> bool:
	var setting_name := "autoload/%s" % AUTOLOAD_NAME
	if not ProjectSettings.has_setting(setting_name):
		return false
	return str(ProjectSettings.get_setting(setting_name)).trim_prefix("*") == AUTOLOAD_PATH
