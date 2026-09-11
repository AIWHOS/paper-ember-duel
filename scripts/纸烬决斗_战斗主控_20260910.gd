extends Node3D

const WorldBuilder=preload("res://scripts/纸烬决斗_场景构建_20260910.gd")
const ActorBuilder=preload("res://scripts/纸烬决斗_角色构建_20260910.gd")
const SAVE_ROOT="user://"
var builder=WorldBuilder.new()
var actors=ActorBuilder.new()
var animator=preload("res://scripts/纸烬决斗_动作控制_20260910.gd").new()
var hero: CharacterBody3D
var hero_model: Node3D
var giant: Node3D
var giant_model: Node3D
var sword: Node3D
var camera: Camera3D
var core_light: OmniLight3D
var world_root: Node3D
var effects: Array[Dictionary]=[]
var danger: Array[Dictionary]=[]
var state="menu"
var health=100.0
var core_health=300.0
var armor=[60.0,60.0]
var broken=[false,false]
var boss_state="idle"
var boss_clock=0.0
var boss_wait=1.5
var attack_step=0
var active_hand=0
var expose_hand=-1
var warning_position=Vector3.ZERO
var warning_mesh: Node3D
var core_open=0.0
var attack_cd=0.0
var dodge_cd=0.0
var dodge_time=0.0
var dodge_vec=Vector3.ZERO
var parry_time=0.0
var parry_cd=0.0
var hurt_invul=0.0
var anim_attack=0.0
var heavy_attack=false
var charging=0.0
var charge_down=false
var combo=0
var clock=0.0
var game_time=0.0
var shake=0.0
var shake_enabled=true
var yaw=0.0
var sensitivity=.002
var message_time=0.0
var hit_count=0
var dodge_count=0
var parry_count=0
var damage_events=0
var menu_layer: Control
var end_layer: Control
var pause_layer: Control
var hud: Control
var tip: Label
var state_label: Label
var hp_bar: ProgressBar
var core_bar: ProgressBar
var armor_labels: Array[Label]=[]
var elapsed_label: Label
var end_title: Label
var end_description: Label
var canvas_layer: CanvasLayer
var audio_players: Array[AudioStreamPlayer]=[]
var audio_cursor=0
var rng=RandomNumberGenerator.new()
var font: Font
var qa_mode=false
var demo_mode=false
var frame_counter=0
var screenshot_requested=false
var moving=false
var demo_end_clock=0.0
var qa_flow=false
const DODGE_DURATION=.58
var dodge_yaw=0.0
var facing_yaw=PI
var real_move_speed=0.0
var attack_duration=.52
var attack_elapsed=0.0
var attack_pending=false
var hit_pause=0.0
var trail_points: Array=[]
var trail_mesh: ImmediateMesh
var trail_node: MeshInstance3D
var charge_aura: Node3D
var footsteps=0.0

func _exit_tree() -> void:
	animator.skeletons.clear();builder.mats.clear();actors.b.mats.clear()
	for a in audio_players:
		if is_instance_valid(a):a.stop();a.stream=null
	audio_players.clear();effects.clear();danger.clear()

func _ready() -> void:
	DisplayServer.window_set_title("纸烬决斗")
	rng.seed=8883
	font=load("res://assets/纸烬决斗_中文字体_20260910.ttf")
	_setup_inputs()
	world_root=Node3D.new();world_root.name="Classroom";add_child(world_root)
	builder.build(world_root)
	_create_actors()
	_create_ui()
	_setup_motion_fx()
	for i in range(8):
		var a=AudioStreamPlayer.new();add_child(a);audio_players.append(a)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	qa_mode=OS.get_cmdline_user_args().has("--qa")
	demo_mode=OS.get_cmdline_user_args().has("--demo")
	qa_flow=OS.get_cmdline_user_args().has("--qa-flow")
	if qa_mode or demo_mode: start_game()
	if qa_mode:call_deferred("run_qa")
	print("PAPER_EMBER_READY | models:",ResourceLoader.exists("res://assets/纸烬决斗_骑士游戏模型_20260910.glb")," / ",ResourceLoader.exists("res://assets/纸烬决斗_巨像游戏模型_20260910.glb"))

