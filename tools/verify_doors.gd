extends SceneTree
## Physical door checks, actual E interactions, and a complete airlock walk.
var checks := 0
var failures := 0
var scene: Control
var player: StationPlayer
var world: Node3D
var lock: StationAirlock

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, title: String) -> void:
	checks += 1
	if value:
		print("PASS: ",title)
	else:
		failures += 1
		push_error(title)

func frames(count: int = 5) -> void:
	for i: int in range(count):
		await physics_frame
	await process_frame

func place(at: Vector3, target: Vector3) -> void:
	var d := (target-(at+Vector3.UP*1.55)).normalized()
	player.teleport_to(at,atan2(-d.x,-d.z),asin(d.y))
	await frames()

func aim(target: Vector3) -> void:
	await place(player.global_position,target)

func action() -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	root.push_input(event,true)
	await frames(2)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event,true)
	await frames(2)

func doorway_clear(door: StationDoor) -> bool:
	var a := door.to_global(Vector3(0,0.025,-1.4))
	var b := door.to_global(Vector3(0,0.025,1.4))
	return not player.test_move(Transform3D(Basis.IDENTITY,a),b-a)

func cycle(count: int = 95) -> bool:
	var safe := true
	for i: int in range(count):
		await physics_frame
		safe = safe and (lock.inner_door.is_closed() or lock.outer_door.is_closed())
	await process_frame
	return safe

func walk_lock(action_name: StringName, count: int) -> void:
	player.teleport_to(player.global_position,lock.outer_door.global_rotation.y+PI)
	Input.action_press(action_name)
	await frames(count)
	Input.action_release(action_name)
	await frames()

func press(button: DoorButton, reposition: bool = false) -> void:
	if button == null:
		check(false,"airlock button exists")
		return
	if reposition:
		var door: StationDoor = button.get_parent()
		var side := signf(door.to_local(button.global_position).z)
		await place(door.to_global(Vector3(0,0.025,side*1.3)),button.global_position)
	await aim(button.global_position+button.global_basis.z*0.11)
	check(player.target==button,"ray reaches "+str(button.get_path()))
	check(scene.get_node("HUD/%InteractionHint").visible,"E prompt for airlock button")
	await action()

