extends SceneTree
## First-loop checks. Runs headless: state rules plus scene/UI wiring.
## Input capture itself is covered by tools/verify_station.gd, which needs a display.

var failures := 0
var checks := 0
var state: Node


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)


func frames(count: int = 4) -> void:
	for _i: int in range(count):
		await process_frame
	await physics_frame


func run() -> void:
	state = root.get_node_or_null("GameState")
	check(state != null, "GameState autoload exists")
	if state == null:
		quit(1)
		return

	state.reset()
	check(state.day == 1, "new game starts on day 1")
	check(state.seeds == state.START_SEEDS and state.seeds == 6, "new game starts with 6 seeds")
	check(state.water == state.START_WATER and state.water == 24, "new game starts with 24 water")
	check(state.plots.size() == 6, "six independent plot states exist")
	check(not state.get_plot(0).planted, "plots start empty")

	check(state.plant(0), "planting an empty plot succeeds")
	check(state.seeds == 5, "planting spends exactly one seed")
	check(not state.plant(0), "cannot plant an occupied plot")
	check(state.seeds == 5, "failed planting spends nothing")
	check(state.water_plot(0), "watering a planted plot succeeds")
	check(state.water == 23, "watering spends exactly one water")
	check(not state.water_plot(0), "cannot water twice in one day")
	check(state.water == 23, "failed watering spends nothing")

	check(state.plant(1), "planting a second plot succeeds")
	check(state.seeds == 4, "second planting spends one seed")
	check(state.get_plot(0).watered_today and not state.get_plot(1).watered_today, "plot watering is independent")

	var report: Dictionary = state.sleep()
	check(state.day == 2, "one sleep advances exactly one day")
	check(state.get_plot(0).growth == 1, "watered plant grows after sleep")
	check(state.get_plot(1).growth == 0, "unwatered plant does not grow")
	check(not state.get_plot(0).watered_today and not state.get_plot(1).watered_today, "sleep resets watering")
	check(report.grown == 1 and report.thirsty == 1 and report.ready == 0, "sleep report counts growth and thirst")

	report = state.sleep()
	check(state.day == 3 and state.get_plot(0).growth == 1 and state.get_plot(1).growth == 0, "second dry sleep grows nothing")
	check(report.grown == 0 and report.thirsty == 2 and report.ready == 0, "second sleep reports no growth")

	check(state.get_plot(0).growth == 1, "plant did not grow without a new watered night")
	check(state.water_plot(0), "plant can be watered on a later day")
	check(state.water == 22, "later watering spends one water")
	check(state.get_plot(0).growth == 1, "watering does not grow the plant instantly")
	report = state.sleep()
	check(state.day == 4 and state.get_plot(0).growth == 2, "second watered night reaches adult")
	check(state.is_ready(0), "adult plant is ready")
	check(report.grown == 1 and report.thirsty == 1 and report.ready == 1, "mature sleep report is correct")

	var seeds_before: int = state.seeds
	check(state.harvest(0) == 2, "harvest returns two seeds")
	check(state.seeds == seeds_before + 2, "harvest adds exactly two seeds")
	check(not state.get_plot(0).planted and state.get_plot(0).growth == 0, "harvest frees the plot")
	check(not state.can_harvest(0), "empty plot is not harvestable")

	state.reset()
	state.seeds = 0
	check(not state.plant(2), "cannot plant without seeds")
	check(not state.get_plot(2).planted, "failed seedless planting changes nothing")

	state.reset()
	check(state.plant(2), "plot for water check is planted")
	state.water = 0
	check(not state.water_plot(2), "cannot water without water")
	check(not state.get_plot(2).watered_today, "failed waterless watering changes nothing")
	check(state.water == 0, "failed waterless watering spends nothing")

	state.reset()
	check(state.plant(3), "young plot is planted")
	check(state.harvest(3) == 0, "immature plant cannot be harvested")
	check(state.get_plot(3).planted, "failed harvest keeps the plant")

	state.reset()
	check(state.plant(5), "ready plot is planted")
	state.get_plot(5).growth = state.READY_GROWTH
	report = state.sleep()
	check(report.grown == 0 and report.thirsty == 0 and report.ready == 1, "already ready plant is reported without thirst")

	state.reset()
	state.day = 9
	state.seeds = 0
	state.water = 0
	state.get_plot(4).plant()
	state.reset()
	check(state.day == 1 and state.seeds == 6 and state.water == 24, "reset restores starting supplies")
	check(not state.get_plot(4).planted, "reset clears every plot")

	# Scene wiring: menu start creates a fresh session.
	change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	await frames(8)
	check(current_scene.name == "MainMenu", "main menu loads")
	state.day = 9
	state.seeds = 0
	state.water = 0
	state.get_plot(2).plant()
	current_scene.get_node("%StartButton").pressed.emit()
	await frames(10)
	check(current_scene.name == "Greenhouse", "start enters the greenhouse")
	check(state.day == 1 and state.seeds == 6 and state.water == 24, "start resets progress")
	check(not state.get_plot(2).planted, "start clears previous plots")

	var scene: Control = current_scene
	var world: Node3D = scene.get_node("WorldViewport/World")
	var slots: Node3D = world.get_node("PlantingSlots")
	var bed: StationBed = world.get_node("Rooms/LivingQuarters/Furnishings/Mattress")
	var player: StationPlayer = scene.player
	var slot0: PlantingSlot = slots.get_node("Slot1")

	check(scene.hud.stats.text.contains("День 1"), "HUD shows the day")
	check(scene.hud.stats.text.contains("Вода 24") and scene.hud.stats.text.contains("Семена 6"), "HUD shows water and seeds")
	await create_timer(0.3).timeout
	check(state.day == 1, "day does not advance without sleep")

	# The existing ray must find the mattress as a general interactable.
	var bed_at := Vector3(-3.1, 0.025, 12.5)
	var bed_direction := (bed.global_position - (bed_at + Vector3.UP * player.head.position.y)).normalized()
	player.teleport_to(bed_at, atan2(-bed_direction.x, -bed_direction.z), asin(bed_direction.y))
	await frames(6)
	player._update_target()
	check(player.target == bed, "interaction ray targets the bed")
	check(player.target is StationBed, "bed uses the shared interactable base")
	check(scene.hud.interaction_hint.text.contains("спать"), "bed shows its own interaction hint")

	player.inspection_requested.emit(bed)
	await frames(2)
	check(scene.sleep_panel.is_open() and scene.sleep_panel.is_confirming(), "E flow opens sleep confirmation")
	check(not player.controls_enabled, "sleep confirmation releases controls")

	check(state.plant(0), "planted a plot before sleeping")
	check(state.water_plot(0), "watered plot before sleeping")
	var day_before: int = state.day
	scene.sleep_panel.confirm()
	await frames(2)
	check(scene.sleep_fade.color.a > 0.0, "sleep fades the screen")
	# A repeated press / second entry point during the fade must not add days.
	scene.sleep_panel.confirm()
	scene._start_sleep()
	await create_timer(1.2).timeout
	await frames(4)
	check(scene.sleep_fade.color.a == 0.0, "sleep restores the image")
	check(state.day == day_before + 1, "repeat press during fade advances exactly one day")
	check(state.get_plot(0).growth == 1, "sleep grew the watered plot")
	check(scene.sleep_panel.is_open() and not scene.sleep_panel.is_confirming(), "sleep report is shown after the fade")
	check(scene.sleep_panel.report_title.text == "День 2", "sleep report names the new day")
	check(scene.sleep_panel.report_text.text.contains("Выросло растений: 1"), "report shows grown count")
	check(slot0.get_node("Visuals/Plants/Young").visible, "plant visual switched to the young stage")
	check(scene.hud.stats.text.contains("День 2") and scene.hud.stats.text.contains("Вода 23"), "HUD refreshed after sleep")

	scene.sleep_panel.close(true)
	await frames(2)
	check(not scene.sleep_panel.is_open(), "sleep report closes")

	# The panel explains why an action is unavailable.
	state.reset()
	state.seeds = 0
	scene._open_inspection(slot0)
	await frames(2)
	check(scene.inspection.action_button.disabled, "planting is disabled without seeds")
	check(scene.inspection.reason.text.contains("Нет семян"), "panel explains missing seeds")
	scene.inspection.close(true)
	await frames(2)

	state.reset()
	check(state.plant(0), "plot for no-water panel check")
	state.water = 0
	scene._open_inspection(slot0)
	await frames(2)
	check(scene.inspection.action_button.disabled, "watering is disabled without water")
	check(scene.inspection.reason.text.contains("Нет воды"), "panel explains missing water")
	scene.inspection.close(true)
	await frames(2)

	# Panel actions must go through GameState guards.
	state.reset()
	scene._open_inspection(slot0)
	await frames(2)
	check(scene.inspection.is_open() and scene.inspection.title.text == "Грядка № 1", "inspection opens for a plot")
	check(scene.inspection.action_button.text.begins_with("Посадить"), "empty plot offers planting")
	scene.inspection.action_button.pressed.emit()
	await frames(2)
	check(state.get_plot(0).planted and state.seeds == 5, "panel planting spends one seed")
	check(slot0.get_node("Visuals/Plants/Sprout").visible, "plant visual switched to the sprout stage")
	check(scene.inspection.action_button.text.begins_with("Полить"), "planted plot offers watering")

	scene.inspection.action_button.pressed.emit()
	await frames(2)
	check(state.get_plot(0).watered_today and state.water == 23, "panel watering spends one water")
	check(scene.inspection.action_button.disabled, "repeat watering is disabled")
	var water_after: int = state.water
	scene.inspection.action_button.pressed.emit()
	await frames(2)
	check(state.water == water_after, "disabled watering spends nothing")
	scene.inspection.close(true)
	await frames(2)
	check(not scene.inspection.is_open(), "inspection closes")

	# Harvest through the same panel.
	state.get_plot(1).plant()
	state.get_plot(1).growth = state.READY_GROWTH
	state.changed.emit()
	var slot1: PlantingSlot = slots.get_node("Slot2")
	var seeds_harvest: int = state.seeds
	scene._open_inspection(slot1)
	await frames(2)
	check(scene.inspection.action_button.text.begins_with("Собрать"), "adult plot offers harvest")
	check(slot1.get_node("Visuals/Plants/Adult").visible, "adult plant visual is visible")
	scene.inspection.action_button.pressed.emit()
	await frames(2)
	check(not state.get_plot(1).planted and state.seeds == seeds_harvest + 2, "panel harvest frees plot and returns seeds")
	check(not slot1.get_node("Visuals/Plants/Adult").visible, "harvest hides the plant visual")
	scene.inspection.close(true)
	await frames(2)

	scene.pause_menu.open()
	await frames(2)
	check(paused, "pause still works")
	scene.pause_menu._on_resume_pressed()
	await frames(2)
	check(not paused, "resume still works")

	# Return to the menu and start over: the panel/state must be clean again.
	scene.pause_menu._on_main_menu_pressed()
	await scene_changed
	await frames(4)
	check(current_scene.name == "MainMenu" and not paused, "return to menu resets pause")
	state.day = 8
	state.seeds = 0
	state.get_plot(5).plant()
	current_scene.get_node("%StartButton").pressed.emit()
	await scene_changed
	await frames(6)
	check(state.day == 1 and state.seeds == 6 and state.water == 24, "second start also begins a new game")
	check(not state.get_plot(5).planted, "second start clears progress")

	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