func _setup_inputs() -> void:
	var keys={"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"dodge":KEY_SPACE,"parry":KEY_Q,"center":KEY_F,"pause":KEY_ESCAPE,"restart":KEY_R,"capture":KEY_F8}
	for action in keys:
		if not InputMap.has_action(action):InputMap.add_action(action)
		var e=InputEventKey.new();e.physical_keycode=keys[action];InputMap.action_add_event(action,e)
	for pair in [["light",MOUSE_BUTTON_LEFT],["heavy",MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(pair[0]):InputMap.add_action(pair[0])
		var e=InputEventMouseButton.new();e.button_index=pair[1];InputMap.action_add_event(pair[0],e)

func _create_actors() -> void:
	hero=CharacterBody3D.new();hero.name="PaperKnight";add_child(hero)
	var shape=CollisionShape3D.new();var capsule=CapsuleShape3D.new();capsule.radius=.22;capsule.height=1.15;shape.shape=capsule;shape.position.y=.575;hero.add_child(shape)
	hero_model=actors.make("骑士");hero.add_child(hero_model)
	sword=Node3D.new();hero_model.add_child(sword);sword.position=Vector3(-.4,.65,.1)
	sword.visible=not ResourceLoader.exists("res://assets/纸烬决斗_骑士游戏模型_20260910.glb")
	var blade=builder.box(sword,Vector3(0,-.26,.2),Vector3(.09,.65,.055),builder.material("sword",Color("302d28"),.5))
	blade.rotation.x=-.7
	builder.box(sword,Vector3(0,.05,0),Vector3(.23,.06,.09),builder.material("guard",Color("61543b")))
	giant=Node3D.new();giant.name="PaperGolem";add_child(giant);giant.position=Vector3(0,0,-3)
	giant_model=actors.make("巨像");giant.add_child(giant_model)
	core_light=OmniLight3D.new();giant.add_child(core_light);core_light.position=Vector3(0,2.8,.7);core_light.omni_range=5.5;core_light.light_color=Color("ff742e");core_light.light_energy=1.8
	camera=Camera3D.new();add_child(camera);camera.fov=56;camera.near=.08;camera.far=65;camera.position=Vector3(0,4.6,10.5);camera.look_at(Vector3(0,2,-2));camera.current=true
	hero.position=Vector3(0,.1,4.5)
	hero_model.rotation.y=PI

func panel_style(bg: Color, border: Color=Color("74644e")) -> StyleBoxFlat:
	var style=StyleBoxFlat.new();style.bg_color=bg;style.border_color=border
	style.set_border_width_all(1);style.set_corner_radius_all(4)
	style.content_margin_left=20;style.content_margin_right=20;style.content_margin_top=16;style.content_margin_bottom=16
	return style

func bar_style(color: Color) -> StyleBoxFlat:
	var s=StyleBoxFlat.new();s.bg_color=color;s.set_corner_radius_all(2);return s

func label(text: String,size: int,color: Color=Color("e7dcc1")) -> Label:
	var l=Label.new();l.text=text;l.add_theme_font_override("font",font);l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);return l

func button(text: String, action: Callable) -> Button:
	var b=Button.new();b.text=text;b.custom_minimum_size=Vector2(290,54);b.add_theme_font_override("font",font);b.add_theme_font_size_override("font_size",19)
	b.add_theme_color_override("font_color",Color("f2e6cb"));b.add_theme_stylebox_override("normal",panel_style(Color("44372a")));b.add_theme_stylebox_override("hover",panel_style(Color("795237"),Color("ddab6f")));b.add_theme_stylebox_override("pressed",panel_style(Color("3b2c23")))
	b.pressed.connect(action);return b

func overlay() -> Control:
	var c=Control.new();c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas_layer.add_child(c)
	var dark=ColorRect.new();dark.color=Color(0.03,.025,.018,.62);dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);c.add_child(dark)
	return c

func _create_ui() -> void:
	canvas_layer=CanvasLayer.new();add_child(canvas_layer)
	if OS.has_feature("movie"):canvas_layer.scale=Vector2.ONE*(4.0/3.0)
	hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;canvas_layer.add_child(hud)
	var top=VBoxContainer.new();top.position=Vector2(46,34);hud.add_child(top)
	top.add_child(label("纸 烬 决 斗",17,Color("bbae92")))
	top.add_child(label("折纸骑士",13,Color("a8997a")))
	hp_bar=ProgressBar.new();hp_bar.custom_minimum_size=Vector2(250,9);hp_bar.show_percentage=false;hp_bar.max_value=100;hp_bar.value=100
	hp_bar.add_theme_stylebox_override("background",bar_style(Color("342e24")));hp_bar.add_theme_stylebox_override("fill",bar_style(Color("cbb990")));top.add_child(hp_bar)
	var boss_ui=VBoxContainer.new();hud.add_child(boss_ui);boss_ui.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP);boss_ui.position=Vector2(450,34);boss_ui.size=Vector2(540,92)
	var title=label("焚卷巨像  /  THE FORGOTTEN",20);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;boss_ui.add_child(title)
	core_bar=ProgressBar.new();core_bar.custom_minimum_size=Vector2(540,10);core_bar.show_percentage=false;core_bar.max_value=300;core_bar.value=300;core_bar.add_theme_stylebox_override("background",bar_style(Color("37271e")));core_bar.add_theme_stylebox_override("fill",bar_style(Color("c86a3c")));boss_ui.add_child(core_bar)
	var armor_row=HBoxContainer.new();armor_row.alignment=BoxContainer.ALIGNMENT_CENTER;armor_row.add_theme_constant_override("separation",30);boss_ui.add_child(armor_row)
	for i in range(2):var l=label("◈  圆印纸甲" if i==0 else "三角纸甲  ◈",13);armor_row.add_child(l);armor_labels.append(l)
	state_label=label("第一阶段 · 诱导落拳，撕开纸甲",15,Color("bcad8a"));state_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;boss_ui.add_child(state_label)
	var bottom=VBoxContainer.new();hud.add_child(bottom);bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT);bottom.position=Vector2(46,804)
	bottom.add_child(label("WASD 移动   ·   鼠标左键 轻击   ·   右键蓄力 重击",14,Color("cec3aa")))
	bottom.add_child(label("空格 闪避   ·   Q 弹反   ·   F 镜头归中   ·   Esc 暂停",14,Color("9d927c")))
	tip=label("",24);tip.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hud.add_child(tip);tip.position=Vector2(250,700);tip.size=Vector2(940,40)
	elapsed_label=label("00:00",15,Color("b6a88d"));hud.add_child(elapsed_label);elapsed_label.position=Vector2(1310,42)
	menu_layer=overlay()
	var menu=VBoxContainer.new();menu_layer.add_child(menu);menu.position=Vector2(110,190);menu.add_theme_constant_override("separation",16)
	menu.add_child(label("P A P E R   &   E M B E R",14,Color("c19564")))
	menu.add_child(label("纸烬决斗",66))
	menu.add_child(label("一页未尽，余烬不息。",21,Color("bcad90")))
	var desc=label("踏入遗忘的教室。\n引出重拳，撕开纸甲，击碎燃烧的核心。",17,Color("a69b83"));desc.custom_minimum_size=Vector2(500,90);menu.add_child(desc)
	menu.add_child(button("进入教室",start_game))
	if not OS.has_feature("web"):menu.add_child(button("退出",func():get_tree().quit()))
	menu.add_child(label("单人竞技场  ·  键盘与鼠标",12,Color("8d826b")))
	end_layer=overlay();end_layer.hide()
	var end_box=VBoxContainer.new();end_layer.add_child(end_box);end_box.position=Vector2(465,235);end_box.add_theme_constant_override("separation",22)
	end_title=label("余烬已熄",48);end_box.add_child(end_title)
	end_description=label("",18);end_box.add_child(end_description)
	end_box.add_child(button("再次挑战",start_game));end_box.add_child(button("返回标题",back_to_menu))
	pause_layer=overlay();pause_layer.hide()
	var pause_box=VBoxContainer.new();pause_layer.add_child(pause_box);pause_box.position=Vector2(560,240);pause_box.add_theme_constant_override("separation",20);pause_box.add_child(label("片刻休息",38))
	pause_box.add_child(button("继续战斗",toggle_pause))
	var chk=CheckButton.new();chk.text="镜头震动";chk.button_pressed=true;chk.add_theme_font_override("font",font);chk.add_theme_font_size_override("font_size",18);chk.toggled.connect(func(v):shake_enabled=v);pause_box.add_child(chk)
	var slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.value=.75;slider.custom_minimum_size=Vector2(280,30);slider.value_changed.connect(func(v):AudioServer.set_bus_volume_db(0,linear_to_db(maxf(v,.001))));pause_box.add_child(label("音量",15));pause_box.add_child(slider)
	pause_box.add_child(button("重新开始",start_game));pause_box.add_child(button("返回标题",back_to_menu))
	hud.hide()