func capture(title: String) -> void:
	await frames(5)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	check(image.save_png("res://docs/station/"+title+".png")==OK,"capture "+title)

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Run graphically: door checks include mouse capture, input and screenshots.")
		quit(1)
		return
	change_scene_to_file("res://scenes/greenhouse/greenhouse.tscn")
	await scene_changed
	await frames(10)
	scene = current_scene
	player = scene.player
	world = scene.get_node("WorldViewport/World")
	if root.focus_exited.is_connected(scene._on_focus_exited):
		root.focus_exited.disconnect(scene._on_focus_exited)
	paused = false
	scene.pause_menu.get_node("Overlay").hide()
	scene._capture_mouse()
	lock = world.get_node("Rooms/Airlock/AirlockControl")
	player.teleport_to(Vector3(0,0.025,0))
	await frames(100)
	check(get_nodes_in_group("station_doors").size()==9,"two automatic, five room and two airlock doors")
	check(world.find_children("ParkedInnerDoor*","Node",true,false).is_empty(),"decorative panels removed from airlock passage")
	for title: String in ["EastDoor","WestDoor"]:
		var door: StationDoor = world.get_node("Greenhouse/"+title)
		check(door.is_closed() and not doorway_clear(door),title+" starts closed and solid")
		await place(door.to_global(Vector3(0,0.025,-2.6)),door.to_global(Vector3(0,1.3,0)))
		await frames(50)
		check(door.is_fully_open() and doorway_clear(door),title+" opens on approach")
		check(door.get_node("LeftLeaf").position.x<-door.opening_width*0.7 and door.get_node("RightLeaf").position.x>door.opening_width*0.7,title+" panels slide in opposite directions")
		await place(door.to_global(Vector3(0,0.025,0)),door.to_global(Vector3(0,1.3,2)))
		await frames(100)
		check(door.is_fully_open(),title+" stays open while player occupies threshold")
		player.teleport_to(Vector3(0,0.025,0))
		await frames(110)
		check(door.is_closed(),title+" closes after player leaves")
	var automatic: StationDoor = world.get_node("Greenhouse/EastDoor")
	await place(automatic.to_global(Vector3(0,0.025,-3.8)),automatic.to_global(Vector3(0,1.3,0)))
	await capture("automatic-door-closed")
	player.teleport_to(automatic.to_global(Vector3(0,0.025,-4.0)),automatic.global_rotation.y+PI)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await frames(75)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await frames()
	check(automatic.to_local(player.global_position).z>1.5,"sprint through automatic doorway without pressing E")
	await place(automatic.to_global(Vector3(0,0.025,-2.5)),automatic.to_global(Vector3(0,1.3,0)))
	await capture("automatic-door-open")
	var ordinary: StationDoor = world.get_node("Rooms/LivingQuarters/HallPartition01/Door")
	await place(ordinary.to_global(Vector3(0,0.025,-1.4)),ordinary.to_global(Vector3(0,1.2,0)))
	check(player.target==ordinary and not doorway_clear(ordinary),"room door targeted from corridor and blocks movement")
	await action()
	await frames(10)
	var paused_pose := ordinary.openness
	scene.pause_menu.open()
	await create_timer(0.3,true).timeout
	check(is_equal_approx(ordinary.openness,paused_pose),"door animation pauses with game")
	scene.pause_menu._on_resume_pressed()
	await frames(50)
	check(ordinary.is_fully_open() and doorway_clear(ordinary),"E swings room door open and collision follows")
	await place(ordinary.to_global(Vector3(0,0.025,2.4)),ordinary.get_node("SwingLeaf/Collision").global_position)
	check(player.target==ordinary,"open door can be targeted from room")
	await action()
	await frames(50)
	check(ordinary.is_closed(),"E closes room door")
	await aim(ordinary.to_global(Vector3(0,1.2,0)))
	await action()
	await frames(50)
	check(ordinary.is_fully_open() and ordinary.get_node("SwingLeaf").rotation.y>1.5,"door opens away from player on room side")
	await place(ordinary.to_global(Vector3(0,0.025,0)),ordinary.to_global(Vector3(0,1.3,2)))
	ordinary.request_open(false)
	await frames(60)
	check(ordinary.is_fully_open(),"ordinary door cannot close on player")
	player.teleport_to(Vector3(0,0.025,0))
	lock.pending_side = &""
	await frames(60)
	check(lock.inner_door.is_closed() and lock.outer_door.is_closed(),"airlock starts with both gates shut")
	await place(lock.inner_door.to_global(Vector3(0,0.025,-1.4)),lock.inner_door.to_global(Vector3(0,1.2,0)))
	await action()
	check(lock.pending_side==&"" and lock.inner_door.is_closed(),"airlock leaf cannot be opened without its button")
	await press(lock.inner_door.get_node("StationButton"),true)
	check(await cycle(55),"inner opening never opens both gates")
	check(lock.inner_door.is_fully_open() and lock.outer_door.is_closed(),"first button opens only inner gate")
	await place(lock.inner_door.to_global(Vector3(0,0.025,0)),lock.inner_door.to_global(Vector3(0,1.3,2)))
	lock.request(&"outer")
	check(await cycle(65),"airlock remains interlocked when player blocks closing gate")
	check(lock.inner_door.is_fully_open() and lock.outer_door.is_closed(),"blocked inner gate prevents outer opening")
	await place(lock.inner_door.to_global(Vector3(0,0.025,2.5)),lock.outer_door.global_position+Vector3.UP)
	check(await cycle(),"cycle remains safe after clearing threshold")
	check(lock.inner_door.is_closed() and lock.outer_door.is_fully_open(),"outer opens after inner has fully closed")
	player.teleport_to(Vector3(0,0.025,0))
	lock.pending_side = &""
	await frames(60)
	await press(lock.inner_door.get_node("StationButton"),true)
	await cycle(55)
	await walk_lock(&"move_forward",130)
	check(lock.inner_door.to_local(player.global_position).z>4.2,"walk from station into chamber without obstructing panels")
	await press(lock.outer_door.get_node("ChamberButton"))
	check(await cycle(),"second button safely exchanges open gates")
	check(lock.inner_door.is_closed() and lock.outer_door.is_fully_open(),"two different buttons permit lunar exit")
	await walk_lock(&"move_forward",140)
	check(Vector2(player.position.x,player.position.z).length()>20.8 and absf(player.position.y+0.45)<0.08,"walk through outer door and down ramp to Moon")
	# Four seconds clear of the sensor plus the physical closing travel.
	await frames(240)
	check(lock.outer_door.is_closed(),"outer gate automatically closes after departure")
	await walk_lock(&"move_back",70)
	await press(lock.outer_door.get_node("SurfaceButton"))
	await cycle(55)
	await walk_lock(&"move_back",130)
	await press(lock.inner_door.get_node("ChamberButton"))
	check(await cycle(),"return cycle keeps one gate closed")
	await walk_lock(&"move_back",80)
	check(Vector2(player.position.x,player.position.z).length()<10,"return from lunar surface to station using outside and inside panels")
	await place(lock.inner_door.to_global(Vector3(0,0.025,-1.8)),lock.outer_door.global_position+Vector3.UP*1.3)
	await capture("airlock-doors")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
