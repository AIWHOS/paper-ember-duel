extends RefCounted

var skeletons={}
var crouch=0.0
var core_blend=0.0
var run_phase=0.0
var run_blend=0.0

func skeleton(model):
	var id=model.get_instance_id()
	if not skeletons.has(id):skeletons[id]=model.find_child("Skeleton3D",true,false)
	return skeletons[id]

func rotate_bone(sk,name,rotation):
	var i=sk.find_bone(name)
	if i>=0:sk.set_bone_pose_rotation(i,sk.get_bone_rest(i).basis.get_rotation_quaternion()*Quaternion.from_euler(rotation))

func global_bone(sk,i,origin,basis):
	var parent=sk.get_bone_parent(i)
	var transform=Transform3D(basis,origin)
	if parent>=0:transform=sk.get_bone_global_pose(parent).affine_inverse()*transform
	sk.set_bone_pose_position(i,transform.origin)
	sk.set_bone_pose_rotation(i,transform.basis.orthonormalized().get_rotation_quaternion())

func limb(sk,upper,lower,end,target,pole):
	var a=sk.find_bone(upper);var b=sk.find_bone(lower);var c=sk.find_bone(end)
	if min(a,min(b,c))<0:return
	var ra=sk.get_bone_global_rest(a);var rb=sk.get_bone_global_rest(b);var rc=sk.get_bone_global_rest(c)
	var root=sk.get_bone_global_pose(a).origin
	var l1=ra.origin.distance_to(rb.origin);var l2=rb.origin.distance_to(rc.origin)
	var delta=target-root;var dist=clampf(delta.length(),absf(l1-l2)+.002,l1+l2-.002)
	var direction=delta.normalized();var bend=(pole-direction*direction.dot(pole)).normalized()
	var co=clampf((l1*l1+dist*dist-l2*l2)/(2*l1*dist),-1,1)
	var elbow=root+direction*(co*l1)+bend*(sqrt(maxf(0,1-co*co))*l1)
	var final_target=root+direction*dist
	var qa=Quaternion((rb.origin-ra.origin).normalized(),(elbow-root).normalized())
	var qb=Quaternion((rc.origin-rb.origin).normalized(),(final_target-elbow).normalized())
	global_bone(sk,a,root,Basis(qa)*ra.basis)
	global_bone(sk,b,elbow,Basis(qb)*rb.basis)
	global_bone(sk,c,final_target,rc.basis)

func world_rotation(sk,name,rotation):
	var i=sk.find_bone(name)
	if i>=0:
		var current=sk.get_bone_global_pose(i)
		global_bone(sk,i,current.origin,Basis.from_euler(rotation)*sk.get_bone_global_rest(i).basis)

func weapon_points(model):
	var sk=skeleton(model)
	if not sk:return []
	var hand=sk.find_bone("RightHand")
	var skin=sk.get_bone_global_pose(hand)*sk.get_bone_global_rest(hand).affine_inverse()
	# Actual blade root and tip from the editable Blender model, converted Z-up to Y-up.
	return [sk.to_global(skin*Vector3(-.3476,.425,.109)),sk.to_global(skin*Vector3(-.3476,.1131,.5189))]