func start_game() -> void:
	for e in effects:if is_instance_valid(e.node):e.node.queue_free()
	effects.clear()
	for d in danger:if is_instance_valid(d.node):d.node.queue_free()
	danger.clear();clear_warning()
	health=100;core_health=300;armor=[60.0,60.0];broken=[false,false]
	boss_state="idle";boss_clock=0;boss_wait=2;attack_step=0;core_open=0;expose_hand=-1
	attack_cd=0;dodge_cd=0;dodge_time=0;parry_time=0;hurt_invul=0;charging=0;charge_down=false;parry_cd=0;anim_attack=0
	hero.position=Vector3(0,.1,4.5);hero.velocity=Vector3.ZERO;giant.position=Vector3(0,0,-3);giant.rotation=Vector3.ZERO;giant_model.position=Vector3.ZERO;giant_model.rotation=Vector3.ZERO
	attack_pending=false;attack_elapsed=0;hit_pause=0;trail_points.clear();facing_yaw=PI;real_move_speed=0;animator.run_blend=0;demo_end_clock=0
	game_time=0;hit_count=0;dodge_count=0;parry_count=0;damage_events=0;combo=0;yaw=0
	state="playing";menu_layer.hide();end_layer.hide();pause_layer.hide();hud.show()
	Input.mouse_mode=play_mouse_mode() if not qa_mode and not demo_mode else Input.MOUSE_MODE_VISIBLE
	message("先避开落拳，再攻击落地的纸甲",4)

func back_to_menu() -> void:
	state="menu";hud.hide();end_layer.hide();pause_layer.hide();menu_layer.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func toggle_pause() -> void:
	if state=="playing":state="paused";pause_layer.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	elif state=="paused":state="playing";pause_layer.hide();Input.mouse_mode=play_mouse_mode()

func play_mouse_mode() -> int:
	# Web uses relative motion within the canvas without requiring Pointer Lock.
	return Input.MOUSE_MODE_HIDDEN if OS.has_feature("web") else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):toggle_pause()
	if event.is_action_pressed("capture"):screenshot_requested=true
	if event.is_action_pressed("restart") and state in ["dead","victory"]:start_game()
	if state!="playing":return
	if event is InputEventMouseMotion and Input.mouse_mode in [Input.MOUSE_MODE_CAPTURED,Input.MOUSE_MODE_HIDDEN]:yaw=clampf(yaw-event.relative.x*sensitivity,-.9,.9)
	if event.is_action_pressed("center"):yaw=0
	if event.is_action_pressed("light"):attack(false)
	if event.is_action_pressed("heavy") and attack_cd<=0:charge_down=true;charging=0
	if event.is_action_released("heavy") and charge_down:attack(charging>.25);charge_down=false;charging=0
	if event.is_action_pressed("dodge"):dodge()
	if event.is_action_pressed("parry") and parry_cd<=0:
		parry_time=.23;parry_cd=.65;ring(hero.position,.48,Color("d7e4d4"),.25);sound("parry",.35)

