class_name DoorButton
extends StaticBody3D

@export var controller_path: NodePath
@export_enum("inner", "outer") var side: String = "inner"
@onready var controller: StationAirlock = get_node(controller_path)
@onready var status: Label3D = $Status
@onready var outline: MeshInstance3D = $Highlight

func _ready() -> void:
	$Title.text = "01 / СТАНЦИЯ" if side=="inner" else "02 / ЛУНА"

func get_interaction_prompt() -> String:
	var title := "внутренняя дверь шлюза" if side == "inner" else "наружная дверь на Луну"
	return "E — открыть: " + title

func interact(_player: Node3D) -> void:
	controller.request(StringName(side))

func set_highlighted(value: bool) -> void:
	outline.visible = value

func _process(_delta: float) -> void:
	var text := controller.get_status()
	if status.text != text:
		status.text = text
