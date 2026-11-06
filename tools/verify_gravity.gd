extends SceneTree
## Check real gravity areas, jump trajectories and continuous airlock crossings.
var checks := 0
var failures := 0
var player: StationPlayer

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, title: String) -> void:
	checks += 1
	if value:
		print("PASS: ",title)
	else:
		failures += 1
		push_error(title)

func frames(count: int = 8) -> void:
	for i: int in range(count):
		await physics_frame
	await process_frame

func jump() -> Vector2:
	var base := player.global_position.y
	var peak := 0.0
	var started := false
	var airborne := 0
	Input.action_press("jump")
	for i: int in range(430):
		await physics_frame
		peak = maxf(peak,player.global_position.y-base)
		if not player.is_on_floor():
			started = true
			airborne += 1
		if i==6 or i==21:
			Input.action_release("jump")
		if i==20:
			Input.action_press("jump")
		if started and player.is_on_floor():
			break
	Input.action_release("jump")
	await frames()
	return Vector2(peak,airborne/60.0)

func walk_lock(direction: StringName, gate: StationDoor) -> int:
	player.teleport_to(player.global_position,gate.global_rotation.y+PI)
	await frames()
	var last := player.gravity
	var changes := 0
	Input.action_press(direction)
	for i: int in range(135):
		await physics_frame
		if not is_equal_approx(player.gravity,last):
			changes += 1
			last = player.gravity
	Input.action_release(direction)
	await frames(12)
	return changes

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Run graphically: gravity checks include captured movement and jump input.")
		quit(1)
		return
	change_scene_to_file("res://scenes/greenhouse/greenhouse.tscn")
	await scene_changed
	await frames()
	var scene: Control = current_scene
	player = scene.player
	if root.focus_exited.is_connected(scene._on_focus_exited):
		root.focus_exited.disconnect(scene._on_focus_exited)
	paused = false
	scene.pause_menu.get_node("Overlay").hide()
	scene._capture_mouse()
	var world: Node3D = scene.get_node("WorldViewport/World")
	check(is_equal_approx(player.gravity,12.0),"spawn inside station has stronger gravity: 12m/s2")
	for marker: Node3D in world.get_node("Waypoints").get_children():
		player.teleport_to(marker.global_position)
		await frames()
		check(is_equal_approx(player.gravity,12.0),str(marker.name)+" uses station gravity")
	player.teleport_to(Vector3(0,3.5,0))
	await frames()
	check(is_equal_approx(player.gravity,12.0),"upper greenhouse dome retains station gravity")
	player.teleport_to(Vector3(0,3.5,12))
	await frames()
	check(is_equal_approx(player.gravity,1.62),"outside on flat roof uses lunar gravity")
	player.teleport_to(Vector3(16,0.1,16))
	await frames()
	check(is_equal_approx(player.gravity,1.62),"exterior outside circular hull is not included in station area")
	player.teleport_to(Vector3(0,0.025,0))
	await frames()
	var indoor := await jump()
	check(indoor.x>0.85 and indoor.x<1.1 and player.is_on_floor(),"station jump is lower and lands normally")
	var lock: StationAirlock = world.get_node("Rooms/Airlock/AirlockControl")
	var gate := lock.outer_door
	player.teleport_to(gate.to_global(Vector3(0,0.025,-1.4)),gate.global_rotation.y+PI)
	await frames()
	check(is_equal_approx(player.gravity,12.0),"airlock chamber retains station gravity")
	lock.request(&"outer")
	await frames(60)
	var changes := await walk_lock(&"move_forward",gate)
	check(changes==1 and is_equal_approx(player.gravity,1.62),"walking out switches gravity once without boundary flicker")
	check(Vector2(player.position.x,player.position.z).length()>21.0 and player.is_on_floor(),"lunar gravity preserves ramp descent and ground contact")
	var lunar := await jump()
	check(lunar.x>6.5 and lunar.x<7.5,"lunar jump reaches about seven meters without a double jump")
	check(lunar.y>indoor.y*5 and lunar.y<6.5 and player.is_on_floor(),"lunar jump floats longer and lands normally")
	print("Station jump: %.3fm / %.3fs; Moon jump: %.3fm / %.3fs" % [indoor.x,indoor.y,lunar.x,lunar.y])
	lock.request(&"outer")
	await frames(60)
	changes = await walk_lock(&"move_back",gate)
	check(changes==1 and is_equal_approx(player.gravity,12.0),"returning through gate restores station gravity once")
	check(player.is_on_floor() and absf(player.position.y)<0.03,"strong gravity preserves return up ramp")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
