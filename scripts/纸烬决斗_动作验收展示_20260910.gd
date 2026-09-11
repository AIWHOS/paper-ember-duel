extends Node

var game
var elapsed=0.0
var previous=0.0
var caption: Label
var samples=[]

func _ready():
	process_physics_priority=100
	game=load("res://main.tscn").instantiate();add_child(game)
	game.start_game();game.qa_flow=true;game.shake_enabled=false
	game.menu_layer.hide();game.hud.hide()
	caption=game.label("MOTION STUDY  /  PAPER & EMBER",30,Color("e7cc9e"));game.canvas_layer.add_child(caption);caption.position=Vector2(55,60)
	game.hero.position=Vector3(-1.4,.02,3.8)
	game.giant.position=Vector3(0,0,-7)
	game.boss_wait=999
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func cross(at: float) -> bool:return previous<at and elapsed>=at

func _physics_process(dt):
	previous=elapsed;elapsed+=dt
	game.boss_wait=999
	if elapsed<4.5:
		caption.text="01  /  RUN CYCLE  -  FOOT PLANT & ARM SWING"
		if cross(.7):Input.action_press("right")
		if cross(2.5):Input.action_release("right");Input.action_press("left")
		if cross(4.3):Input.action_release("left")
	elif elapsed<8:
		caption.text="02  /  LIGHT ATTACK  -  SWING & RECOVERY"
		if cross(4.8) or cross(5.6) or cross(6.4) or cross(7.2):game.attack(false)
	elif elapsed<12:
		caption.text="03  /  HEAVY ATTACK  -  CHARGE, SLASH & IMPACT"
		if cross(8.3):game.charge_down=true
		if cross(9.2):game.charge_down=false;game.charging=0;game.attack(true)
		if cross(10.5):game.charge_down=true
		if cross(11.1):game.charge_down=false;game.charging=0;game.attack(true)
	else:
		caption.text="04  /  DODGE ROLL  -  TUCK, ROTATION & LANDING"
		if cross(12.6):Input.action_press("right");game.dodge();Input.action_release("right")
		if cross(14):Input.action_press("left");game.dodge();Input.action_release("left")
		if cross(15.5):Input.action_press("forward");game.dodge();Input.action_release("forward")
	game.camera.position=game.hero.position+(Vector3(2.35,1.45,2.7) if elapsed<4.5 or elapsed>=12 else Vector3(2.4,1.50,-2.6))
	game.camera.fov=37;game.camera.look_at(game.hero.position+Vector3(0,.69,0))
	if cross(1.3) or cross(1.4) or cross(5.05) or cross(5.16) or cross(9.68) or cross(12.82) or cross(12.95):
		var sk=game.animator.skeleton(game.hero_model)
		samples.append({"second":elapsed,"left_foot":str(sk.get_bone_global_pose(sk.find_bone("LeftFoot")).origin),"right_foot":str(sk.get_bone_global_pose(sk.find_bone("RightFoot")).origin),"blade":str(game.animator.weapon_points(game.hero_model)),"model_basis":str(game.hero_model.basis)})
	if cross(17):
		Input.action_release("right");Input.action_release("left");Input.action_release("forward")
		var f=FileAccess.open("res://verification/纸烬决斗_动作展示采样_20260910.json",FileAccess.WRITE);f.store_string(JSON.stringify(samples,"  "));f.close()
		get_tree().quit()
