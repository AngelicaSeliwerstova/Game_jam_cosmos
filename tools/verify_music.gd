extends SceneTree
## Real mixer/scene lifecycle checks. Run without --headless for audio output.

var checks := 0
var failures := 0
var music: AudioStreamPlayer

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if value:
		print("PASS: ",message)
	else:
		failures += 1
		push_error(message)

func settle(seconds: float = 0.4) -> void:
	await create_timer(seconds,true).timeout

func detach_focus_pause() -> void:
	if root.focus_exited.is_connected(current_scene._on_focus_exited):
		root.focus_exited.disconnect(current_scene._on_focus_exited)
	paused = false
	current_scene.pause_menu.get_node("Overlay").hide()

func run() -> void:
	music = root.get_node_or_null("Music") as AudioStreamPlayer
	check(music!=null,"music autoload created")
	if music == null:
		quit(1)
		return
	var original_id := music.get_instance_id()
	check(music.stream is AudioStreamWAV and absf(music.stream.get_length()-180.0)<0.1,"full three-minute track loaded")
	check(music.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"forward looping configured")
	check(music.stream.stereo and music.stream.mix_rate==44100,"original stereo and sample rate preserved")
	check(music.stream.format==AudioStreamWAV.FORMAT_QOA,"imported audio uses QOA compression")
	check(music.volume_db==-8.0,"background music level -8dB")
	var bus := AudioServer.get_bus_index("Music")
	check(bus>0 and music.bus==&"Music","dedicated Music bus connected")
	change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
	await scene_changed
	await settle()
	check(music.playing,"music starts in main menu")
	var position := music.get_playback_position()
	await settle()
	check(music.get_playback_position()>position+0.1,"audio playback position advances")
	var peak := -100.0
	for i: int in range(10):
		await settle(0.05)
		peak = maxf(peak,AudioServer.get_bus_peak_volume_left_db(bus,0))
	check(peak>-70.0,"Music bus mixes a non-silent audio signal")
	print("Music bus peak: ",peak," dB")
	position = music.get_playback_position()
	current_scene.get_node("%StartButton").pressed.emit()
	await scene_changed
	detach_focus_pause()
	await settle()
	check(music.get_instance_id()==original_id and music.get_playback_position()>position,"entering station preserves the same playback")
	current_scene.pause_menu.open()
	position = music.get_playback_position()
	await settle()
	check(paused and music.playing and music.get_playback_position()>position+0.1,"music continues during game pause")
	current_scene.pause_menu._on_resume_pressed()
	await settle(0.1)
	check(not paused and music.playing,"music continues after resume")
	position = music.get_playback_position()
	current_scene.pause_menu._on_main_menu_pressed()
	await scene_changed
	await settle()
	check(music.get_instance_id()==original_id and music.get_playback_position()>position,"returning to menu does not restart music")
	current_scene.get_node("%StartButton").pressed.emit()
	await scene_changed
	detach_focus_pause()
	await settle()
	check(root.find_children("*","AudioStreamPlayer",true,false).size()==1,"repeat entry does not create overlapping players")
	# Exercise the actual end of the track without waiting three minutes.
	music.seek(179.75)
	await settle(0.15)
	check(music.get_playback_position()>179.5,"seek reaches the end of the track")
	await settle(0.6)
	check(music.playing and music.get_playback_position()<1.5,"track loops and keeps playing")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
