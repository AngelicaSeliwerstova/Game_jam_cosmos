extends SceneTree
## Integration checks against the saved scene and Godot's real physics space.
## Run graphically: pointer capture and input checks require a real display.

var failures := 0
var checks := 0
var scene: Control
var player: StationPlayer
var world: Node3D
var space: PhysicsDirectSpaceState3D
const LAYOUT_SCALE := 1.35
const HALL_RADIUS := 6.65 * LAYOUT_SCALE
const OUTER_RADIUS := 12.6 * LAYOUT_SCALE

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

func key_input(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func place(at: Vector3, target: Vector3) -> void:
	var direction := (target - (at + Vector3.UP * player.head.position.y)).normalized()
	player.teleport_to(at, atan2(-direction.x,-direction.z), asin(direction.y))
	await frames()

func contact_check(at: Vector3, diagonal: bool, sprint: bool, title: String) -> void:
	player.teleport_to(at)
	await frames(10)
	Input.action_press("move_forward")
	if diagonal:
		Input.action_press("move_left")
	if sprint:
		Input.action_press("sprint")
	var low := player.position.y
	var high := low
	var previous := player.position
	var largest_step := 0.0
	var grounded := true
	for i: int in range(100):
		await physics_frame
		largest_step = maxf(largest_step,player.position.distance_to(previous))
		low = minf(low,player.position.y)
		high = maxf(high,player.position.y)
		grounded = grounded and player.is_on_floor()
		previous = player.position
	for key: String in ["move_forward","move_left","sprint"]:
		Input.action_release(key)
	await frames()
	check(largest_step<0.12 and high-low<0.01 and grounded,title)
	print("  motion: max step %.5fm, height span %.5fm" % [largest_step,high-low])

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
	await scene_changed
	await frames()
	check(current_scene.name == "MainMenu","main menu loads")
	current_scene.get_node("%StartButton").pressed.emit()
	await scene_changed
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
	check(player.camera.is_set_as_top_level() and ProjectSettings.get_setting("physics/common/physics_interpolation"),"independent camera follows interpolated physics")
	# Architectural capsule routes are checked with doors open. Door interaction,
	# obstruction and airlock sequencing have their own real-input integration test.
	player.teleport_to(Vector3(0,0.025,0))
	for door: StationDoor in get_nodes_in_group("station_doors"):
		if door.mode != StationDoor.Mode.AIRLOCK:
			door.request_open(true)
			if door.mode == StationDoor.Mode.AUTOMATIC:
				door.close_delay = 2.0
	var airlock: StationAirlock = world.get_node("Rooms/Airlock/AirlockControl")
	airlock.request(&"inner")
	await frames(55)
	var all_clear := true
	var all_supported := true
	for i: int in range(144):
		var a := point(HALL_RADIUS,TAU*i/144)
		var b := point(HALL_RADIUS,TAU*(i+1)/144)
		all_clear = all_clear and clear_segment(a,b)
		all_supported = all_supported and supported(a)
	check(all_clear,"complete corridor circuit clear for 0.6m player capsule")
	check(all_supported,"continuous floor around full circuit")
	for i: int in range(6):
		var angle := i*PI/3-PI/24
		check(clear_segment(point(HALL_RADIUS,angle),point(9.55*LAYOUT_SCALE,angle)),"room %d entrance physically traversable" % (i+1))
	for side: float in [-1,1]:
		check(clear_segment(Vector3(side*HALL_RADIUS,0.025,0),Vector3(side*3.5*LAYOUT_SCALE,0.025,0)),"greenhouse entrance %d traversable" % int(side))
	check(clear_segment(Vector3(-6.3,0.025,0),Vector3(6.3,0.025,0)),"wide central cross aisle")
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
		if bed.slot_number == 4:
			var still := player.position
			Input.action_press("sprint")
			Input.action_press("jump")
			Input.action_press("move_forward")
			await frames(10)
			check(player.position.is_equal_approx(still),"inspection blocks running and jumping")
			for key: String in ["sprint","jump","move_forward"]:
				Input.action_release(key)
		scene.inspection.close(true)
		await frames()
		check(player.controls_enabled,"inspection close restores control")
	# Actual input and movement, including bed collision, sprint and jump.
	await place(Vector3(0,0.025,0),Vector3(0,1.55,-1))
	Input.action_press("move_forward")
	await frames(65)
	Input.action_release("move_forward")
	await frames()
	check(player.position.z < -1.35 and player.position.z > -1.46,"W walks and physical bed stops player")
	check(absf(player.position.y)<0.02,"player rests on floor")
	var distances: Array[float] = []
	for running: bool in [false,true]:
		player.teleport_to(Vector3(0,0.025,0),-PI/2)
		await frames(8)
		var start := player.position
		Input.action_press("move_forward")
		if running:
			key_input(KEY_SHIFT,true)
		await frames(30)
		Input.action_release("move_forward")
		key_input(KEY_SHIFT,false)
		await frames()
		distances.append(player.position.distance_to(start))
	check(distances[0]>1.2 and distances[0]<1.6,"walking remains approximately 2.7m/s")
	check(distances[1]>2.4 and distances[1]<3.0 and distances[1]>distances[0]*1.7,"held Shift runs approximately 5.2m/s")
	player.teleport_to(Vector3(0,0.025,0))
	await frames(8)
	key_input(KEY_SPACE,true)
	var peak := 0.0
	for i: int in range(90):
		await physics_frame
		peak = maxf(peak,player.position.y)
		if i == 6 or i == 19:
			key_input(KEY_SPACE,false)
		if i == 18:
			key_input(KEY_SPACE,true)
	await frames()
	check(peak>0.9 and peak<1.3,"Space jumps without an airborne double jump")
	check(player.is_on_floor() and absf(player.position.y)<0.02,"jump lands on stable floor")
	var flower_bed: Node3D = world.get_node("PlantingSlots/Slot4")
	await contact_check(flower_bed.position+Vector3(0,0.025,2.3),false,false,"walking into flower bed has no position spikes")
	await contact_check(flower_bed.position+Vector3(0,0.025,2.3),false,true,"running into flower bed has no position spikes")
	await contact_check(flower_bed.position+Vector3(1.5,0.025,2),true,false,"walking around flower bed corner stays stable")
	await contact_check(flower_bed.position+Vector3(1.5,0.025,2),true,true,"running around flower bed corner stays stable")
	# Immediate mouse rotation must not be delayed by position interpolation.
	player.teleport_to(Vector3(0,0.025,0))
	player.look(Vector2(100,-40))
	await frames(2)
	check(absf(player.rotation.y+0.25)<0.01 and absf(player.head.rotation.x-0.1)<0.01,"mouse look remains responsive with smoothed camera")
	await action("pause")
	check(paused and not player.can_process(),"Escape pauses world")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"pause releases mouse")
	scene.pause_menu._on_resume_pressed()
	await frames()
	check(not paused and player.controls_enabled,"resume restores controls")
	# Rays through each intended window must reach terrain, never an opaque hull.
	for index: int in range(6):
		var angle := index*PI/3+PI/24
		var query := PhysicsRayQueryParameters3D.create(point(11.5*LAYOUT_SCALE,angle,1.8),point(15*LAYOUT_SCALE,angle,1.8),1)
		var hit := space.intersect_ray(query)
		check(not hit.is_empty() and str(hit.collider.name)=="Glazing","room %d has actual transparent exterior window" % (index+1))
	# Roof sampled above all corridor angles: no missing or reversed collision faces.
	var roof_complete := true
	for i: int in range(72):
		var query := PhysicsRayQueryParameters3D.create(point(HALL_RADIUS,TAU*i/72,4),point(HALL_RADIUS,TAU*i/72,2.8),1)
		roof_complete = roof_complete and not space.intersect_ray(query).is_empty()
	check(roof_complete,"corridor roof has no gaps in 72 samples")
	var air_angle := 5*PI/3-PI/24
	airlock.request(&"outer")
	await frames(100)
	check(clear_segment(point(OUTER_RADIUS-1.3,air_angle),point(OUTER_RADIUS+0.7,air_angle)),"outer airlock doorway and landing traversable")
	player.teleport_to(point(OUTER_RADIUS-1.3,air_angle),air_angle+PI)
	await frames()
	Input.action_press("move_forward")
	await frames(118)
	Input.action_release("move_forward")
	await frames()
	check(Vector2(player.position.x,player.position.z).length()>OUTER_RADIUS+3.8 and absf(player.position.y+0.45)<0.08,"walk down airlock ramp onto lunar ground")
	airlock.request(&"outer")
	Input.action_press("move_back")
	await frames(118)
	Input.action_release("move_back")
	await frames()
	check(Vector2(player.position.x,player.position.z).length()<OUTER_RADIUS-0.8 and absf(player.position.y)<0.03,"walk up ramp and return through airlock without jumping")
	var ground_query := PhysicsRayQueryParameters3D.create(Vector3(20,3,0),Vector3(20,-4,0),1)
	check(not space.intersect_ray(ground_query).is_empty(),"lunar ground has upward-facing collision")
	check(player.camera.far>=100,"player camera reaches saved starfield")
	# Solid geometry should occlude interaction rays as before.
	var ray := PhysicsRayQueryParameters3D.create(Vector3(6.2*LAYOUT_SCALE,1.4,2*LAYOUT_SCALE),Vector3(3.3*LAYOUT_SCALE,1.4,2*LAYOUT_SCALE),1)
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