func update_hero(model,p,dt):
	var sk=skeleton(model)
	if not sk:return
	sk.reset_bone_poses()
	var speed=p.get("speed",3.4 if p.moving else 0.0)
	var attacking=p.anim_attack>0
	var rolling=p.get("dodge_time",0.0)>0
	var duration=p.get("attack_duration",.90 if p.heavy_attack else .52)
	var progress=clampf(1.0-p.anim_attack/duration,0.0,1.0)
	var move_weight=clampf(speed/3.4,0,1) if p.moving and not rolling else 0.0
	run_blend=move_toward(run_blend,move_weight,dt*9)
	run_phase+=dt*(speed/.40)*.40*TAU
	var phase=run_phase
	var pelvis=sk.find_bone("Pelvis")
	var bob=(-.075+.025*sin(phase*2))*run_blend
	sk.set_bone_pose_position(pelvis,sk.get_bone_rest(pelvis).origin+Vector3(0,bob,0))
	world_rotation(sk,"Chest",Vector3(.14*run_blend,.10*sin(phase)*run_blend,.06*cos(phase)*run_blend))
	world_rotation(sk,"Head",Vector3(-.04*run_blend,0,-.025*cos(phase)*run_blend))
	for pair in [["Left",0.0],["Right",.5]]:
		var side=pair[0];var u=fposmod(phase/TAU+pair[1],1.0)
		var foot=sk.get_bone_global_rest(sk.find_bone(side+"Foot")).origin
		var z=0.0;var lift=0.0;var pitch=0.0
		if u<.4:
			z=lerpf(.20,-.20,u/.4)
			pitch=-.45*smoothstep(.22,.4,u)
		else:
			var swing=(u-.4)/.6
			z=lerpf(-.20,.20,smoothstep(0,1,swing))
			lift=sin(swing*PI)*.23
			pitch=.30*sin(swing*PI)
		foot+=Vector3(0,lift,z)*run_blend
		limb(sk,side+"Leg",side+"Shin",side+"Foot",foot,Vector3(0,0,1))
		world_rotation(sk,side+"Foot",Vector3(pitch*run_blend,0,0))
	# Bent elbows and opposite arm/leg travel form a complete running silhouette.
	var wrist_r=Vector3(-.31,.61,.11-.14*cos(phase)*run_blend)
	var wrist_l=Vector3(.31,.64,.10+.15*cos(phase)*run_blend)
	var sword_rotation=Vector3(-.35,0,-.12)
	if attacking or p.charging:
		var t=progress
		if p.charging:t=.25
		var strike=smoothstep(.32,.62,t)
		var recovery=smoothstep(.72,1.0,t)
		if p.heavy_attack or p.charging:
			strike=smoothstep(.42,.64,t);recovery=smoothstep(.74,1,t)
			var wind=smoothstep(0,.18,p.get("charge_amount",.18)) if p.charging else smoothstep(0,.25,t)
			wrist_r=wrist_r.lerp(Vector3(-.42,.97,.10),wind)
			wrist_r=wrist_r.lerp(Vector3(-.33,.68,.25),strike).lerp(Vector3(-.31,.61,.11),recovery)
			sword_rotation=sword_rotation.lerp(Vector3(-2.1,-.15,0),wind).lerp(Vector3(.75,-.15,0),strike).lerp(Vector3(-.35,0,-.12),recovery)
			world_rotation(sk,"Chest",Vector3(lerpf(-.16,.38,strike)*(1-recovery),-.18*(1-strike),0))
			wrist_l=Vector3(.34,.78,.10).lerp(Vector3(.28,.67,.20),strike)
		else:
			var reverse=p.get("combo",1)%2==0
			var from=Vector3(-.40,.86,-.02) if not reverse else Vector3(-.04,.83,.23)
			var to=Vector3(.025,.69,.20) if not reverse else Vector3(-.45,.74,.10)
			var wind=smoothstep(0,.23,t)
			wrist_r=wrist_r.lerp(from,wind).lerp(to,strike).lerp(Vector3(-.31,.61,.11),recovery)
			var start_yaw=1.25 if reverse else -1.25
			var end_yaw=-1.25 if reverse else 1.25
			sword_rotation=sword_rotation.lerp(Vector3(-.9,start_yaw,0),wind).lerp(Vector3(.12,end_yaw,0),strike).lerp(Vector3(-.35,0,-.12),recovery)
			world_rotation(sk,"Chest",Vector3(.10,lerpf(-.32,.35,strike)*(1-recovery)*( -1 if reverse else 1),0))
			wrist_l=Vector3(.32,.72,.11)
		if run_blend<.2:
			for pair in [["Left",1],["Right",-1]]:
				var foot=sk.get_bone_global_rest(sk.find_bone(pair[0]+"Foot")).origin+Vector3(pair[1]*.025,0,pair[1]*.055)
				limb(sk,pair[0]+"Leg",pair[0]+"Shin",pair[0]+"Foot",foot,Vector3(0,0,1))
	limb(sk,"RightArm","RightForearm","RightHand",wrist_r,Vector3(-1,0,-.4))
	limb(sk,"LeftArm","LeftForearm","LeftHand",wrist_l,Vector3(1,0,-.3))
	world_rotation(sk,"RightHand",sword_rotation)
	world_rotation(sk,"LeftHand",Vector3(-.7,0,.25))
	rotate_bone(sk,"CapeRoot",Vector3(.05*sin(p.clock*5)+.32*run_blend,0,.07*sin(phase)*run_blend))
	rotate_bone(sk,"CapeTip",Vector3(.10*sin(p.clock*8)+.40*run_blend,0,.09*sin(phase-.6)*run_blend))
	var facing=p.get("facing_yaw",model.rotation.y)
	model.basis=Basis(Vector3.UP,facing);model.position=Vector3.ZERO
	if rolling:
		var t=clampf(1.0-p.dodge_time/p.get("dodge_duration",.58),0,1)
		var tuck=smoothstep(0,.16,t)*(1-smoothstep(.80,1,t))
		sk.set_bone_pose_position(pelvis,sk.get_bone_rest(pelvis).origin-Vector3.UP*.055*tuck)
		world_rotation(sk,"Chest",Vector3(.60*tuck,0,0));world_rotation(sk,"Head",Vector3(.3*tuck,0,0))
		for pair in [["Left",1],["Right",-1]]:
			var side=pair[0];var sign=pair[1]
			var foot=sk.get_bone_global_rest(sk.find_bone(side+"Foot")).origin.lerp(Vector3(sign*.13,.26,.08),tuck)
			limb(sk,side+"Leg",side+"Shin",side+"Foot",foot,Vector3(0,.35,1))
			var tucked_hand=Vector3(-.40,.70,.13) if side=="Right" else Vector3(.22,.70,.18)
			var hand=sk.get_bone_global_rest(sk.find_bone(side+"Hand")).origin.lerp(tucked_hand,tuck)
			limb(sk,side+"Arm",side+"Forearm",side+"Hand",hand,Vector3(sign,0,1))
		world_rotation(sk,"RightHand",Vector3(-.8,-1.2,0))
		rotate_bone(sk,"CapeRoot",Vector3(.65*tuck,0,0));rotate_bone(sk,"CapeTip",Vector3(.9*tuck,0,0))
		var rotation=TAU*smoothstep(.10,.88,t)
		model.basis=Basis(Vector3.UP,p.get("dodge_yaw",facing))*Basis(Vector3.RIGHT,rotation)
		var pivot=Vector3(0,.62,0)
		model.position=pivot-model.basis*pivot+Vector3.UP*(sin(PI*t)*.16)

