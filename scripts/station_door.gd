class_name StationDoor
extends Node3D

enum Mode { AUTOMATIC, MANUAL, AIRLOCK }
@export var mode: Mode = Mode.MANUAL
@export var opening_width: float = 1.8
@export var travel_time: float = 0.65
@export var close_delay: float = 1.0
@export var slide_clearance: float = 0.10

var openness: float = 0.0
var requested_open: bool = false
var _empty_time: float = 0.0
var _swing_direction: float = -1.0

@onready var guard: Area3D = $CloseGuard
@onready var sensor: Area3D = get_node_or_null("ApproachSensor")

func _ready() -> void:
	add_to_group("station_doors")
	_apply_pose()

func request_open(value: bool) -> void:
	requested_open = value
	if value:
		_empty_time = 0.0

func is_closed() -> bool:
	return openness < 0.001

func is_fully_open() -> bool:
	return openness > 0.999

func get_interaction_prompt() -> String:
	if mode != Mode.MANUAL:
		return ""
	return "E — закрыть дверь" if requested_open else "E — открыть дверь"

func interact(player: Node3D) -> void:
	if mode != Mode.MANUAL:
		return
	if not requested_open and is_closed():
		# Open away from the player, from either side of the doorway.
		_swing_direction = -1.0 if to_local(player.global_position).z < 0.0 else 1.0
	request_open(not requested_open)

func _physics_process(delta: float) -> void:
	if mode == Mode.AUTOMATIC:
		if sensor.has_overlapping_bodies():
			_empty_time = 0.0
			requested_open = true
		else:
			_empty_time += delta
			if _empty_time >= close_delay:
				requested_open = false
	# Never push or trap a player while closing, including during a lock cycle.
	if not requested_open and guard.has_overlapping_bodies():
		if mode == Mode.MANUAL:
			requested_open = true
		return
	var next := move_toward(openness, 1.0 if requested_open else 0.0, delta / travel_time)
	if mode == Mode.MANUAL and not is_equal_approx(next,openness) and _swing_would_hit_player(next):
		return
	openness = next
	_apply_pose()

func _swing_would_hit_player(next: float) -> bool:
	var leaf: AnimatableBody3D = $SwingLeaf
	var collider: CollisionShape3D = $SwingLeaf/Collision
	var future := Transform3D(Basis(Vector3.UP,_swing_direction*PI*0.5*next),leaf.position)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = global_transform * future * collider.transform
	query.collision_mask = 2
	query.margin = 0.04
	return not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _apply_pose() -> void:
	if mode == Mode.MANUAL:
		$SwingLeaf.rotation.y = _swing_direction * PI * 0.5 * openness
	else:
		var travel := (opening_width * 0.5 + slide_clearance) * openness
		$LeftLeaf.position.x = -opening_width * 0.25 - travel
		$RightLeaf.position.x = opening_width * 0.25 + travel
