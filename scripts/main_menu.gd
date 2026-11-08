extends Control

@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton

var game_state


func _ready() -> void:
	game_state = get_node_or_null("/root/GameState")
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	quit_button.visible = not OS.has_feature("web")
	start_button.grab_focus()


func _on_start_pressed() -> void:
	if game_state != null:
		game_state.reset()
	get_tree().change_scene_to_file("res://scenes/greenhouse/greenhouse.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
