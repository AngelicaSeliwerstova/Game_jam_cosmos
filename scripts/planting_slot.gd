@tool
class_name PlantingSlot
extends Interactable
## A planting bed. Its mutable state lives in GameState; this node only mirrors it.

@export_range(1, 6) var slot_number: int = 1
@export var show_plant: bool = false:
	set(value):
		show_plant = value
		if is_node_ready() and Engine.is_editor_hint():
			_apply_preview()

@onready var selection_outline: MeshInstance3D = $Visuals/SelectionOutline
@onready var sprout: Node3D = $Visuals/Plants/Sprout
@onready var young: Node3D = $Visuals/Plants/Young
@onready var adult: Node3D = $Visuals/Plants/Adult

var game_state


func _ready() -> void:
	if Engine.is_editor_hint():
		_apply_preview()
		return
	game_state = get_node_or_null("/root/GameState")
	if game_state != null and not game_state.changed.is_connected(_refresh):
		game_state.changed.connect(_refresh)
	_refresh()


func get_interaction_hint() -> String:
	return "E — осмотреть грядку"


func _apply_preview() -> void:
	_show_stage(2 if show_plant else -1)


func _refresh() -> void:
	var plot: PlotState = game_state.get_plot(slot_number - 1) if game_state != null else null
	_show_stage(plot.growth if plot != null and plot.planted else -1)


func _show_stage(stage: int) -> void:
	sprout.visible = stage == 0
	young.visible = stage == 1
	adult.visible = stage >= 2
