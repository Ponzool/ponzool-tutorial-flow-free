extends SceneTree

const FlowScript := preload("res://addons/ponzool_tutorial_flow/tutorial_flow.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow := FlowScript.new()
	flow.storage_path = "user://ponzool_package_smoke_test.cfg"
	root.add_child(flow)
	await process_frame

	var page := PonzoolTutorialPage.new()
	page.body = "Fresh project smoke test"
	var tutorial := PonzoolTutorial.new()
	tutorial.id = &"package_smoke_test"
	tutorial.pages = [page]
	var catalog := PonzoolTutorialCatalog.new()
	catalog.tutorials = [tutorial]

	if not flow.set_catalog(catalog).is_empty():
		printerr("PACKAGE SMOKE TEST FAILED: catalog rejected")
		quit(1)
		return
	if not flow.trigger(&"package_smoke_test", {"force": true}):
		printerr("PACKAGE SMOKE TEST FAILED: trigger rejected")
		quit(1)
		return
	await process_frame
	if flow.get_current_id() != &"package_smoke_test":
		printerr("PACKAGE SMOKE TEST FAILED: tutorial did not start")
		quit(1)
		return
	flow.dismiss_current()
	await process_frame
	print("PACKAGE SMOKE TEST PASSED")
	quit(0)
