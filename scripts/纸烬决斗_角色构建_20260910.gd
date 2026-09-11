extends RefCounted

const Builder=preload("res://scripts/纸烬决斗_场景构建_20260910.gd")
var b=Builder.new()

func make(kind: String) -> Node3D:
	var path: String="res://assets/纸烬决斗_%s游戏模型_20260910.glb"%kind
	if ResourceLoader.exists(path):
		var scene=load(path).instantiate()
		for child in scene.find_children("*","MeshInstance3D",true,false):
			for surface in range(child.mesh.get_surface_count()):
				var mat=child.mesh.surface_get_material(surface)
				if mat is StandardMaterial3D:
					var tinted=mat.duplicate();tinted.albedo_color*=Color(.80,.78,.74);child.set_surface_override_material(surface,tinted)
		return scene
	return placeholder(kind)

func placeholder(kind: String) -> Node3D:
	var root:=Node3D.new()
	var stone=b.material("stone",Color("292824"))
	var paper=b.material("ivory",Color("c9b894"))
	if kind=="骑士":
		b.box(root,Vector3(0,.73,0),Vector3(.4,.46,.29),paper)
		b.box(root,Vector3(0,1.1,0),Vector3(.55,.45,.45),paper)
		b.box(root,Vector3(0,1.03,.231),Vector3(.39,.12,.01),stone)
		for side in [-1,1]:
			var ear=b.box(root,Vector3(side*.22,1.4,0),Vector3(.12,.22,.23),paper)
			ear.rotation.z=-side*.22
			b.box(root,Vector3(side*.14,.28,0),Vector3(.12,.5,.12),stone)
			b.box(root,Vector3(side*.14,.08,.08),Vector3(.16,.13,.28),stone)
			var arm:=Node3D.new();arm.name="LeftArm" if side==-1 else "RightArm";root.add_child(arm);arm.position=Vector3(side*.29,.89,0)
			b.box(arm,Vector3(side*.05,-.22,0),Vector3(.10,.45,.13),stone)
	else:
		b.box(root,Vector3(0,2.9,0),Vector3(2.6,2.5,1.2),stone)
		b.box(root,Vector3(0,4.45,.10),Vector3(.78,.8,.7),stone)
		for side in [-1,1]:
			b.box(root,Vector3(side*.67,.9,0),Vector3(.78,1.8,.85),stone)
			b.box(root,Vector3(side*.67,.16,.2),Vector3(1.0,.3,1.2),stone)
			var arm:=Node3D.new();arm.name="LeftArm" if side==-1 else "RightArm";root.add_child(arm);arm.position=Vector3(side*1.6,3.8,0)
			b.box(arm,Vector3(side*.25,-1,0),Vector3(1.0,2.2,1),stone)
			b.box(arm,Vector3(side*.25,-2.0,.22),Vector3(1.3,.9,1.25),stone)
			b.box(arm,Vector3(side*.25,-1.9,.88),Vector3(.92,.65,.05),paper)
		for i in range(8):
			var m=b.box(root,Vector3((i%4-1.5)*.64,2.3+floori(i/4)*1.3,.65),Vector3(.7,.85,.035),paper)
			m.rotation.z=(i%3-1)*.18
		var glow=b.material("core",Color("ef692e"),.7,2.0)
		var core:=MeshInstance3D.new();var sphere:=SphereMesh.new();sphere.radius=.65;sphere.height=1.3;core.mesh=sphere;core.material_override=glow;root.add_child(core);core.position=Vector3(0,2.9,.7)
	return root