func _physics_process(dt: float) -> void:
	clock+=dt;frame_counter+=1
	if demo_mode and state in ["victory","dead"]:
		demo_end_clock+=dt
		if demo_end_clock>3:get_tree().quit(0 if state=="victory" else 1)
	if hit_pause>0 and state=="playing":
		hit_pause=maxf(0,hit_pause-dt);update_effects(dt*.2);update_camera(dt);return
	if state=="playing":
		game_time+=dt
		attack_cd=maxf(0,attack_cd-dt);dodge_cd=maxf(0,dodge_cd-dt);dodge_time=maxf(0,dodge_time-dt);parry_time=maxf(0,parry_time-dt);parry_cd=maxf(0,parry_cd-dt);hurt_invul=maxf(0,hurt_invul-dt)
		if charge_down:charging=minf(1.3,charging+dt)
		var input=Input.get_vector("left","right","forward","back")
		var direction=Vector3(input.x,0,input.y).rotated(Vector3.UP,yaw)
		if demo_mode:direction=demo_direction()
		moving=direction.length()>.1
		var speed=3.4 if not charge_down else 1.3
		if anim_attack>0:speed*=.30
		if dodge_time>0:
			direction=dodge_vec
			var roll_t=1.0-dodge_time/DODGE_DURATION
			speed=2.0+6.4*sin(PI*roll_t)
		hero.velocity.x=direction.x*speed;hero.velocity.z=direction.z*speed
		if not hero.is_on_floor():hero.velocity.y-=20*dt
		else:hero.velocity.y=-.1
		hero.move_and_slide()
		hero.position.x=clampf(hero.position.x,-8.0,8.0);hero.position.z=clampf(hero.position.z,-8.5,8.8)
		var delta=hero.position-giant.position;delta.y=0
		if delta.length()<1.35:hero.position=giant.position+delta.normalized()*1.35+Vector3.UP*.03
		real_move_speed=Vector2(hero.get_real_velocity().x,hero.get_real_velocity().z).length()
		moving=real_move_speed>.15 and dodge_time<=0
		var aim=giant.position-hero.position
		if moving and anim_attack<=0 and not charge_down:aim=direction
		if dodge_time>0:aim=dodge_vec
		facing_yaw=lerp_angle(facing_yaw,atan2(aim.x,aim.z),minf(1,dt*18))
		update_attack(dt)
		footsteps+=dt*real_move_speed
		if moving and int(footsteps*5)!=int((footsteps-dt*real_move_speed)*5):foot_dust()
		update_boss(dt)
		update_danger(dt)
		if demo_mode:demo_driver(dt)
	if state!="paused":
		update_effects(dt)
		animate_models(dt)
		update_motion_fx(dt)
	update_camera(dt)
	update_hud(dt)
	if screenshot_requested:
		screenshot_requested=false;capture_frame()

func fist_position(hand: int) -> Vector3:
	return giant.to_global(Vector3(-2.34 if hand==0 else 2.34,.12,1.1))

func update_boss(dt: float) -> void:
	boss_clock+=dt
	if boss_state=="phase_shift":
		if boss_clock>1.5:
			boss_state="idle";boss_clock=0;boss_wait=.8
			attack_step=3 if core_health>100 else 4
		return
	if boss_state=="open":
		core_open-=dt
		if core_open<=0:
			armor=[60.0,60.0];broken=[false,false];boss_state="idle";boss_wait=2.0;boss_clock=0;message("纸甲重聚，再次寻找落拳的空隙",2.5)
		return
	if boss_state=="idle":
		var aim=hero.position-giant.position
		giant.rotation.y=lerp_angle(giant.rotation.y,atan2(aim.x,aim.z),dt*.8)
		if aim.length()>5.0:
			giant.position+=Vector3(aim.x,0,aim.z).normalized()*dt*.42
			giant.position.x=clampf(giant.position.x,-3.5,3.5);giant.position.z=clampf(giant.position.z,-5,2)
		boss_wait-=dt
		if boss_wait<=0:
			active_hand=attack_step%2
			var stage=1 if core_health>200 else (2 if core_health>100 else 3)
			var move="slam"
			if attack_step%4==2:move="sweep"
			if stage>=2 and attack_step%5==3:move="shock"
			if stage>=3 and attack_step%5==4:move="fire"
			begin_boss_attack(move)
	elif boss_state=="windup_slam" and boss_clock>=1.15:
		boss_state="recover_slam";boss_clock=0;expose_hand=active_hand;clear_warning();ring(warning_position,1.32,Color("f18842"),.5);burst(warning_position,16);shake=.45;sound("slam",.85)
		if distance_flat(hero.position,warning_position)<1.5:receive_damage(22,true)
	elif boss_state=="recover_slam":
		if boss_clock>=2.7:finish_boss_attack()
	elif boss_state=="windup_sweep" and boss_clock>=1.05:
		boss_state="sweep";boss_clock=0;clear_warning();sound("swing",.75)
	elif boss_state=="sweep":
		if boss_clock<.5 and distance_flat(hero.position,giant.position)<3.6 and hero.position.z>giant.position.z-.6:receive_damage(17,false)
		if boss_clock>.8:boss_state="recover_slam";boss_clock=0;expose_hand=active_hand
	elif boss_state=="windup_shock" and boss_clock>=1.4:
		boss_state="shock";boss_clock=0;clear_warning();shake=.6;sound("slam",.9)
	elif boss_state=="shock":
		var radius=boss_clock*7.0
		if int(boss_clock*60)%3==0:ring(giant.position,radius,Color("cf9460"),.15)
		var d=distance_flat(hero.position,giant.position)
		if absf(d-radius)<.35:receive_damage(20,false)
		if boss_clock>1.65:finish_boss_attack()
	elif boss_state=="windup_fire" and boss_clock>=1.4:
		boss_state="fire";boss_clock=0;clear_warning();sound("burn",.7)
		for i in range(5):
			var at=hero.position+Vector3(rng.randf_range(-3,3),0,rng.randf_range(-3,3));at.y=.07
			var n=make_ring(at,1.05,Color("d36029"));add_child(n)
			danger.append({"node":n,"position":at,"life":5.0,"delay":.8,"tick":0.0})
	elif boss_state=="fire" and boss_clock>1.3:finish_boss_attack()

