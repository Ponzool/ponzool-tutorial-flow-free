class_name PonzoolTutorial
extends Resource

enum Scope {
	ALWAYS,
	SESSION,
	GLOBAL,
}

@export var id: StringName
@export var title := "Tutorial"
@export var pages: Array[PonzoolTutorialPage] = []
@export var pause_game := true
@export var scope: Scope = Scope.SESSION
@export_range(-1000, 1000, 1) var priority := 0
