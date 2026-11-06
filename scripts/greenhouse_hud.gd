class_name GreenhouseHUD
extends CanvasLayer

signal pause_requested
signal capture_requested

@onready var gameplay: Control = $Root
@onready var crosshair: Label = %Crosshair
@onready var interaction_hint: Label = %InteractionHint
@onready var capture_button: Button = %CaptureButton


func show_target(available: bool) -> void:
	interaction_hint.visible = available


func set_captured(value: bool) -> void:
	capture_button.visible = not value
	crosshair.visible = value
	if not value:
		interaction_hint.hide()


func set_gameplay_visible(value: bool) -> void:
	gameplay.visible = value


func _on_pause_pressed() -> void:
	pause_requested.emit()


func _on_capture_button_down() -> void:
	capture_requested.emit()
