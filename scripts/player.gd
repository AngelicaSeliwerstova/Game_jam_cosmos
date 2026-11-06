class_name StationPlayer
extends CharacterBody3D

signal target_changed(slot: PlantingSlot)
signal inspection_requested(slot: PlantingSlot)

@export var walk_speed: float = 2.7
@export var mouse_sensitivity: float = 0.0025

var controls_enabled: bool = false
var target: PlantingSlot
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay


func _physics_process(delta: float) -> void:
	if not controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		velocity = Vector3.ZERO
		_set_target(null)
		return

	var input_axis: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = global_basis * Vector3(input_axis.x, 0.0, input_axis.y)
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	_update_target()


func look(screen_delta: Vector2) -> void:
	if not controls_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	rotate_y(-screen_delta.x * mouse_sensitivity)
	head.rotation.x = clampf(head.rotation.x - screen_delta.y * mouse_sensitivity, -1.35, 1.35)


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
	if target != null:
		inspection_requested.emit(target)


func _update_target() -> void:
	interaction_ray.force_raycast_update()
	_set_target(interaction_ray.get_collider() as PlantingSlot)


func _set_target(value: PlantingSlot) -> void:
	if target == value:
		return
	if is_instance_valid(target):
		target.set_highlighted(false)
	target = value
	if target != null:
		target.set_highlighted(true)
	target_changed.emit(target)
