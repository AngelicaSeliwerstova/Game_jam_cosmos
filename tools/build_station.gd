extends SceneTree
## Offline authoring only. The game loads the saved, fully editable PackedScene.
## Re-running replaces generated scenes, so keep hand edits or make a copy first.

const MODULES := "res://scenes/station/modules/"
const R_GARDEN := 5.3
const R_HALL := 8.0
const R_OUTER := 12.6
const HEIGHT := 3.15
var mats: Dictionary = {}
var modules: Dictionary = {}
var world: Node3D

func _initialize() -> void:
	build.call_deferred()

func group(parent: Node, title: String) -> Node3D:
	var node := Node3D.new()
	node.name = title
	parent.add_child(node, true)
	return node

func material(title: String, color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.resource_name = title
	mat.albedo_color = color
	mat.roughness = 0.95
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mats[title] = mat
	return mat

func mesh_node(parent: Node, title: String, mesh: Mesh, at: Vector3, solid: bool = false) -> Node3D:
	var node: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		node = body
	else:
		node = Node3D.new()
	node.name = title
	parent.add_child(node, true)
	node.position = at
	var visual := MeshInstance3D.new()
	visual.name = "Visuals"
	visual.mesh = mesh
	node.add_child(visual)
	if solid:
		var shape := CollisionShape3D.new()
		shape.name = "Collision"
		if mesh is BoxMesh:
			var box := BoxShape3D.new()
			box.size = mesh.size
			shape.shape = box
		elif mesh is CylinderMesh:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = maxf(mesh.top_radius, mesh.bottom_radius)
			cylinder.height = mesh.height
			shape.shape = cylinder
		else:
			shape.shape = mesh.create_trimesh_shape()
		node.add_child(shape)
	return node

func box(parent: Node, title: String, at: Vector3, size: Vector3, mat: Material, solid: bool = false) -> Node3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	return mesh_node(parent, title, mesh, at, solid)

func cylinder(parent: Node, title: String, at: Vector3, radius: float, height: float, mat: Material, solid: bool = false) -> Node3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	mesh.material = mat
	return mesh_node(parent, title, mesh, at, solid)

func beam(parent: Node, title: String, a: Vector3, b: Vector3, width: float, mat: Material, solid: bool = false) -> Node3D:
	var node := box(parent, title, (a+b)*0.5, Vector3(width, width, a.distance_to(b)+0.025), mat, solid)
	node.look_at_from_position(node.position, b, Vector3.UP if absf((b-a).normalized().y) < 0.99 else Vector3.FORWARD)
	return node

func point(radius: float, angle: float, y: float = 0.0) -> Vector3:
	return Vector3(sin(angle)*radius, y, cos(angle)*radius)

func sign_at(parent: Node, title: String, text: String, at: Vector3, yaw: float, color: Color = Color(0.77,0.91,0.85), size: int = 28) -> void:
	var label := Label3D.new()
	label.name = title
	label.text = text
	label.position = at
	label.rotation.y = yaw
	label.pixel_size = 0.0035
	label.font_size = size
	label.outline_size = 3
	label.modulate = color
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	parent.add_child(label, true)

func light_at(parent: Node, title: String, at: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.name = title
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.shadow_enabled = false
	parent.add_child(light, true)

func own_tree(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		# Preserve the contents of reusable scenes as instances.
		if child.scene_file_path.is_empty():
			own_tree(child, owner_node)

func save_scene(node: Node, path: String) -> PackedScene:
	own_tree(node, node)
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	return load(path) as PackedScene

func instance(parent: Node, kind: String, title: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var node: Node3D = modules[kind].instantiate()
	node.name = title
	parent.add_child(node, true)
	node.position = at
	node.rotation.y = yaw
	return node

func make_modules() -> void:
	var node := Node3D.new()
	node.name = "DoorFrame"
	box(node,"LeftJamb",Vector3(-0.83,1.2,0),Vector3(0.16,2.4,0.32),mats.metal)
	box(node,"RightJamb",Vector3(0.83,1.2,0),Vector3(0.16,2.4,0.32),mats.metal)
	box(node,"Lintel",Vector3(0,2.48,0),Vector3(1.82,0.16,0.32),mats.metal)
	box(node,"StatusStrip",Vector3(0,2.5,-0.17),Vector3(1.2,0.035,0.02),mats.green_light)
	modules.door = save_scene(node,MODULES+"door_frame.tscn")
	node.free()
	node = Node3D.new()
	node.name = "SupplyCrate"
	box(node,"Body",Vector3(0,0.38,0),Vector3(0.85,0.76,0.7),mats.crate,true)
	box(node,"Lid",Vector3(0,0.78,0),Vector3(0.9,0.08,0.75),mats.metal)
	for x: float in [-0.29,0.29]:
		box(node,"Band",Vector3(x,0.38,0),Vector3(0.045,0.78,0.72),mats.metal)
	sign_at(node,"InventoryTag","SEEDS / 04",Vector3(0,0.46,0.357),0,Color(0.86,0.91,0.76),18)
	modules.crate = save_scene(node,MODULES+"supply_crate.tscn")
	node.free()
	node = Node3D.new()
	node.name = "StorageShelf"
	# A single enclosing collider keeps the player clear of the small shelf parts.
	var body := StaticBody3D.new()
	body.name = "SolidFootprint"
	body.collision_mask = 0
	node.add_child(body)
	var shape := CollisionShape3D.new()
	var footprint := BoxShape3D.new()
	footprint.size = Vector3(2.2,2.2,0.75)
	shape.shape = footprint
	shape.position.y = 1.1
	body.add_child(shape)
	for x: float in [-1.02,1.02]:
		for z: float in [-0.32,0.32]:
			box(node,"Upright",Vector3(x,1.1,z),Vector3(0.09,2.2,0.09),mats.metal)
	for y: float in [0.12,0.83,1.54,2.18]:
		box(node,"Shelf",Vector3(0,y,0),Vector3(2.2,0.07,0.75),mats.panel)
	for y: float in [0.16,0.87,1.58]:
		for x: float in [-0.65,0,0.65]:
			box(node,"Canister",Vector3(x,y+0.21,0),Vector3(0.44,0.42,0.47),mats.crate)
	modules.shelf = save_scene(node,MODULES+"storage_shelf.tscn")
	node.free()
	node = Node3D.new()
	node.name = "Workstation"
	box(node,"Cabinet",Vector3(-0.7,0.44,0),Vector3(0.52,0.88,0.85),mats.panel,true)
	box(node,"Leg",Vector3(0.8,0.44,0),Vector3(0.12,0.88,0.75),mats.metal,true)
	box(node,"Worktop",Vector3(0,0.94,0),Vector3(2.0,0.12,1),mats.panel,true)
	box(node,"ScreenFrame",Vector3(0,1.36,-0.28),Vector3(0.87,0.55,0.12),mats.metal)
	box(node,"Display",Vector3(0,1.36,-0.211),Vector3(0.74,0.42,0.015),mats.screen)
	for i: int in range(3):
		box(node,"DisplayLine",Vector3(-0.1,1.47-i*0.08,-0.2),Vector3(0.4-i*0.08,0.015,0.01),mats.cold_light)
	box(node,"Keys",Vector3(0,1.02,0.19),Vector3(0.65,0.04,0.24),mats.metal)
	modules.desk = save_scene(node,MODULES+"workstation.tscn")
	node.free()
	node = Node3D.new()
	node.name = "WaterTank"
	cylinder(node,"Tank",Vector3(0,1.0,0),0.55,1.8,mats.tank,true)
	for y: float in [0.18,1.76]:
		cylinder(node,"Collar",Vector3(0,y,0),0.58,0.12,mats.metal)
	box(node,"Gauge",Vector3(0,1.06,0.55),Vector3(0.15,0.75,0.04),mats.screen)
	box(node,"FillLevel",Vector3(0,0.96,0.58),Vector3(0.06,0.43,0.02),mats.cold_light)
	modules.tank = save_scene(node,MODULES+"water_tank.tscn")
	node.free()

func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	# Godot uses clockwise front faces; keep upper surfaces facing +Y.
	for v: Vector3 in [a,c,b]:
		st.set_uv(Vector2(v.x,v.z)*0.25)
		st.add_vertex(v)

func slab(parent: Node, title: String, inner: float, outer: float, start: float, end: float, y: float, thickness: float, mat: Material, sections: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	st.set_material(mat)
	for i: int in range(sections):
		var a := lerpf(start,end,float(i)/sections)
		var b := lerpf(start,end,float(i+1)/sections)
		var p := point(inner,a,y)
		var q := point(outer,a,y)
		var r := point(outer,b,y)
		var s := point(inner,b,y)
		triangle(st,p,q,r)
		triangle(st,p,r,s)
		triangle(st,p-Vector3.UP*thickness,r-Vector3.UP*thickness,q-Vector3.UP*thickness)
		triangle(st,p-Vector3.UP*thickness,s-Vector3.UP*thickness,r-Vector3.UP*thickness)
		for pair: Array in [[p,q],[q,r],[r,s],[s,p]]:
			var u: Vector3 = pair[0]
			var v: Vector3 = pair[1]
			triangle(st,u,v-Vector3.UP*thickness,v)
			triangle(st,u,u-Vector3.UP*thickness,v-Vector3.UP*thickness)
	st.generate_normals()
	mesh_node(parent,title,st.commit(),Vector3.ZERO,true)

func wall(parent: Node, title: String, a: Vector3, b: Vector3, kind: String = "solid") -> void:
	var segment := group(parent,title)
	segment.position = (a+b)*0.5
	# Local +Z is toward the exterior for clockwise station polygons.
	segment.rotation.y = atan2(-(b-a).z,(b-a).x)
	var width := a.distance_to(b)+0.035
	if kind == "door":
		var side := (width-1.82)*0.5
		for x: float in [-1,1]:
			box(segment,"WallPier",Vector3(x*(0.91+side*0.5),HEIGHT*0.5,0),Vector3(side,HEIGHT,0.18),mats.panel,true)
		box(segment,"DoorHeader",Vector3(0,(HEIGHT+2.4)*0.5,0),Vector3(1.82,HEIGHT-2.4,0.18),mats.panel,true)
		instance(segment,"door","Frame",Vector3.ZERO)
	elif kind == "window":
		box(segment,"Sill",Vector3(0,0.52,0),Vector3(width,1.04,0.18),mats.panel,true)
		box(segment,"Header",Vector3(0,2.96,0),Vector3(width,0.38,0.18),mats.panel,true)
		for x: float in [-1,1]:
			box(segment,"WindowMullion",Vector3(x*(width*0.5-0.065),1.9,0),Vector3(0.13,1.76,0.24),mats.metal,true)
		box(segment,"Glazing",Vector3(0,1.9,0),Vector3(width-0.2,1.74,0.045),mats.glass,true)
		for y: float in [1.06,2.77]:
			box(segment,"Rail",Vector3(0,y,0),Vector3(width,0.09,0.24),mats.metal)
	else:
		box(segment,"Panel",Vector3(0,HEIGHT*0.5,0),Vector3(width,HEIGHT,0.18),mats.panel,true)
		box(segment,"Wainscot",Vector3(0,0.38,-0.105),Vector3(width,0.1,0.03),mats.metal)
	box(segment,"TopFrame",Vector3(0,HEIGHT-0.045,0),Vector3(width,0.09,0.25),mats.metal)

func make_greenhouse() -> void:
	var garden := group(world,"Greenhouse")
	slab(garden,"Floor",0,R_GARDEN,0,TAU,0,0.24,mats.floor,24)
	var roof := group(garden,"Dome")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	st.set_material(mats.glass)
	var radii := [R_GARDEN,4.6,2.65,0.0]
	var levels := [HEIGHT,4.55,5.5,5.9]
	for i: int in range(24):
		var a := TAU*i/24
		var b := TAU*(i+1)/24
		var open: bool = i in [5,6,17,18]
		if open:
			# Two adjacent facets form a clear 2.74 m entrance with no threshold.
			box(garden,"EntranceHeader",(point(R_GARDEN,a)+point(R_GARDEN,b))*0.5+Vector3.UP*2.78,Vector3(point(R_GARDEN,a).distance_to(point(R_GARDEN,b))+0.04,0.74,0.18),mats.metal,true).rotation.y = (a+b)*0.5
		else:
			wall(garden,"GlazedBay%02d" % i,point(R_GARDEN,a),point(R_GARDEN,b),"window")
		for j: int in range(3):
			var p := point(radii[j],a,levels[j])
			var q := point(radii[j],b,levels[j])
			var r := point(radii[j+1],b,levels[j+1])
			var s := point(radii[j+1],a,levels[j+1])
			triangle(st,p,q,r)
			triangle(st,p,r,s)
			if i % 2 == 0:
				beam(roof,"Rib",p,s,0.09,mats.metal)
			if j < 2:
				beam(roof,"Ring",p,q,0.075,mats.metal)
	st.generate_normals()
	mesh_node(roof,"GlassCanopy",st.commit(),Vector3.ZERO,true)
	cylinder(roof,"Crown",Vector3(0,5.9,0),0.28,0.16,mats.metal)
	var beds := group(world,"PlantingSlots")
	var planting: PackedScene = load("res://scenes/planting_slot/planting_slot.tscn")
	for i: int in range(6):
		var bed: Node3D = planting.instantiate()
		bed.name = "Slot%d" % (i+1)
		bed.slot_number = i+1
		bed.show_plant = i == 3
		beds.add_child(bed)
		bed.position = Vector3((i%3-1)*3.05,0,(-1 if i<3 else 1)*1.9)
		# Keep the editor-only sample plant visible when this tool rebuilds the scene.
		bed.get_node("Visuals/Plants/Adult").visible = i == 3
		sign_at(garden,"BedNumber","0%d" % (i+1),bed.position+Vector3(0,0.6,0.86),0,Color(0.73,0.9,0.67),23)
	for x: float in [-2.7,2.7]:
		light_at(garden,"GrowLight",Vector3(x,2.75,0),Color(0.77,1,0.82),1.4,7.4)
		box(garden,"GrowLuminaire",Vector3(x,3.17,0),Vector3(0.22,0.1,3.2),mats.green_light)
	for x: float in [-1,1]:
		# The entrance axes are +/-X. Keep the central cross aisle free.
		sign_at(garden,"AtriumSign","О Р А Н Ж Е Р Е Я",Vector3(x*5.1,2.75,0),x*PI/2,Color(0.67,0.94,0.73),24)

func room_props(room: Node3D, index: int) -> void:
	match index:
		0:
			box(room,"BunkFrame",Vector3(-2.6,0.27,10.4),Vector3(1.45,0.54,2.3),mats.metal,true)
			box(room,"Mattress",Vector3(-2.6,0.59,10.4),Vector3(1.37,0.17,2.15),mats.warm,true)
			box(room,"Pillow",Vector3(-2.6,0.74,11.1),Vector3(1.02,0.16,0.45),mats.panel)
			instance(room,"desk","PersonalDesk",Vector3(2.3,0,10.4),PI)
			box(room,"Locker",Vector3(3.8,1.05,9.3),Vector3(1.1,2.1,0.8),mats.panel,true)
			box(room,"LockerHandle",Vector3(3.6,1.1,8.88),Vector3(0.05,0.32,0.06),mats.metal)
			cylinder(room,"PetBedRim",Vector3(0.2,0.12,11.3),0.65,0.24,mats.warm,true)
			cylinder(room,"PetCushion",Vector3(0.2,0.25,11.3),0.52,0.05,mats.fabric)
		1:
			box(room,"KitchenUnit",Vector3(-2.3,0.48,10.7),Vector3(2.6,0.96,0.85),mats.panel,true)
			box(room,"Counter",Vector3(-2.3,1.01,10.7),Vector3(2.72,0.1,0.94),mats.metal)
			for x: float in [-2.9,-1.8]:
				cylinder(room,"CookingPlate",Vector3(x,1.08,10.7),0.24,0.025,mats.screen)
			box(room,"FoodCabinet",Vector3(2.7,1.0,10.7),Vector3(1.65,2.0,0.85),mats.crate,true)
			box(room,"DiningTable",Vector3(0,0.76,9.6),Vector3(1.4,0.12,0.9),mats.warm,true)
			box(room,"TablePedestal",Vector3(0,0.35,9.6),Vector3(0.45,0.7,0.45),mats.metal,true)
			instance(room,"tank","DrinkingWater",Vector3(3.7,0,8.8))
			sign_at(room,"WaterLabel","H₂O / ПИТЬЕВАЯ",Vector3(3.7,2.05,8.8),PI,Color(0.7,0.9,1),19)
		2:
			instance(room,"desk","ResearchTerminal",Vector3(-2.3,0,10.5),PI)
			box(room,"SampleBench",Vector3(2.1,0.49,10.5),Vector3(2.0,0.98,1.1),mats.panel,true)
			cylinder(room,"SpecimenPot",Vector3(2.1,1.15,10.5),0.3,0.3,mats.crate)
			cylinder(room,"SpecimenStem",Vector3(2.1,1.54,10.5),0.045,0.5,mats.leaf)
			for side: float in [-1,1]:
				box(room,"SpecimenLeaf",Vector3(2.1+side*0.16,1.62,10.5),Vector3(0.35,0.06,0.19),mats.leaf).rotation.z = side*0.35
			box(room,"SampleHood",Vector3(2.1,1.72,10.5),Vector3(0.95,1.4,0.8),mats.glass)
			box(room,"HoodTop",Vector3(2.1,2.43,10.5),Vector3(1.05,0.12,0.9),mats.cold_light)
			sign_at(room,"LabLabel","ОБРАЗЕЦ / 001",Vector3(2.1,0.69,9.93),PI,Color(0.65,0.86,1),20)
		3:
			instance(room,"shelf","SeedShelf",Vector3(-2.7,0,10.5))
			instance(room,"shelf","SoilShelf",Vector3(2.7,0,10.5))
			instance(room,"crate","SeedCrate",Vector3(-3.7,0,8.7))
			instance(room,"crate","SoilCrate",Vector3(3.7,0,8.7))
			instance(room,"crate","StackedCrate",Vector3(3.7,0.83,8.7))
			box(room,"ToolBoard",Vector3(0,1.45,11.9),Vector3(1.5,1.1,0.1),mats.metal)
			for x: float in [-0.45,0,0.45]:
				box(room,"ToolHandle",Vector3(x,1.4,11.8),Vector3(0.065,0.6,0.065),mats.warm)
				box(room,"ToolHead",Vector3(x,1.75,11.8),Vector3(0.24,0.17,0.06),mats.panel)
		4:
			for x: float in [-2.7,-1.3]:
				instance(room,"tank","WaterReservoir",Vector3(x,0,10.4))
			instance(room,"shelf","AirFilters",Vector3(2.6,0,10.4))
			box(room,"ElectricalPanel",Vector3(0.6,1.6,11.7),Vector3(1.4,1.3,0.3),mats.metal,true)
			for i: int in range(5):
				box(room,"Breaker",Vector3(0.12+i*0.24,1.62,11.52),Vector3(0.09,0.25,0.05),mats.green_light if i<4 else mats.warm)
			for x: float in [-3.2,-2.85]:
				beam(room,"ServicePipe",Vector3(x,2.6,8.5),Vector3(x,2.6,10.8),0.12,mats.tank)
				beam(room,"PipeRiser",Vector3(x,0.3,10.8),Vector3(x,2.6,10.8),0.12,mats.tank)
		5:
			instance(room,"desk","CommsTerminal",Vector3(2.7,0,9.9),PI)
			box(room,"SuitAlcove",Vector3(-2.7,1.2,10.3),Vector3(1.55,2.4,0.9),mats.metal,true)
			box(room,"SuitTorso",Vector3(-2.7,1.38,9.78),Vector3(0.63,0.8,0.38),mats.panel)
			cylinder(room,"Helmet",Vector3(-2.7,2.02,9.78),0.3,0.4,mats.panel)
			box(room,"Visor",Vector3(-2.7,2.04,9.47),Vector3(0.4,0.18,0.05),mats.screen)
			for x: float in [-2.9,-2.5]:
				box(room,"SuitLeg",Vector3(x,0.65,9.78),Vector3(0.24,0.7,0.28),mats.panel)
			# Recessed door leaves communicate an open lock, without automation.
			for x: float in [-1,1]:
				box(room,"ParkedInnerDoor",Vector3(x*1.45,1.15,7.7),Vector3(0.5,2.3,0.08),mats.tank)
			sign_at(room,"AirlockProtocol","ШЛЮЗ 06 / ВЫХОД НА ПОВЕРХНОСТЬ",Vector3(0,2.7,9.0),PI,Color(1,0.76,0.4),22)

func make_rooms() -> void:
	var rooms := group(world,"Rooms")
	var corridor := group(world,"RingCorridor")
	slab(corridor,"ContinuousFloor",R_GARDEN,R_HALL,0,TAU,0,0.24,mats.floor,24)
	var roof := group(corridor,"Roof")
	slab(roof,"FlatRoof",R_GARDEN-0.03,R_HALL+0.04,0,TAU,3.38,0.23,mats.roof,24)
	var names := ["LivingQuarters","Kitchen","Laboratory","Storage","Utilities","Airlock"]
	var labels := ["01 / ЖИЛАЯ КАЮТА","02 / КУХНЯ И ПРОВИЗИЯ","03 / ЛАБОРАТОРИЯ","04 / СКЛАД","05 / ТЕХНИЧЕСКИЙ ОТСЕК","06 / ШЛЮЗ И СВЯЗЬ"]
	for index: int in range(6):
		var room := group(rooms,names[index])
		room.rotation.y = index*PI/3
		room.set_meta("purpose",labels[index])
		var start := -PI/6
		var end := PI/6
		slab(room,"Floor",R_HALL,R_OUTER,start,end,0,0.24,mats.floor,4)
		var room_roof := group(room,"Roof")
		slab(room_roof,"FlatRoof",R_HALL-0.03,R_OUTER+0.03,start,end,3.38,0.23,mats.roof,4)
		for i: int in range(4):
			var a := start+i*PI/12
			var b := a+PI/12
			wall(room,"HallPartition%02d" % i,point(R_HALL,a),point(R_HALL,b),"door" if i==1 else "solid")
			wall(room,"OuterHull%02d" % i,point(R_OUTER,a),point(R_OUTER,b),"door" if index==5 and i==1 else ("window" if i in [1,2] else "solid"))
		# One radial partition per sector, shared with the next room.
		wall(room,"RadialPartition",point(R_HALL,end),point(R_OUTER,end))
		var door_center := (point(R_HALL,-PI/12)+point(R_HALL,0))*0.5
		sign_at(room,"RoomSign",labels[index],door_center+Vector3(0,2.79,-0.15),PI-PI/24,Color(0.77,0.91,0.85),22)
		box(room,"CeilingStrip",Vector3(0,3.1,9.7),Vector3(3.2,0.045,0.16),mats.cold_light if index==2 else mats.warm_light)
		light_at(room,"RoomLight",Vector3(0,2.65,9.65),Color(0.69,0.85,1) if index==2 else (Color(1,0.83,0.65) if index in [0,1] else Color(0.82,0.9,0.94)),1.65,6.5)
		room_props(room,index)
		var angle := index*PI/3
		var at := point(6.65,angle,2.7)
		light_at(corridor,"HallLight",at,Color(0.76,0.88,0.88),0.85,4.8)
		var luminaire := box(corridor,"HallLuminaire",point(6.65,angle,3.1),Vector3(1.45,0.045,0.16),mats.cold_light)
		luminaire.rotation.y = angle
		# Navigation bars are visual only and never catch the player's capsule.
		for i: int in range(4):
			var a := angle-PI/6+i*PI/12
			beam(corridor,"FloorGuide",point(5.75,a,0.012),point(5.75,a+PI/12,0.012),0.035,mats.green_light)
		var waypoint := Marker3D.new()
		waypoint.name = names[index]+"Entry"
		world.get_node("Waypoints").add_child(waypoint)
		waypoint.position = point(9.0,angle-PI/24,0.02)

func make_exterior() -> void:
	var exterior := group(world,"Exterior")
	var terrain := FastNoiseLite.new()
	terrain.seed = 7104
	terrain.frequency = 0.085
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	st.set_material(mats.ground)
	var craters := [Vector3(-20,0,-18),Vector3(20,0,13),Vector3(-14,0,25),Vector3(26,0,-22)]
	for x: int in range(-26,26):
		for z: int in range(-26,26):
			var corners: Array[Vector3] = []
			for d: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var v := Vector3((x+d.x)*2,0,(z+d.y)*2)
				var distance := Vector2(v.x,v.z).length()
				v.y = -0.45+terrain.get_noise_2d(v.x,v.z)*1.4*smoothstep(16,30,distance)
				for crater: Vector3 in craters:
					var dist := Vector2(v.x-crater.x,v.z-crater.z).length()
					v.y += 0.5*exp(-pow((dist-3.5)/1.0,2))-0.9*exp(-pow(dist/2.6,2))
				corners.append(v)
			triangle(st,corners[0],corners[2],corners[1])
			triangle(st,corners[0],corners[3],corners[2])
	st.generate_normals()
	mesh_node(exterior,"FiniteRegolith",st.commit(),Vector3.ZERO,true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i: int in range(58):
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(0.18,0.7)
		mesh.height = mesh.radius*1.5
		mesh.radial_segments = 5
		mesh.rings = 2
		mesh.material = mats.rock
		var at := point(rng.randf_range(17,40),rng.randf_range(0,TAU),-0.3)
		var rock := mesh_node(exterior,"Rock%02d" % i,mesh,at,true)
		rock.rotation = Vector3(rng.randf(),rng.randf()*TAU,rng.randf())
	# The lock is in sector 5, one facet to the left of its centre.
	var angle := 5*PI/3-PI/24
	var ramp := group(exterior,"AirlockRamp")
	ramp.position = point(R_OUTER*cos(PI/24),angle)
	ramp.rotation.y = angle
	box(ramp,"Landing",Vector3(0,-0.12,0.45),Vector3(2.1,0.24,1.1),mats.metal,true)
	# A wedge joins the landing and ground exactly, with no vertical box lip.
	var ramp_surface := SurfaceTool.new()
	ramp_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	ramp_surface.set_smooth_group(-1)
	ramp_surface.set_material(mats.metal)
	var near_left := Vector3(-1.05,0,1)
	var near_right := Vector3(1.05,0,1)
	var far_right := Vector3(1.05,-0.45,3.6)
	var far_left := Vector3(-1.05,-0.45,3.6)
	triangle(ramp_surface,near_left,far_right,near_right)
	triangle(ramp_surface,near_left,far_left,far_right)
	var down := Vector3(0,0.18,0)
	triangle(ramp_surface,near_left-down,near_right-down,far_right-down)
	triangle(ramp_surface,near_left-down,far_right-down,far_left-down)
	for edge: Array in [[near_left,near_right],[near_right,far_right],[far_right,far_left],[far_left,near_left]]:
		triangle(ramp_surface,edge[0],edge[1],edge[1]-down)
		triangle(ramp_surface,edge[0],edge[1]-down,edge[0]-down)
	ramp_surface.generate_normals()
	mesh_node(ramp,"Ramp",ramp_surface.commit(),Vector3.ZERO,true)
	for x: float in [-1.02,1.02]:
		beam(ramp,"GuardRail",Vector3(x,0.8,0),Vector3(x,0.35,3),0.07,mats.metal)
		beam(ramp,"RailPost",Vector3(x,0,0.1),Vector3(x,0.8,0.1),0.07,mats.metal)
	var sky_nodes := group(exterior,"Starfield")
	# Bake a single star mesh: unlike GPU-only MultiMesh buffers it also saves
	# reliably when authoring with Godot's headless dummy RenderingServer.
	var star_surface := SurfaceTool.new()
	star_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	star_surface.set_material(mats.star)
	for i: int in range(620):
		var direction := Vector3(rng.randf_range(-1,1),rng.randf_range(-0.15,1),rng.randf_range(-1,1)).normalized()
		var size := rng.randf_range(0.09,0.2)
		var center := direction*88
		var a := center+Vector3(-size,-size,-size)
		var b := center+Vector3(size,-size,size)
		var c := center+Vector3(-size,size,size)
		var d := center+Vector3(size,size,-size)
		triangle(star_surface,a,b,c)
		triangle(star_surface,a,d,b)
		triangle(star_surface,a,c,d)
		triangle(star_surface,b,d,c)
	star_surface.generate_normals()
	var stars := mesh_node(sky_nodes,"Stars",star_surface.commit(),Vector3.ZERO)
	stars.get_node("Visuals").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Exterior identification, shallow roof service units and landing feet.
	sign_at(exterior,"StationName","SELENE / 01\nLUNAR BOTANICAL STATION",Vector3(0,2.0,12.65),0,Color(0.9,0.92,0.83),29)
	for index: int in range(6):
		var angle_leg := index*PI/3
		cylinder(exterior,"FoundationFoot",point(10.8,angle_leg,-0.32),0.5,0.32,mats.metal,true)
		var unit := box(exterior,"RoofServiceUnit",point(10.2,angle_leg,3.65),Vector3(1.4,0.55,0.9),mats.metal)
		unit.rotation.y = angle_leg

func build() -> void:
	DirAccess.make_dir_recursive_absolute(MODULES)
	for name: String in ["station_floor","station_wall","station_metal","station_fabric","lunar_ground"]:
		mats[name.trim_prefix("station_")] = load("res://assets/materials/"+name+".tres")
	mats.ground = mats.lunar_ground
	mats.panel = mats.wall
	material("roof",Color(0.31,0.36,0.38))
	material("crate",Color(0.47,0.46,0.34))
	material("tank",Color(0.36,0.52,0.55))
	material("warm",Color(0.64,0.43,0.28))
	material("leaf",Color(0.31,0.57,0.32))
	material("rock",Color(0.33,0.34,0.36))
	material("screen",Color(0.035,0.13,0.15),true)
	material("green_light",Color(0.43,0.78,0.52),true)
	material("cold_light",Color(0.65,0.85,0.9),true)
	material("warm_light",Color(0.9,0.83,0.65),true)
	material("star",Color(0.88,0.9,0.94),true)
	var glass := material("glass",Color(0.36,0.57,0.59,0.13))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Static shared materials remain replaceable independently of the scene.
	DirAccess.make_dir_recursive_absolute("res://assets/materials/station")
	for key: String in mats:
		if mats[key].resource_path.is_empty():
			var path := "res://assets/materials/station/"+key+".tres"
			assert(ResourceSaver.save(mats[key],path) == OK)
			mats[key] = load(path)
	make_modules()
	world = Node3D.new()
	world.name = "LunarStation"
	group(world,"Waypoints")
	make_greenhouse()
	make_rooms()
	make_exterior()
	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.001,0.002,0.004)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.65,0.72,0.78)
	settings.ambient_light_energy = 0.65
	settings.reflected_light_source = 2
	environment.environment = settings
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-32,-38,0)
	sun.light_color = Color(1,0.94,0.83)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90
	world.add_child(sun)
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	player.name = "Player"
	world.add_child(player)
	player.position = Vector3(-0.8,0.02,9.0)
	player.rotation.y = 0
	var views := group(world,"PreviewCameras")
	for data: Array in [["Exterior",Vector3(23,13,26),Vector3(0,1.2,0)],["Greenhouse",Vector3(4.6,1.8,0),Vector3(-1,1.6,0)],["Plan",Vector3(0,36,0.01),Vector3.ZERO]]:
		var camera := Camera3D.new()
		camera.name = data[0]
		views.add_child(camera)
		camera.far = 200
		if data[0] == "Exterior":
			camera.fov = 50
		camera.position = data[1]
		camera.look_at_from_position(camera.position,data[2])
		if data[0] == "Plan":
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = 29
	save_scene(world,"res://scenes/greenhouse/greenhouse_world.tscn")
	print("Station saved: editable nodes, reusable props, six existing planting slots.")
	world.free()
	quit()