func begin_boss_attack(move: String) -> void:
	boss_state="windup_"+move;boss_clock=0;expose_hand=-1
	warning_position=fist_position(active_hand)
	clear_warning()
	if move=="slam":warning_mesh=make_ring(warning_position,1.35,Color("ca6b35"))
	else:warning_mesh=make_ring(giant.position,3.4,Color("9c754b"))
	add_child(warning_mesh)
	sound("windup",.35)

func finish_boss_attack() -> void:
	boss_state="idle";boss_clock=0;boss_wait=.8;attack_step+=1;expose_hand=-1;clear_warning()

func attack(heavy: bool) -> void:
	if state!="playing" or attack_cd>0 or dodge_time>0:return
	heavy_attack=heavy;attack_duration=.90 if heavy else .52
	attack_cd=attack_duration;anim_attack=attack_duration;attack_elapsed=0;attack_pending=true
	combo=(combo+1)%2;trail_points.clear()
	var aim=giant.position-hero.position
	facing_yaw=atan2(aim.x,aim.z)

func update_attack(dt: float) -> void:
	if anim_attack<=0:return
	attack_elapsed+=dt;anim_attack=maxf(0,attack_duration-attack_elapsed)
	var contact=.54 if heavy_attack else .26
	if attack_pending and attack_elapsed>=contact:
		attack_pending=false
		sound("swing",.7 if heavy_attack else .4)
		strike_effect(heavy_attack)
		resolve_attack(heavy_attack)

func resolve_attack(heavy: bool) -> void:
	var power=38.0 if heavy else 17.0
	if boss_state=="open":
		var target=giant.to_global(Vector3(0,0,1.1))
		if distance_flat(hero.position,target)<2.35:
			var phase_floor=200.0 if core_health>200 else (100.0 if core_health>100 else 0.0)
			core_health=maxf(phase_floor,core_health-power);hit_count+=1;hit_pause=.065 if heavy else .025;shake=.20 if heavy else .08;burst(target+Vector3.UP*1.2,8);sound("hit",.65)
			if core_health<=0:end_game(true)
			elif core_health<=phase_floor:
				boss_state="phase_shift";boss_clock=0;core_open=0;armor=[60.0,60.0];broken=[false,false];expose_hand=-1;clear_warning()
				message("巨像苏醒 · 准备闪过震地波" if core_health==200 else "余烬狂怒 · 避开燃烧的纸页",3)
				ring(giant.position,3.0,Color("da7a45"),1.0);burst(giant.position+Vector3.UP*2,28)
			return
	if expose_hand>=0 and not broken[expose_hand]:
		var at=fist_position(expose_hand)
		if distance_flat(hero.position,at)<1.75:
			armor[expose_hand]=maxf(0,armor[expose_hand]-power);hit_count+=1;hit_pause=.065 if heavy else .025;burst(at+Vector3.UP*.4,8);shake=.13;sound("hit",.55)
			if armor[expose_hand]<=0:break_armor(expose_hand)
			return
	if distance_flat(hero.position,giant.position)<3.5:message("等待落拳，攻击拳背纸甲",1.0)

func break_armor(hand: int) -> void:
	broken[hand]=true;burst(fist_position(hand),24);sound("break",.8);message("纸甲撕裂",1.8)
	if broken[0] and broken[1]:
		boss_state="open";boss_clock=0;core_open=7.0;expose_hand=-1;clear_warning();shake=.3;message("核心脱离！靠近悬浮核心连续攻击",3);sound("break",1.0)

func dodge() -> void:
	if state!="playing" or dodge_cd>0 or dodge_time>0:return
	var input=Input.get_vector("left","right","forward","back")
	dodge_vec=Vector3(input.x,0,input.y).rotated(Vector3.UP,yaw)
	if dodge_vec.length()<.1:dodge_vec=(hero.position-giant.position).normalized();dodge_vec.y=0
	dodge_vec=dodge_vec.normalized();dodge_time=DODGE_DURATION;dodge_cd=.82;dodge_count+=1;sound("swing",.28)
	dodge_yaw=atan2(dodge_vec.x,dodge_vec.z)
	attack_pending=false;anim_attack=0;attack_cd=maxf(attack_cd,.2);charge_down=false;charging=0;trail_points.clear()
	foot_dust()

func receive_damage(amount: float, can_parry: bool) -> bool:
	if state!="playing" or hurt_invul>0:return false
	if dodge_time>.09 and dodge_time<DODGE_DURATION-.045:return false
	if can_parry and parry_time>0:
		parry_count+=1;hurt_invul=.35;ring(hero.position,1,Color("e7efdc"),.35);message("弹反成功",1.2);sound("parry",.9);armor[active_hand]=maxf(0,armor[active_hand]-28)
		if armor[active_hand]<=0:break_armor(active_hand)
		return false
	health=maxf(0,health-amount);hurt_invul=.65;damage_events+=1;shake=.4;sound("hurt",.55)
	if health<=0:end_game(false)
	return true

func end_game(won: bool) -> void:
	state="victory" if won else "dead";end_layer.show();pause_layer.hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	end_title.text="余烬已熄" if won else "纸页散落"
	end_description.text=("你让教室重新安静下来。" if won else "读懂落拳的节奏，再试一次。")+"\n\n用时 %02d:%02d  ·  命中 %d\n闪避 %d 次  ·  弹反 %d 次"%[int(game_time)/60,int(game_time)%60,hit_count,dodge_count,parry_count]
	if won:burst(giant.position+Vector3.UP*2,45);sound("break",1)
	if demo_mode:
		var f=FileAccess.open(SAVE_ROOT+"纸烬决斗_完整对战验证_20260910.json",FileAccess.WRITE)
		if f:f.store_string(JSON.stringify({"won":won,"health":health,"core_health":core_health,"seconds":game_time,"hits":hit_count,"dodges":dodge_count,"damage_events":damage_events,"movement":"normal CharacterBody3D movement and collision"},"  "));f.close()
		print("FULL_FIGHT_RESULT ",won," seconds=",game_time," health=",health)

