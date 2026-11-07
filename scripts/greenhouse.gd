extends Control

const SLEEP_FADE_SECONDS: float = 0.35

@onready var world_viewport: SubViewport = $WorldViewport
@onready var image: TextureRect = $Image
@onready var player: StationPlayer = $WorldViewport/World/Player
@onready var hud: GreenhouseHUD = $HUD
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var inspection: InspectionPanel = $InspectionPanel
@onready var sleep_panel: SleepPanel = $SleepPanel
@onready var sleep_fade: ColorRect = $SleepFade/Fade

var _sleeping: bool = false
var game_state


func _ready() -> void:
	game_state = get_node_or_null("/root/GameState")
	get_tree().paused = false
	image.texture = world_viewport.get_texture()
	resized.connect(_fit_image)
	_fit_image()
	player.target_changed.connect(_on_target_changed)
	player.inspection_requested.connect(_on_interaction_requested)
	sleep_panel.confirmed.connect(_start_sleep)
	sleep_panel.closed.connect(_on_sleep_closed)
	get_window().focus_exited.connect(_on_focus_exited)
	if OS.has_feature("web"):
		_release_mouse()
	else:
		_capture_mouse()


func _process(_delta: float) -> void:
	if _sleeping or inspection.is_open() or sleep_panel.is_open():
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
	if _sleeping:
		get_viewport().set_input_as_handled()
		return
	if sleep_panel.is_open():
		if event.is_action_pressed("pause") and not event.is_echo():
			sleep_panel.close(false)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact") and not event.is_echo():
			if sleep_panel.is_confirming():
				sleep_panel.confirm()
			else:
				sleep_panel.close(false)
			get_viewport().set_input_as_handled()
		return
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
	if get_tree().paused or _sleeping or inspection.is_open() or sleep_panel.is_open():
		return
	# Called synchronously by button_down / mouse input on Web (pointer lock).
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.set_captured(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	player.set_controls_enabled(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)


func _release_mouse() -> void:
	player.set_controls_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_captured(false)


func _on_target_changed(target: Interactable) -> void:
	hud.show_target(target)


func _on_interaction_requested(target: Interactable) -> void:
	if target is StationBed:
		_open_sleep()
	elif target is PlantingSlot:
		_open_inspection(target as PlantingSlot)


func _open_inspection(slot: PlantingSlot) -> void:
	if _sleeping:
		return
	_release_mouse()
	hud.set_gameplay_visible(false)
	inspection.open(slot.slot_number)


func _on_inspection_closed(from_click: bool) -> void:
	hud.set_gameplay_visible(true)
	_resume_controls(from_click)


func _open_sleep() -> void:
	if _sleeping:
		return
	_release_mouse()
	hud.set_gameplay_visible(false)
	sleep_panel.open_confirmation(game_state.day)


func _start_sleep() -> void:
	if _sleeping:
		return
	_sleeping = true
	_release_mouse()
	hud.set_gameplay_visible(false)
	sleep_fade.color.a = 0.0

	var tween: Tween = create_tween()
	tween.tween_property(sleep_fade, "color:a", 1.0, SLEEP_FADE_SECONDS)
	await tween.finished
	if not is_inside_tree():
		return

	# Exactly one night is resolved for this confirmed sleep.
	var report: Dictionary = game_state.sleep()

	var fade_in: Tween = create_tween()
	fade_in.tween_property(sleep_fade, "color:a", 0.0, SLEEP_FADE_SECONDS)
	await fade_in.finished
	_sleeping = false
	sleep_panel.show_report(game_state.day, report)


func _on_sleep_closed(from_click: bool) -> void:
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
	if not get_tree().paused and not _sleeping and not inspection.is_open() and not sleep_panel.is_open():
		pause_menu.open()


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
