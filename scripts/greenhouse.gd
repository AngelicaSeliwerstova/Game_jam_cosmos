extends Control

@onready var world_viewport: SubViewport = $WorldViewport
@onready var image: TextureRect = $Image
@onready var player: StationPlayer = $WorldViewport/World/Player
@onready var hud: GreenhouseHUD = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var inspection: InspectionPanel = $InspectionPanel


func _ready() -> void:
	get_tree().paused = false
	image.texture = world_viewport.get_texture()
	resized.connect(_fit_image)
	_fit_image()
	player.target_changed.connect(_on_target_changed)
	player.inspection_requested.connect(_open_inspection)
	get_window().focus_exited.connect(_on_focus_exited)
	if OS.has_feature("web"):
		_release_mouse()
	else:
		_capture_mouse()


func _process(_delta: float) -> void:
	if inspection.is_open():
		return
	# Pointer lock may be released by the browser itself. Never reacquire it here:
	# a new click must be the source of the next capture request.
	var captured: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	player.set_controls_enabled(captured)
	hud.set_captured(captured)


func _fit_image() -> void:
	# Fit the live 3D texture without cropping or changing its 16:9 proportions.
	var render_size := Vector2(world_viewport.size)
	var image_scale: float = minf(size.x / render_size.x, size.y / render_size.y)
	image.size = render_size * image_scale
	image.position = (size - image.size) * 0.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if inspection.is_open():
			inspection.close(false)
		else:
			pause_menu.open()
		get_viewport().set_input_as_handled()
		return
	if inspection.is_open():
		if event.is_action_pressed("interact") and not event.is_echo():
			inspection.close(false)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			if image.get_global_rect().has_point(click.position):
				_capture_mouse()
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		player.look((event as InputEventMouseMotion).screen_relative)
	elif event.is_action_pressed("interact") and not event.is_echo():
		player.interact()
		get_viewport().set_input_as_handled()


func _capture_mouse() -> void:
	if get_tree().paused or inspection.is_open():
		return
	# Called synchronously by button_down / mouse input on Web (pointer lock).
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.set_captured(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	player.set_controls_enabled(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)


func _release_mouse() -> void:
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_captured(false)


func _on_target_changed(slot: PlantingSlot) -> void:
	hud.show_target(slot != null)


func _open_inspection(slot: PlantingSlot) -> void:
	_release_mouse()
	hud.set_gameplay_visible(false)
	inspection.open(slot.slot_number)


func _on_inspection_closed(from_click: bool) -> void:
	hud.set_gameplay_visible(true)
	_resume_controls(from_click)


func _on_pause_opened() -> void:
	_release_mouse()
	hud.set_gameplay_visible(false)


func _on_resumed(from_click: bool) -> void:
	hud.set_gameplay_visible(true)
	_resume_controls(from_click)


func _resume_controls(from_click: bool) -> void:
	if from_click or not OS.has_feature("web"):
		_capture_mouse()
	else:
		_release_mouse()


func _on_focus_exited() -> void:
	if not get_tree().paused and not inspection.is_open():
		pause_menu.open()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
