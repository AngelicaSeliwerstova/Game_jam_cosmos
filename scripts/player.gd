class_name StationPlayer
extends CharacterBody3D

signal target_changed(target: Node)
signal inspection_requested(slot: PlantingSlot)

@export var walk_speed: float = 2.7
@export var sprint_speed: float = 5.2
@export var jump_speed: float = 4.8
@export var mouse_sensitivity: float = 0.0025

var controls_enabled: bool = false
var target: Node
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _view_yaw: float = 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay


func _ready() -> void:
	_view_yaw = rotation.y
	# Follow interpolated position but keep mouse look immediate.
	camera.set_as_top_level(true)
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	interaction_ray.set_as_top_level(true)
	interaction_ray.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	reset_physics_interpolation()
	_update_camera(true)


func _process(_delta: float) -> void:
	_update_camera()


func _physics_process(delta: float) -> void:
	rotation.y = _view_yaw
	if not controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		velocity = Vector3.ZERO
		_set_target(null)
		return

	var input_axis: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = global_basis * Vector3(input_axis.x, 0.0, input_axis.y)
	var speed: float = sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = jump_speed
	else:
		# Keep contact stable on floors and ramps; upward jump velocity is preserved.
		if is_on_floor():
			velocity.y = 0.0
		velocity.y -= gravity * delta
	move_and_slide()
	_update_target()


func look(screen_delta: Vector2) -> void:
	if not controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	_view_yaw = wrapf(_view_yaw - screen_delta.x * mouse_sensitivity, -PI, PI)
	head.rotation.x = clampf(head.rotation.x - screen_delta.y * mouse_sensitivity, -1.35, 1.35)


func teleport_to(at: Vector3, yaw: float = 0.0, pitch: float = 0.0) -> void:
	global_position = at
	_view_yaw = yaw
	rotation.y = yaw
	head.rotation.x = clampf(pitch, -1.35, 1.35)
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	_update_camera(true)


func _view_basis() -> Basis:
	return Basis.from_euler(Vector3(head.rotation.x, _view_yaw, 0.0))


func _update_camera(immediate: bool = false) -> void:
	var at: Vector3 = global_position if immediate else get_global_transform_interpolated().origin
	camera.global_transform = Transform3D(_view_basis(), at + Vector3.UP * head.position.y)


func set_controls_enabled(value: bool) -> void:
	controls_enabled = value
	if not value:
		velocity = Vector3.ZERO
		_set_target(null)


func interact() -> void:
	if not controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	# Recheck the nearest solid collider on E, so a cached target cannot bypass a wall.
	_update_target()
	if target is PlantingSlot:
		inspection_requested.emit(target)
	elif is_instance_valid(target) and target.has_method("interact"):
		target.interact(self)


func get_target_prompt() -> String:
	if target is PlantingSlot:
		return "E — осмотреть грядку"
	if is_instance_valid(target) and target.has_method("get_interaction_prompt"):
		return target.get_interaction_prompt()
	return ""


func _update_target() -> void:
	# Interaction uses the current physical position, independently of camera smoothing.
	interaction_ray.global_transform = Transform3D(_view_basis(), global_position + Vector3.UP * head.position.y)
	interaction_ray.force_raycast_update()
	var hit := interaction_ray.get_collider() as Node
	while hit != null:
		if hit is PlantingSlot or (hit.has_method("interact") and hit.has_method("get_interaction_prompt")):
			_set_target(hit)
			return
		hit = hit.get_parent()
	_set_target(null)


func _set_target(value: Node) -> void:
	if target == value:
		return
	if is_instance_valid(target) and target.has_method("set_highlighted"):
		target.set_highlighted(false)
	target = value
	if target != null and target.has_method("set_highlighted"):
		target.set_highlighted(true)
	target_changed.emit(target)
