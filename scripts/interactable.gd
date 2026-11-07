class_name Interactable
extends StaticBody3D
## Minimal shared base for objects the player can aim at and use with E.

@export var interaction_hint: String = "E — взаимодействовать"


func get_interaction_hint() -> String:
	return interaction_hint


func set_highlighted(value: bool) -> void:
	var outline: MeshInstance3D = get_node_or_null("Visuals/SelectionOutline") as MeshInstance3D
	if outline != null:
		outline.visible = value
