class_name InspectionPanel
extends CanvasLayer

signal closed(from_click: bool)

@onready var overlay: Control = $Overlay
@onready var title: Label = %Title
@onready var close_button: Button = %CloseButton


func open(slot_number: int) -> void:
	title.text = "Грядка № %d" % slot_number
	overlay.show()
	close_button.grab_focus()


func is_open() -> bool:
	return overlay.visible


func close(from_click: bool = false) -> void:
	overlay.hide()
	closed.emit(from_click)


func _on_close_button_down() -> void:
	close(true)
