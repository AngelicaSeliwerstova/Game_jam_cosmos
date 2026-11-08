extends SceneTree
## Export the saved 3D world, including its reusable scene instances, to Blender.
## Run from the project root: godot --headless --path . --script res://tools/export_station_glb.gd

const SOURCE := "res://scenes/greenhouse/greenhouse_world.tscn"
const OUTPUT_DIR := "res://build/blender"
const OUTPUT := OUTPUT_DIR + "/lunar_station.glb"
var visible_meshes := 0

func _initialize() -> void:
	export_station.call_deferred()

func remove_scripts(node: Node) -> void:
	# Export a disposable copy; never run the gameplay controller or change the source.
	if node is MeshInstance3D and node.is_visible_in_tree():
		visible_meshes += 1
	node.set_script(null)
	for child: Node in node.get_children():
		remove_scripts(child)

func export_station() -> void:
	var scene: PackedScene = load(SOURCE)
	if scene == null:
		push_error("Cannot load station: " + SOURCE)
		quit(1)
		return
	var station: Node3D = scene.instantiate()
	# _ready() normally sets this visibility. Apply it before removing scripts.
	for bed: Node in station.get_node("PlantingSlots").get_children():
		bed.get_node("Visuals/PlantPlaceholder").visible = bed.get("show_plant")
	remove_scripts(station)
	root.add_child(station)
	await process_frame
	var directory_error := DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	if directory_error != OK:
		push_error("Cannot create export directory: " + error_string(directory_error))
		quit(1)
		return
	# Avoid reimporting this exported world into the original project.
	var ignore := FileAccess.open(OUTPUT_DIR + "/.gdignore", FileAccess.WRITE)
	if ignore == null:
		push_error("Cannot create export .gdignore")
		quit(1)
		return
	ignore.close()
	var document := GLTFDocument.new()
	document.image_format = "PNG"
	document.root_node_mode = GLTFDocument.ROOT_NODE_MODE_KEEP_ROOT
	# Hidden outlines and five inactive plant placeholders must stay absent in Blender.
	document.visibility_mode = GLTFDocument.VISIBILITY_MODE_EXCLUDE
	var state := GLTFState.new()
	var result := document.append_from_scene(station, state)
	if result == OK:
		result = document.write_to_filesystem(state, OUTPUT)
	if result != OK:
		push_error("glTF export failed: " + error_string(result))
		quit(1)
		return
	print("EXPORTED: ", ProjectSettings.globalize_path(OUTPUT))
	print("Visible source mesh instances: ", visible_meshes)
	print("glTF nodes: ", state.get_nodes().size(), "; mesh resources: ", state.get_meshes().size(), "; embedded images: ", state.get_images().size())
	station.queue_free()
	quit()
