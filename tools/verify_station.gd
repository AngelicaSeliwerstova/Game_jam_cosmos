extends SceneTree
## Integration checks against the saved scene and Godot's real physics space.
## Run graphically: pointer capture and input checks require a real display.

var failures := 0
var checks := 0
var scene: Control
var player: StationPlayer
var world: Node3D
var space: PhysicsDirectSpaceState3D

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ",message)
	else:
		failures += 1
		push_error(message)

func frames(count: int = 4) -> void:
	for i: int in range(count):
		await physics_frame
	await process_frame

func point(radius: float, angle: float, y: float = 0.025) -> Vector3:
	return Vector3(sin(angle)*radius,y,cos(angle)*radius)

func clear_segment(a: Vector3, b: Vector3) -> bool:
	return not player.test_move(Transform3D(Basis.IDENTITY,a),b-a)

func supported(at: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*0.1,at-Vector3.UP*0.25,1)
	return not space.intersect_ray(query).is_empty()

func action(title: StringName) -> void:
	var event := InputEventAction.new()
	event.action = title
	event.pressed = true
	root.push_input(event,true)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await frames(2)

func place(at: Vector3, target: Vector3) -> void:
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	player.camera.look_at(target)
	await frames()

func capture(title: String) -> void:
	await frames(8)
	await RenderingServer.frame_post_draw
	var image: Image = scene.world_viewport.get_texture().get_image()
	image.resize(1280,720,Image.INTERPOLATE_NEAREST)
	check(image.save_png("res://docs/station/"+title+".png") == OK,"rendered "+title)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run without --headless: checks include real pointer capture and rendered images.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://docs/station")
	change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	await frames()
	check(current_scene.name == "MainMenu","main menu loads")
	current_scene.get_node("%StartButton").pressed.emit()
	await frames(8)
	scene = current_scene
	player = scene.player
	world = scene.get_node("WorldViewport/World")
	# Automated camera captures must not pause when the OS gives focus to another app.
	if root.focus_exited.is_connected(scene._on_focus_exited):
		root.focus_exited.disconnect(scene._on_focus_exited)
	paused = false
	scene.pause_menu.get_node("Overlay").hide()
	scene._capture_mouse()
	await frames()
	space = player.get_world_3d().direct_space_state
	check(world.get_node("Rooms").get_child_count()==6,"six furnished room nodes")
	check(world.get_node("PlantingSlots").get_child_count()==6,"six reusable planting scenes")
	check(scene.world_viewport.size==Vector2i(640,360),"existing 640x360 3D buffer preserved")
	check(scene.get_node("HUD").get_viewport()==root,"HUD remains at window resolution")
	var all_clear := true
	var all_supported := true
	for i: int in range(144):
		var a := point(6.65,TAU*i/144)
		var b := point(6.65,TAU*(i+1)/144)
		all_clear = all_clear and clear_segment(a,b)
		all_supported = all_supported and supported(a)
	check(all_clear,"complete corridor circuit clear for 0.6m player capsule")
	check(all_supported,"continuous floor around full circuit")
	for i: int in range(6):
		var angle := i*PI/3-PI/24
		check(clear_segment(point(6.65,angle),point(9.55,angle)),"room %d entrance physically traversable" % (i+1))
	for side: float in [-1,1]:
		check(clear_segment(Vector3(side*6.65,0.025,0),Vector3(side*3.5,0.025,0)),"greenhouse entrance %d traversable" % int(side))
	check(clear_segment(Vector3(-4.7,0.025,0),Vector3(4.7,0.025,0)),"wide central cross aisle")
	for bed: PlantingSlot in world.get_node("PlantingSlots").get_children():
		var approach := Vector3(bed.position.x,0.025,0)
		var at := bed.position+Vector3(0,0.025,1.48 if bed.position.z<0 else -1.48)
		check(clear_segment(approach,at),"bed %d reachable from central aisle" % bed.slot_number)
		await place(at,bed.global_position+Vector3(0,0.75,0))
		player._update_target()
		check(player.target==bed,"existing ray targets bed %d" % bed.slot_number)
		await action("interact")
		check(scene.inspection.is_open() and scene.inspection.title.text=="Грядка № %d" % bed.slot_number,"E inspects bed %d" % bed.slot_number)
		check(not player.controls_enabled and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"inspection releases cursor")
		scene.inspection.close(true)
		await frames()
		check(player.controls_enabled,"inspection close restores control")
	# Actual input and movement, using the unchanged player controller.
	await place(Vector3(0,0.025,0),Vector3(0,1.55,-1))
	player.camera.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	await frames(65)
	Input.action_release("move_forward")
	await frames()
	check(player.position.z < -0.6 and player.position.z > -0.85,"W walks and physical bed stops player")
	check(absf(player.position.y)<0.02,"player rests on floor")
	await action("pause")
	check(paused and not player.can_process(),"Escape pauses world")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"pause releases mouse")
	scene.pause_menu._on_resume_pressed()
	await frames()
	check(not paused and player.controls_enabled,"resume restores controls")
	# The existing mattress is now a general interactable and opens sleep by E.
	var bed: StationBed = world.get_node("Rooms/LivingQuarters/Mattress")
	await place(Vector3(-2.6,0.025,8.9),bed.global_position)
	player._update_target()
	check(player.target==bed,"interaction ray targets the bed")
	await action("interact")
	check(scene.sleep_panel.is_open() and scene.sleep_panel.is_confirming(),"E opens sleep confirmation")
	check(not player.controls_enabled and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"sleep confirmation releases cursor")
	await action("pause")
	await frames()
	check(not scene.sleep_panel.is_open() and player.controls_enabled,"Escape cancels sleep and restores control")
	# Rays through each intended window must reach terrain, never an opaque hull.
	for index: int in range(6):
		var angle := index*PI/3+PI/24
		var query := PhysicsRayQueryParameters3D.create(point(11.5,angle,1.8),point(15,angle,1.8),1)
		var hit := space.intersect_ray(query)
		check(not hit.is_empty() and str(hit.collider.name)=="Glazing","room %d has actual transparent exterior window" % (index+1))
	# Roof sampled above all corridor angles: no missing or reversed collision faces.
	var roof_complete := true
	for i: int in range(72):
		var query := PhysicsRayQueryParameters3D.create(point(6.6,TAU*i/72,4),point(6.6,TAU*i/72,2.8),1)
		roof_complete = roof_complete and not space.intersect_ray(query).is_empty()
	check(roof_complete,"corridor roof has no gaps in 72 samples")
	var air_angle := 5*PI/3-PI/24
	check(clear_segment(point(11.3,air_angle),point(13.3,air_angle)),"outer airlock doorway and landing traversable")
	await place(point(11.3,air_angle),point(17,air_angle,1.55))
	player.rotation.y = air_angle+PI
	player.camera.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	await frames(115)
	Input.action_release("move_forward")
	await frames()
	check(Vector2(player.position.x,player.position.z).length()>15.8 and absf(player.position.y+0.45)<0.08,"walk down airlock ramp onto lunar ground")
	Input.action_press("move_back")
	await frames(115)
	Input.action_release("move_back")
	await frames()
	check(Vector2(player.position.x,player.position.z).length()<11.8 and absf(player.position.y)<0.03,"walk up ramp and return through airlock without jumping")
	var ground_query := PhysicsRayQueryParameters3D.create(Vector3(20,3,0),Vector3(20,-4,0),1)
	check(not space.intersect_ray(ground_query).is_empty(),"lunar ground has upward-facing collision")
	check(player.camera.far>=100,"player camera reaches saved starfield")
	# Solid geometry should occlude interaction rays as before.
	var ray := PhysicsRayQueryParameters3D.create(Vector3(6.2,1.4,2),Vector3(3.3,1.4,2),1)
	var obstruction := space.intersect_ray(ray)
	check(not obstruction.is_empty() and not obstruction.collider is PlantingSlot,"greenhouse glazing blocks interaction through wall")
	if DisplayServer.get_name() != "headless":
		scene._release_mouse()
		var cameras := world.get_node("PreviewCameras")
		cameras.get_node("Exterior").make_current()
		await capture("exterior")
		cameras.get_node("Greenhouse").make_current()
		await capture("greenhouse")
		# Cutaway for the plan only: regular gameplay always keeps the roofs.
		world.get_node("Greenhouse/Dome").hide()
		world.get_node("RingCorridor/Roof").hide()
		for room: Node3D in world.get_node("Rooms").get_children():
			room.get_node("Roof").hide()
		cameras.get_node("Plan").make_current()
		await capture("plan")
		world.get_node("Greenhouse/Dome").show()
		world.get_node("RingCorridor/Roof").show()
		for room: Node3D in world.get_node("Rooms").get_children():
			room.get_node("Roof").show()
		player.camera.make_current()
	scene.pause_menu._on_main_menu_pressed()
	await scene_changed
	await frames()
	check(current_scene.name=="MainMenu" and not paused,"return to menu resets pause")
	current_scene.get_node("%StartButton").pressed.emit()
	await scene_changed
	await frames(6)
	check(current_scene.player is StationPlayer and not paused,"station can be entered again")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