func update_danger(dt: float) -> void:
	for i in range(danger.size()-1,-1,-1):
		var d=danger[i];d.delay-=dt;d.life-=dt;d.tick-=dt
		if d.delay<=0 and d.tick<=0:
			d.tick=.6
			if distance_flat(hero.position,d.position)<1.1:receive_damage(8,false)
		if d.life<=0:d.node.queue_free();danger.remove_at(i)

func make_ring(at: Vector3,radius: float,color: Color) -> Node3D:
	var root=Node3D.new();root.position=Vector3(at.x,maxf(.065,at.y),at.z)
	var mesh=MeshInstance3D.new();var torus=TorusMesh.new();torus.inner_radius=maxf(.01,radius-.025);torus.outer_radius=maxf(.035,radius+.025);torus.rings=40;torus.ring_segments=6;mesh.mesh=torus
	var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mesh.material_override=mat;root.add_child(mesh)
	return root

func ring(at: Vector3,radius: float,color: Color,life: float) -> void:
	var n=make_ring(at,radius,color);add_child(n);effects.append({"node":n,"life":life,"total":life,"velocity":Vector3.ZERO,"spin":Vector3.ZERO,"ring":true})

func burst(at: Vector3,count: int) -> void:
	for i in range(count):
		var m=builder.box(self,at+Vector3(0,.2,0),Vector3(rng.randf_range(.05,.15),.01,rng.randf_range(.08,.22)),builder.material("debris",Color("c7b795")))
		effects.append({"node":m,"life":rng.randf_range(.5,1.4),"total":1.4,"velocity":Vector3(rng.randf_range(-2,2),rng.randf_range(1,4),rng.randf_range(-2,2)),"spin":Vector3(rng.randf(),rng.randf(),rng.randf())*7,"ring":false})

func clear_warning() -> void:
	if is_instance_valid(warning_mesh):warning_mesh.queue_free()
	warning_mesh=null

func update_effects(dt: float) -> void:
	for i in range(effects.size()-1,-1,-1):
		var e=effects[i];e.life-=dt
		if e.life<=0 or not is_instance_valid(e.node):
			if is_instance_valid(e.node):e.node.queue_free()
			effects.remove_at(i);continue
		if e.get("pulse",false):
			e.node.scale=Vector3.ONE*lerpf(1.0,4.0,1-e.life/e.total)
			for child in e.node.get_children():
				if child is MeshInstance3D:child.material_override.albedo_color.a=maxf(0,e.life/e.total)
		elif e.ring:e.node.scale*=1+dt*.65
		else:
			e.velocity.y-=8*dt;e.node.position+=e.velocity*dt;e.node.rotation+=e.spin*dt
			if e.node.position.y<.06:e.node.position.y=.06;e.velocity=Vector3.ZERO
	if is_instance_valid(warning_mesh):warning_mesh.scale=Vector3.ONE*(1.0+sin(clock*8)*.025)

func pose(model: Node3D,bone: String,rotation: Vector3) -> void:
	var sk=model.find_child("Skeleton3D",true,false) as Skeleton3D
	if sk:
		var idx=sk.find_bone(bone)
		if idx>=0:sk.set_bone_pose_rotation(idx,sk.get_bone_rest(idx).basis.get_rotation_quaternion()*Quaternion.from_euler(rotation))
	else:
		var n=model.find_child(bone,true,false) as Node3D
		if n:n.rotation=rotation

func animate_models(dt: float) -> void:
	animator.update_hero(hero_model,{"clock":clock,"moving":moving and state=="playing","anim_attack":anim_attack,"heavy_attack":heavy_attack,"charging":charge_down,"charge_amount":charging,"dodging":dodge_time>0,"dodge_time":dodge_time,"dodge_duration":DODGE_DURATION,"dodge_yaw":dodge_yaw,"speed":real_move_speed,"facing_yaw":facing_yaw,"attack_duration":attack_duration,"combo":combo},dt)
	animator.update_giant(giant_model,{"boss_state":boss_state,"boss_clock":boss_clock,"clock":clock,"active_hand":active_hand,"broken":broken,"victory":state=="victory"},dt)
	core_light.light_energy=(.75 if boss_state=="open" else .38)+sin(clock*5)*.07
	if state=="victory":core_light.light_energy=0
	var sk=animator.skeleton(giant_model)
	if sk and sk.find_bone("Core")>=0:core_light.position=sk.get_bone_global_pose(sk.find_bone("Core")).origin+Vector3(0,0,.35)

func update_camera(dt: float) -> void:
	if state=="menu":
		camera.position=camera.position.lerp(Vector3(5.5,3.4,9),minf(1,dt*2));camera.look_at(Vector3(0,2,-2));return
	if state=="paused":return
	var focus=hero.position.lerp(giant.position,.45)+Vector3.UP*1.5
	var desired=hero.position+Vector3(0,4.6,7.9).rotated(Vector3.UP,yaw)
	desired.x=clampf(desired.x,-10.1,10.1);desired.z=clampf(desired.z,-8.8,10.2)
	camera.position=camera.position.lerp(desired,minf(1,dt*5.5))
	shake=maxf(0,shake-dt*1.8)
	if shake_enabled and shake>0:focus+=Vector3(rng.randf_range(-shake,shake),rng.randf_range(-shake,shake),0)*.12
	camera.look_at(focus)

