class_name PauseMenu
extends CanvasLayer

signal opened
signal resumed(from_click: bool)

@onready var overlay: Control = $Overlay
@onready var resume_button: Button = %ResumeButton


func _unhandled_input(event: InputEvent) -> void:
	if overlay.visible and event.is_action_pressed("pause") and not event.is_echo():
		_resume(false)
		get_viewport().set_input_as_handled()


func open() -> void:
	overlay.show()
	get_tree().paused = true
	opened.emit()
	resume_button.grab_focus()


func _resume(from_click: bool) -> void:
	overlay.hide()
	get_tree().paused = false
	resumed.emit(from_click)


func _on_resume_pressed() -> void:
	_resume(true)


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
