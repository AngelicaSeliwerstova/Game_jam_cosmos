class_name GreenhouseHUD
extends CanvasLayer

signal pause_requested
signal capture_requested

@onready var gameplay: Control = $Root
@onready var crosshair: Label = %Crosshair
@onready var interaction_hint: Label = %InteractionHint
@onready var stats: Label = %Stats
@onready var capture_button: Button = %CaptureButton

var game_state

func _ready() -> void:
	game_state = get_node_or_null("/root/GameState")
	if game_state != null and not game_state.changed.is_connected(_refresh_stats):
		game_state.changed.connect(_refresh_stats)
	_refresh_stats()


func show_target(available: bool, prompt: String = "E — осмотреть грядку") -> void:
	interaction_hint.text = prompt
	interaction_hint.visible = available


func set_captured(value: bool) -> void:
	capture_button.visible = not value
	crosshair.visible = value
	if not value:
		interaction_hint.hide()


func set_gameplay_visible(value: bool) -> void:
	gameplay.visible = value


func _refresh_stats() -> void:
	if game_state == null:
		return
	stats.text = "День %d   ·   Вода %d   ·   Семена %d" % [game_state.day, game_state.water, game_state.seeds]


func _on_pause_pressed() -> void:
	pause_requested.emit()


func _on_capture_button_down() -> void:
	capture_requested.emit()