func update_hud(dt: float) -> void:
	hp_bar.value=health;core_bar.value=core_health
	for i in range(2):armor_labels[i].text=("圆印" if i==0 else "三角")+(" · 已破甲" if broken[i] else " · 纸甲 %d"%int(armor[i]))
	var stage=1 if core_health>200 else (2 if core_health>100 else 3)
	state_label.text="核心暴露 · 剩余 %.1f 秒"%maxf(0,core_open) if boss_state=="open" else "第 %d 阶段 · 避开攻击，拆掉双拳纸甲"%stage
	elapsed_label.text="%02d:%02d"%[int(game_time)/60,int(game_time)%60]
	message_time-=dt
	if message_time<=0:tip.text=""
	if charge_down:tip.text="蓄力重击"+" · ".repeat(int(charging*4)+1)

func message(text: String,time: float=2) -> void:
	tip.text=text;message_time=time

func distance_flat(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func sound(kind: String,volume: float) -> void:
	var file="res://assets/纸烬决斗_音效_%s_20260910.wav"%kind
	if not ResourceLoader.exists(file):return
	var a=audio_players[audio_cursor%audio_players.size()];audio_cursor+=1;a.stream=load(file);a.volume_db=linear_to_db(volume);a.pitch_scale=rng.randf_range(.9,1.1);a.play()

func capture_frame() -> void:
	await RenderingServer.frame_post_draw
	var im=get_viewport().get_texture().get_image()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(im.save_png_to_buffer(),"paper-ember-duel-screenshot.png","image/png")
		return
	var path=ProjectSettings.globalize_path(SAVE_ROOT+"纸烬决斗_实机截图_20260911.png")
	var error=im.save_png(path)
	if error==OK:print("CAPTURE_SAVED ",path);message("截图已保存至游戏用户数据目录",2)
	else:push_warning("Screenshot save failed: %s"%error)
	if not qa_flow:
		var record=ProjectSettings.globalize_path("res://documentary/过程记录_20260910/纸烬决斗_实机_%s_%03d秒_20260910.png"%[boss_state,int(game_time)])
		if DirAccess.dir_exists_absolute(record.get_base_dir()):im.save_png(record)

func demo_direction() -> Vector3:
	var target=giant.to_global(Vector3(0,0,4.3))
	if boss_state=="recover_slam" and expose_hand>=0:target=fist_position(expose_hand)+giant.basis.z*.7
	elif boss_state=="open":target=giant.to_global(Vector3(0,0,2.1))
	elif boss_state=="windup_slam":target=fist_position(active_hand)+giant.basis.z*2.1
	var direction=target-hero.position;direction.y=0
	for d in danger:
		if d.delay<.25 and distance_flat(hero.position,d.position)<1.5:
			direction=hero.position-d.position;direction.y=0
			if direction.length()<.1:direction=Vector3.RIGHT
			return direction.normalized()
	return direction.normalized() if direction.length()>.25 else Vector3.ZERO

func demo_driver(_dt: float) -> void:
	# Demo walks through normal movement/collision and uses the same attack cooldowns.
	if boss_state=="recover_slam" and expose_hand>=0 and distance_flat(hero.position,fist_position(expose_hand))<1.3:
		if attack_cd<=0:attack(true)
	elif boss_state=="open" and distance_flat(hero.position,giant.to_global(Vector3(0,0,1.1)))<1.7:
		if attack_cd<=0:attack(true)
	if boss_state=="windup_slam" and boss_clock>1.02 and distance_flat(hero.position,warning_position)<1.6:dodge()
	if boss_state=="shock" and absf(distance_flat(hero.position,giant.position)-boss_clock*7)<.75:dodge()
	if not qa_flow and int(game_time) in [7,18,29] and frame_counter%60==0:screenshot_requested=true

func run_qa() -> void:
	await get_tree().physics_frame
	var results: Dictionary={}
	hero.position=Vector3(6.4,.04,7.3)
	Input.action_press("right")
	for step in range(30):await get_tree().physics_frame
	Input.action_release("right")
	results["crate_collision_after_batching"]=hero.position.x>6.4 and hero.position.x<7.1
	results["hero_feet_ground_height"]=absf(hero.position.y-.02)<.04
	var sk=animator.skeleton(giant_model)
	if sk:
		for step in range(100):animator.update_giant(giant_model,{"boss_state":"open","boss_clock":2.0,"clock":0.0,"active_hand":0,"broken":[true,true],"victory":false},1.0/60)
		var feet_ok=true
		for side in ["Left","Right"]:
			var idx=sk.find_bone(side+"Foot")
			feet_ok=feet_ok and sk.get_bone_global_pose(idx).origin.distance_to(sk.get_bone_global_rest(idx).origin)<.01
		results["feet_pinned_during_core_open"]=feet_ok
		var core_idx=sk.find_bone("Core")
		results["core_reachable_height"]=core_idx>=0 and sk.get_bone_global_pose(core_idx).origin.y<1.7
		results["armor_separate_and_hidden"]=not giant_model.find_child("RightFistArmor",true,false).visible and not giant_model.find_child("LeftFistArmor",true,false).visible
		animator.crouch=0;animator.core_blend=0
		animate_models(1.0)
	# Verify hit windows, i-frames, correct armor accounting, core gating, pause and reset.
	hero.position=giant.to_global(Vector3(0,0,2));var initial=core_health;attack(false);update_attack(attack_duration);results["closed_core_immune"]=core_health==initial
	hurt_invul=0;dodge_time=.2;var old_hp=health;receive_damage(20,false);results["dodge_iframe"]=health==old_hp
	dodge_time=0;parry_time=.2;hurt_invul=0;active_hand=0;old_hp=health;receive_damage(20,true);results["parry"]=health==old_hp and parry_count==1
	parry_time=0;hurt_invul=0;receive_damage(20,false);results["damage"]=health==old_hp-20
	boss_state="recover_slam";expose_hand=0;hero.position=fist_position(0)+Vector3(0,0,1);armor[0]=30;attack_cd=0;attack(true);update_attack(attack_duration);results["one_hand_not_open"]=broken[0] and boss_state!="open"
	expose_hand=1;hero.position=fist_position(1)+Vector3(0,0,1);armor[1]=30;attack_cd=0;attack(true);update_attack(attack_duration);results["both_hands_open"]=boss_state=="open"
	hero.position=giant.to_global(Vector3(0,0,2));initial=core_health;attack_cd=0;attack(true);update_attack(attack_duration);results["core_damage"]=core_health<initial
	core_health=10;attack_cd=0;attack(true);update_attack(attack_duration);results["victory"]=state=="victory"
	start_game();results["restart"]=state=="playing" and health==100 and core_health==300 and not broken[0] and danger.is_empty()
	toggle_pause();results["pause"]=state=="paused";toggle_pause();results["resume"]=state=="playing"
	hurt_invul=0;receive_damage(1000,false);results["death"]=state=="dead"
	var ok=true
	for v in results.values():if not v:ok=false
	var file=FileAccess.open(SAVE_ROOT+"纸烬决斗_战斗验证_20260910.json",FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"passed":ok,"checks":results},"  "));file.close()
	else:push_error("Unable to save combat QA report");ok=false
	print("COMBAT_QA_PASS" if ok else "COMBAT_QA_FAIL",JSON.stringify(results))
	for a in audio_players:a.stop();a.stream=null
	animator.skeletons.clear()
	builder.mats.clear()
	actors.b.mats.clear()
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)

