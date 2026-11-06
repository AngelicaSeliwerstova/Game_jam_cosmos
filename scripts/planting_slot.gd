@tool
class_name PlantingSlot
extends StaticBody3D

@export_range(1, 6) var slot_number: int = 1
@export var show_plant: bool = false:
	set(value):
		show_plant = value
		if is_node_ready():
			$Visuals/PlantPlaceholder.visible = show_plant

@onready var selection_outline: MeshInstance3D = $Visuals/SelectionOutline


func _ready() -> void:
	$Visuals/PlantPlaceholder.visible = show_plant


func set_highlighted(value: bool) -> void:
	selection_outline.visible = value