func update_giant(model,p,dt):
	var sk=skeleton(model)
	if not sk:return
	sk.reset_bone_poses()
	var state=p.boss_state;var t=p.boss_clock
	var dropping=0.0
	if state=="windup_slam":dropping=smoothstep(.92,1.15,t)
	if state=="recover_slam":dropping=1-smoothstep(2.25,2.7,t)
	if state=="open" or p.victory:dropping=.85
	if state=="shock":dropping=1-smoothstep(.2,1.5,t)
	crouch=lerpf(crouch,dropping*.78,minf(1,dt*24))
	var pelvis=sk.find_bone("Pelvis");sk.set_bone_pose_position(pelvis,sk.get_bone_rest(pelvis).origin-Vector3.UP*crouch)
	rotate_bone(sk,"Chest",Vector3(.16*crouch,0,.01*sin(p.clock*1.5)))
	for pair in [["Right",-1,0],["Left",1,1]]:
		var side=pair[0];var sign=pair[1];var hand=pair[2]
		var foot=sk.get_bone_global_rest(sk.find_bone(side+"Foot")).origin
		limb(sk,side+"Leg",side+"Shin",side+"Foot",foot,Vector3(sign*.12,0,1))
		var wrist=sk.get_bone_global_rest(sk.find_bone(side+"Hand")).origin
		var high=Vector3(sign*2.20,4.8,1.1);var ground=Vector3(sign*2.34,.50,.35)
		if hand==p.active_hand:
			if state=="windup_slam":
				wrist=wrist.lerp(high,smoothstep(0,.72,t))
				wrist=wrist.lerp(ground,smoothstep(.92,1.15,t))
			elif state=="recover_slam":wrist=ground.lerp(wrist,smoothstep(2.25,2.7,t))
			elif state=="windup_sweep":wrist=wrist.lerp(Vector3(sign*3.3,1.8,.6),smoothstep(0,1,t))
			elif state=="sweep":wrist=Vector3(sign*3.3*cos(t*4.5),1.4,2.5*sin(t*4.5)+.8)
		if state=="windup_shock":wrist=wrist.lerp(high,smoothstep(0,1,t))
		if state=="shock":wrist=ground.lerp(wrist,smoothstep(.2,1.5,t))
		if state=="open" or p.victory:wrist=Vector3(sign*2.6,.65,.35)
		limb(sk,side+"Arm",side+"Forearm",side+"Hand",wrist,Vector3(sign,0,-.6))
		var armor=model.find_child(side+"FistArmor",true,false)
		if armor:armor.visible=not p.broken[hand]
	core_blend=lerpf(core_blend,1.0 if state=="open" else 0.0,minf(1,dt*4))
	var core=sk.find_bone("Core")
	if core>=0:
		var current=sk.get_bone_global_pose(core)
		global_bone(sk,core,current.origin.lerp(Vector3(0,1.55+sin(p.clock*3)*.035,1.4),core_blend),current.basis)
	var shell=model.find_child("CoreShell",true,false)
	if shell:shell.visible=not p.victory
	model.position=Vector3.ZERO;model.rotation=Vector3.ZERO