func _setup_motion_fx() -> void:
	trail_mesh=ImmediateMesh.new();trail_node=MeshInstance3D.new();trail_node.mesh=trail_mesh;add_child(trail_node)
	var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.vertex_color_use_as_albedo=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED;mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	trail_node.material_override=mat;trail_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	charge_aura=make_ring(Vector3.ZERO,.18,Color("f9b754"));add_child(charge_aura);charge_aura.hide()

func update_motion_fx(dt: float) -> void:
	for i in range(trail_points.size()-1,-1,-1):
		trail_points[i].life-=dt
		if trail_points[i].life<=0:trail_points.remove_at(i)
	var points=animator.weapon_points(hero_model)
	var t=attack_elapsed/maxf(.01,attack_duration)
	if points.size()==2 and anim_attack>0 and t>.28 and t<.76 and dodge_time<=0:
		trail_points.append({"a":points[0].lerp(points[1],.20),"b":points[1]+(points[1]-points[0])*.10,"life":.18 if heavy_attack else .12,"total":.18 if heavy_attack else .12,"heavy":heavy_attack})
	trail_mesh.clear_surfaces()
	if trail_points.size()>1:
		trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(1,trail_points.size()):
			var left=trail_points[i-1];var right=trail_points[i]
			for spec in [[left,"a"],[left,"b"],[right,"b"],[left,"a"],[right,"b"],[right,"a"]]:
				var row=spec[0];var color=Color("ffb345") if row.heavy else Color("e4e9f3")
				color.a=(row.life/row.total)*(.22 if spec[1]=="a" else .8)
				trail_mesh.surface_set_color(color);trail_mesh.surface_add_vertex(row[spec[1]])
		trail_mesh.surface_end()
	charge_aura.visible=charge_down and state=="playing" and points.size()==2
	if charge_aura.visible:
		charge_aura.position=points[1];charge_aura.rotation=Vector3(PI/2,clock*5,clock*3)
		charge_aura.scale=Vector3.ONE*(.6+minf(charging,1.0)+sin(clock*24)*.12)

func strike_effect(heavy: bool) -> void:
	if not heavy:return
	var forward=Vector3(sin(facing_yaw),0,cos(facing_yaw))
	var at=hero.position+forward*.78;at.y=.07
	var n=make_ring(at,.35,Color(1,.65,.20,.9));add_child(n)
	for child in n.get_children():child.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	effects.append({"node":n,"life":.40,"total":.40,"velocity":Vector3.ZERO,"spin":Vector3.ZERO,"ring":true,"pulse":true})
	burst(at,14);shake=maxf(shake,.20)
	for i in range(7):
		var direction=forward.rotated(Vector3.UP,(i-3)*.24)
		var flash=builder.line(self,at+direction*.15+Vector3.UP*.04,at+direction*(.65+float(i%3)*.18)+Vector3.UP*.04,.012,builder.material("heavy_flash",Color("f6c678"),.8,1.0))
		effects.append({"node":flash,"life":.12,"total":.12,"velocity":Vector3.ZERO,"spin":Vector3.ZERO,"ring":true})

func foot_dust() -> void:
	for i in range(2):
		var dust=builder.box(self,hero.position+Vector3(rng.randf_range(-.14,.14),.055,rng.randf_range(-.1,.1)),Vector3(.045,.015,.08),builder.material("foot_dust",Color("998669")))
		effects.append({"node":dust,"life":.20,"total":.20,"velocity":Vector3(0,.35,0),"spin":Vector3(2,3,1),"ring":false})
