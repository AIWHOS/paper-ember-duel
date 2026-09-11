extends RefCounted

var rng := RandomNumberGenerator.new()
var mats: Dictionary = {}

func material(key: String, color: Color, roughness: float = 0.9, glow: float = 0.0) -> Material:
	if mats.has(key): return mats[key]
	if key.begins_with("tile") or key in ["wood","wall","trim","base"]:
		var sm:=ShaderMaterial.new()
		sm.shader=load("res://assets/纸烬决斗_场景材质_20260910.gdshader")
		sm.set_shader_parameter("base_color",color.darkened(.16))
		sm.set_shader_parameter("wood",key in ["wood","trim"])
		sm.set_shader_parameter("grain_strength",.18)
		mats[key]=sm
		return sm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	mats[key] = m
	return m

func box(parent: Node3D, at: Vector3, size: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.position = at
	if solid:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var cs := BoxShape3D.new()
		cs.size = size
		collider.shape = cs
		body.add_child(collider)
		mesh.add_child(body)
	return mesh

func line(parent: Node3D, a: Vector3, b: Vector3, width: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = width
	c.bottom_radius = width
	c.height = a.distance_to(b)
	c.radial_segments = 6
	m.mesh = c
	m.material_override = mat
	parent.add_child(m)
	m.position = (a+b)*0.5
	var direction := (b-a).normalized()
	if absf(direction.dot(Vector3.UP)) < 0.999:
		m.quaternion = Quaternion(Vector3.UP, direction)
	return m

func build(parent: Node3D) -> void:
	rng.seed = 93742
	var floor_m := material("base", Color("514a3e"))
	box(parent, Vector3(0,-0.18,0),Vector3(24,0.4,22),floor_m,true)
	for x in range(-11,12,2):
		for z in range(-10,11,2):
			var tone := rng.randf_range(0.0,0.11)
			var tile := material("tile%d" % int(tone*120),Color(0.29+tone,0.265+tone,0.22+tone))
			var m := box(parent,Vector3(x,0.005+rng.randf_range(-0.008,0.008),z),Vector3(1.97,0.05,1.96),tile)
			m.rotation.y=rng.randf_range(-0.006,0.006)
	var wall := material("wall",Color("4c4940"))
	var wood := material("wood",Color("282219"))
	var trim := material("trim",Color("66523a"))
	box(parent,Vector3(0,5,-10.5),Vector3(24,10,0.6),wall,true)
	box(parent,Vector3(11.7,5,0),Vector3(.5,10,22),wall,true)
	box(parent,Vector3(-11.7,.8,0),Vector3(.5,1.6,22),wall,true)
	# Collision perimeter remains readable even beyond the camera's view.
	box(parent,Vector3(0,1.0,10.8),Vector3(24,2,.3),wall,true)
	for z in [-9.0,-4.5,0.0,4.5,9.0]:
		for x in [-11.3,11.2]:
			box(parent,Vector3(x,4.5,z),Vector3(.48,9,.55),wood)
		box(parent,Vector3(0,8.5,z),Vector3(23,.45,.6),wood)
		for y in [2.0,4.0,6.0,8.0]:
			box(parent,Vector3(-11.55,y,z+2.0),Vector3(.18,.12,4.0),trim)
			box(parent,Vector3(-11.55,y+0.8,z+1.1),Vector3(.14,1.65,.12),trim)
	var window := material("daylight",Color("e0c9a2"),1,0.7)
	for z in [-6.5,-2.0,2.5,7.0]:
		box(parent,Vector3(-11.85,4.7,z),Vector3(.02,6,3.8),window)
	box(parent,Vector3(0,4.4,-10.08),Vector3(9.6,4.5,.22),wood)
	box(parent,Vector3(0,4.4,-9.93),Vector3(9.15,4.05,.05),material("board",Color("242d29")))
	var chalk := material("chalk",Color("b4ae98"))
	box(parent,Vector3(0,7.15,-9.3),Vector3(23,.22,1.5),wood)
	for x in range(-11,12,2):
		box(parent,Vector3(x,7.65,-8.65),Vector3(.07,1.0,.07),trim)
		books(parent,Vector3(x,7.28,-9.4),rng.randi_range(3,6))
	for y in [7.4,8.1]:box(parent,Vector3(0,y,-8.65),Vector3(23,.07,.07),wood)
	for i in range(64):
		var a:=TAU*i/64.0
		var b:=TAU*(i+1)/64.0
		line(parent,Vector3(sin(a)*1.05,5.05+cos(a)*1.05,-9.88),Vector3(sin(b)*1.05,5.05+cos(b)*1.05,-9.88),.017,chalk)
	for i in range(12):
		var a:=TAU*i/12
		line(parent,Vector3(sin(a)*1.18,5.05+cos(a)*1.18,-9.87),Vector3(sin(a)*1.46,5.05+cos(a)*1.46,-9.87),.014,chalk)
	var peaks: Array[Vector3]=[Vector3(-4,2.8,-9.86),Vector3(-2.9,3.9,-9.86),Vector3(-1.6,2.7,-9.86),Vector3(.4,3.7,-9.86),Vector3(1.5,2.7,-9.86),Vector3(3.4,4,-9.86),Vector3(4.2,2.7,-9.86)]
	for i in range(peaks.size()-1):line(parent,peaks[i],peaks[i+1],.018,chalk)
	# Peripheral desks and library shelves leave a broad clear arena.
	for side in [-1,1]:
		for z in [-7,-3,1,5,8]:
			desk(parent,Vector3(side*9.3,0,z),trim,wood)
		for z in [-7,-1,5]:
			shelf(parent,Vector3(side*10.95,0,z),wood,side)
	for x in [-8.0,8.0]:
		for z in [-9.0,8.0]: books(parent,Vector3(x,.05,z),9)
	for p in [Vector3(-7.7,0,6.8),Vector3(7.6,0,7.3),Vector3(8.2,0,-8.2),Vector3(-8.3,0,-8.0)]:
		prop(parent,"木箱",p,rng.randf_range(-.3,.3))
	var paper:=material("paper",Color("c6b58f"))
	for i in range(85):
		var pos:=Vector3(rng.randf_range(-10.5,10.5),.042,rng.randf_range(-9.8,9.7))
		if absf(pos.x)<5 and absf(pos.z)<6 and i%3!=0:continue
		var m:=box(parent,pos,Vector3(rng.randf_range(.12,.35),.005,rng.randf_range(.2,.48)),paper)
		m.rotation.y=rng.randf_range(-PI,PI)
	for i in range(12):
		var p:=Vector3(rng.randf_range(-10.8,10.8),rng.randf_range(6.4,8),rng.randf_range(-9,4))
		var m:=box(parent,p,Vector3(.7,.85,.01),paper)
		m.rotation=Vector3(.08,rng.randf_range(-.7,.7),rng.randf_range(-.3,.3))
		line(parent,p+Vector3(0,.4,0),Vector3(p.x,8.5,p.z),.006,wood)
	# Broken chalk circles: aesthetic markings, distinct from live orange warnings.
	for r in [5.1,7.0]:
		for i in range(70):
			if i%9==0:continue
			var a:=TAU*i/70.0
			var b:=TAU*(i+.8)/70.0
			line(parent,Vector3(cos(a)*r,.041,sin(a)*r-1),Vector3(cos(b)*r,.041,sin(b)*r-1),.015,chalk)
	var sun:=DirectionalLight3D.new()
	parent.add_child(sun)
	sun.rotation_degrees=Vector3(-36,-62,0)
	sun.light_color=Color("fff0d7")
	sun.light_energy=.92
	sun.shadow_enabled=true
	sun.directional_shadow_max_distance=42
	var fill:=OmniLight3D.new()
	parent.add_child(fill)
	fill.position=Vector3(0,5,4)
	fill.omni_range=20
	fill.light_color=Color("b8c7ce")
	fill.light_energy=.45
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("292a26")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("b4ac91")
	env.environment.ambient_light_energy=.34
	env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.environment.fog_enabled=true
	env.environment.fog_light_color=Color("6f706b")
	env.environment.fog_density=.006
	parent.add_child(env)
	batch_static_meshes(parent)

func desk(parent: Node3D, at: Vector3, top: Material, legs: Material) -> void:
	if ResourceLoader.exists("res://assets/props/纸烬决斗_课桌游戏道具_20260910.glb"):
		var angle=rng.randf_range(-.28,.28)
		prop(parent,"课桌",at,angle)
		prop(parent,"木椅",at+Vector3(.1,0,1.03).rotated(Vector3.UP,angle),angle+PI+rng.randf_range(-.12,.12))
		books(parent,at+Vector3(.25,1.09,-.1),rng.randi_range(2,5))
		return
	var root:=Node3D.new()
	parent.add_child(root)
	root.position=at
	root.rotation.y=rng.randf_range(-.28,.28)
	box(root,Vector3(0,1.2,0),Vector3(1.55,.14,1),top,true)
	for x in [-.6,.6]:
		for z in [-.35,.35]:box(root,Vector3(x,.6,z),Vector3(.08,1.2,.08),legs)
	box(root,Vector3(0,.68,.92),Vector3(.62,.1,.6),top)
	box(root,Vector3(0,1.1,1.15),Vector3(.62,.8,.07),top)
	for x in [-.24,.24]:
		for z in [.7,1.15]:box(root,Vector3(x,.34,z),Vector3(.07,.68,.07),legs)
	books(root,Vector3(.2,1.3,0),rng.randi_range(2,6))

func books(parent: Node3D, at: Vector3, count: int) -> void:
	for i in range(count):
		var color:=Color.from_hsv(rng.randf_range(.07,.15),rng.randf_range(.15,.42),rng.randf_range(.2,.42))
		var m:=box(parent,at+Vector3(rng.randf_range(-.13,.13),i*.105,0),Vector3(.45,.09,.65),material("book%d"%rng.randi_range(0,20),color))
		m.rotation.y=rng.randf_range(-.4,.4)

func shelf(parent: Node3D, at: Vector3, wood: Material, side: int) -> void:
	var root:=Node3D.new()
	parent.add_child(root)
	root.position=at
	root.rotation.y=PI*.5*side
	box(root,Vector3(0,1.8,0),Vector3(2.4,3.6,.12),wood)
	for x in [-1.2,1.2]:box(root,Vector3(x,1.8,.3),Vector3(.1,3.6,.7),wood)
	for y in [0.0,1.2,2.4,3.6]:
		box(root,Vector3(0,y,.3),Vector3(2.5,.1,.7),wood)
		if y<3:
			for x in [-.85,0.0,.8]:books(root,Vector3(x,y+.08,.3),rng.randi_range(4,8))

func prop(parent: Node3D,kind: String,at: Vector3,angle: float) -> Node3D:
	var path="res://assets/props/纸烬决斗_%s游戏道具_20260910.glb"%kind
	if not ResourceLoader.exists(path):return null
	var ob=load(path).instantiate();parent.add_child(ob);ob.position=at;ob.rotation.y=angle
	for child in ob.find_children("*","MeshInstance3D",true,false):
		for surface in range(child.mesh.get_surface_count()):
			var mat=child.mesh.surface_get_material(surface)
			if mat is StandardMaterial3D:
				var key="prop_"+kind+str(surface)
				if not mats.has(key):
					var tinted=mat.duplicate();tinted.albedo_color=Color(.43,.43,.40);tinted.roughness=.94;mats[key]=tinted
				child.set_surface_override_material(surface,mats[key])
	var dims={"课桌":Vector3(1.75,1.05,.85),"木椅":Vector3(.65,1.25,.65),"木箱":Vector3(.9,.9,.9)}[kind]
	var body=StaticBody3D.new();ob.add_child(body);var cs=CollisionShape3D.new();var shape=BoxShape3D.new();shape.size=dims;cs.shape=shape;cs.position.y=dims.y*.5;body.add_child(cs)
	return ob

func batch_static_meshes(parent: Node3D) -> void:
	var groups={}
	for child in parent.find_children("*","MeshInstance3D",true,false):
		if child.mesh==null or child.mesh.get_surface_count()!=1:continue
		var material=child.get_active_material(0)
		if material==null:continue
		var mesh=child.mesh;var key=str(material.get_instance_id());var transform=parent.global_transform.affine_inverse()*child.global_transform
		if mesh is BoxMesh:
			key+="box";transform.basis*=Basis.from_scale(mesh.size)
			mesh=BoxMesh.new();mesh.size=Vector3.ONE
		elif mesh is CylinderMesh and is_equal_approx(mesh.top_radius,mesh.bottom_radius):
			key+="cylinder";transform.basis*=Basis.from_scale(Vector3(mesh.top_radius,mesh.height,mesh.top_radius))
			mesh=CylinderMesh.new();mesh.top_radius=1;mesh.bottom_radius=1;mesh.height=1;mesh.radial_segments=6
		else:key+=str(mesh.get_instance_id())
		if not groups.has(key):groups[key]={"mesh":mesh,"material":material,"transforms":[]}
		groups[key].transforms.append(transform)
		child.visible=false
	for data in groups.values():
		var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=data.mesh;mm.instance_count=data.transforms.size()
		for i in range(mm.instance_count):mm.set_instance_transform(i,data.transforms[i])
		var instance=MultiMeshInstance3D.new();instance.multimesh=mm;instance.material_override=data.material;parent.add_child(instance)
