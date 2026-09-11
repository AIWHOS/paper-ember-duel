extends Node3D

var actor
var camera: Camera3D
var animator=preload("res://scripts/纸烬决斗_动作控制_20260910.gd").new()
var builder=preload("res://scripts/纸烬决斗_场景构建_20260910.gd").new()
var kind="骑士"
var clock=0.0
var height=1.35
var bones=[]

func _ready():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--asset="):kind=arg.trim_prefix("--asset=")
	if kind=="道具":
		height=1.8;actor=Node3D.new();add_child(actor)
		for pair in [["课桌",-1.6],["木椅",0.0],["木箱",1.4]]:builder.prop(actor,pair[0],Vector3(pair[1],0,0),0)
	else:
		height=1.35 if kind=="骑士" else 5.3
		actor=preload("res://scripts/纸烬决斗_角色构建_20260910.gd").new().make(kind);add_child(actor)
		var sk=animator.skeleton(actor)
		var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color(.35,.8,.92,.65);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.no_depth_test=true
		for i in range(sk.get_bone_count()):
			if sk.get_bone_parent(i)<0:continue
			var node=MeshInstance3D.new();var mesh=CylinderMesh.new();mesh.top_radius=height*.003;mesh.bottom_radius=height*.003;mesh.height=.1;mesh.radial_segments=6;node.mesh=mesh;node.material_override=material;add_child(node);bones.append({"node":node,"i":i})
	var floor_material=StandardMaterial3D.new();floor_material.albedo_color=Color(.12,.13,.14);floor_material.roughness=.9
	builder.box(self,Vector3(0,-.04,0),Vector3(height*8,.06,height*8),floor_material)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.10,.12,.14);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.7,.76,.8);env.environment.ambient_light_energy=.55;env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;add_child(env)
	for pair in [[Vector3(-2,3,3),.55],[Vector3(3,2,1),.30],[Vector3(0,3,-2),.55]]:
		var light=OmniLight3D.new();add_child(light);light.position=pair[0]*height;light.omni_range=height*10;light.light_energy=pair[1];light.omni_attenuation=.8;light.shadow_enabled=true
	camera=Camera3D.new();add_child(camera);camera.current=true;camera.fov=38;camera.near=.03
	camera.position=Vector3(.4,height*.70,height*2.25);camera.look_at(Vector3(0,height*.5,0))
	if kind=="道具":camera.position=Vector3(3.4,2.8,5.5);camera.look_at(Vector3(0,.6,0))

func _process(dt):
	clock+=dt
	if kind=="道具":
		camera.position=Vector3(sin(clock*.18)*5.5,2.8,cos(clock*.18)*5.5);camera.look_at(Vector3(0,.6,0));return
	actor.rotation.y=clock*TAU/12
	if kind=="骑士":animator.update_hero(actor,{"clock":clock,"moving":clock>6,"anim_attack":fmod(clock,.7) if clock>3 and clock<6 else 0.0,"heavy_attack":true,"charging":false,"dodging":false},dt)
	else:animator.update_giant(actor,{"clock":clock,"boss_state":"windup_slam" if clock>3 and clock<5 else "idle","boss_clock":clampf((clock-3)*.6,0,1.1),"active_hand":0,"broken":[false,false],"victory":false},dt)
	actor.rotation.y=clock*TAU/12
	var sk=animator.skeleton(actor)
	for b in bones:
		b.node.visible=clock>3 and clock<9
		var a=sk.to_global(sk.get_bone_global_pose(sk.get_bone_parent(b.i)).origin);var z=sk.to_global(sk.get_bone_global_pose(b.i).origin);var delta=z-a
		b.node.position=(a+z)*.5;b.node.mesh.height=maxf(.001,delta.length())
		if delta.length()>.001:b.node.quaternion=Quaternion(Vector3.UP,delta.normalized())

func _exit_tree():animator.skeletons.clear();builder.mats.clear()
