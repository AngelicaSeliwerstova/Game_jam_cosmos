class_name StationAirlock
extends Node3D

@export var inner_door_path: NodePath
@export var outer_door_path: NodePath
var pending_side: StringName = &""
var _open_age: float = 0.0

@onready var inner_door: StationDoor = get_node(inner_door_path)
@onready var outer_door: StationDoor = get_node(outer_door_path)

func request(side: StringName) -> void:
	if side != &"inner" and side != &"outer":
		return
	pending_side = side
	_open_age = 0.0

func get_status() -> String:
	if pending_side == &"":
		return "ГОТОВ · ДВЕРИ ЗАКРЫТЫ" if inner_door.is_closed() and outer_door.is_closed() else "ДВЕРИ ЗАКРЫВАЮТСЯ"
	var other := outer_door if pending_side == &"inner" else inner_door
	if not other.is_closed():
		return "ЗАКРЫВАЕТСЯ ВТОРАЯ ДВЕРЬ\nНЕ СТОЙТЕ В ПРОЁМЕ"
	return "ВХОД НА СТАНЦИЮ" if pending_side == &"inner" else "ВЫХОД НА ЛУНУ"

func _physics_process(delta: float) -> void:
	# The other gate must be completely closed, not just ordered to close.
	if pending_side == &"inner":
		outer_door.request_open(false)
		inner_door.request_open(outer_door.is_closed())
	elif pending_side == &"outer":
		inner_door.request_open(false)
		outer_door.request_open(inner_door.is_closed())
	else:
		inner_door.request_open(false)
		outer_door.request_open(false)
	if pending_side != &"":
		var wanted := inner_door if pending_side == &"inner" else outer_door
		if wanted.is_fully_open() and not wanted.guard.has_overlapping_bodies():
			_open_age += delta
			if _open_age > 4.0:
				pending_side = &""
		else:
			_open_age = 0.0
