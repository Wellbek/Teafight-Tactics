extends CharacterBody3D

var main
var player
var timer: Timer
var parent

@export var unitName: String
var ui: Control

var target = null
var targetable = true 
var attacking = false

var dead = false

@export_category("Stats")
@export var move_speed = 5.0
@export var attackrange = 4.0
@export var max_health = 100.0
@onready var curr_health = max_health
@export var attack_dmg = 20.0
@export var armor = 30.0
@export var attack_speed = 0.8
@export var attack_timer: Timer

const BAR_COLOR = Color(0.757, 0.231, 0.259)

func _ready():
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	var viewport = find_child("SubViewport")
	ui = viewport.get_child(0)
	find_child("Sprite3D").texture = viewport.get_texture()
	ui.get_node("HPBar").self_modulate = BAR_COLOR	
	
func _enter_tree():	
	main = get_tree().root.get_child(0)
	timer = main.get_timer()
	parent = get_parent()
	player = parent.get_parent().get_parent()
	
func _process(delta):
	if parent.visible and not timer.is_transitioning() and not timer.is_preparing():
		find_target()

func _physics_process(delta):	
	if target and not is_instance_valid(target): target = null
		
	if target:
		var distance = global_transform.origin.distance_to(target.global_transform.origin)
		#if name == "MurkWolf": print(distance)
		
		if distance > attackrange:
			attacking = false
			velocity = (target.global_transform.origin - global_transform.origin).normalized() * move_speed
			move_and_slide()
		elif not attacking: in_attack_range()
		
		look_at(target.global_transform.origin)
		rotation.x = 0
		rotation.z = 0
	
@rpc("any_peer", "call_local", "unreliable")
func change_target_status(value):
	targetable = value
	
func is_targetable():
	return targetable
			
func find_target():
	if not player or not is_multiplayer_authority(): return
	
	var player_units = player.find_child("CombatUnits").get_children()
	
	for unit in player_units:	
		if not unit.is_targetable(): continue
		
		if not target or global_transform.origin.distance_to(unit.global_transform.origin) < global_transform.origin.distance_to(target.global_transform.origin):
			target = unit
		
func toggleUI(value):
	ui.visible = value
	
func get_ui():
	return ui

func in_attack_range():
	if attack_timer == null: attack_timer = $AttackTimer
	attacking = true
	attack_timer.wait_time = 1/attack_speed
	attack_timer.start()
	
func _on_attack_timer_timeout():
	if main.get_timer().is_transitioning(): get_node("AttackTimer").stop()
	else: auto_attack(target)

func auto_attack(_target):
	if _target == null or _target.get_mode() != 1: return
	
	_target.take_dmg.rpc_id(_target.get_owner_id(), attack_dmg)

func change_attack_speed(val):
	attack_speed = val
	attack_timer.wait_time = 1/attack_speed
	if attacking == true: attack_timer.start()

@rpc("any_peer", "call_local", "unreliable")
func take_dmg(raw_dmg):
	var dmg = raw_dmg / (1+armor/100) # https://leagueoflegends.fandom.com/wiki/Armor
	
	curr_health = 0 if dmg >= curr_health else curr_health-dmg
	
	ui.get_node("HPBar").value = curr_health/max_health * 100
	
	if curr_health <= 0 and not dead: 
		dead = true
		death.rpc(get_path())
		main.freeObject.rpc(get_path())
		
@rpc("any_peer", "call_local", "reliable")
func death(_path):
	var instance = get_tree().root.get_node(_path)
	var parent = instance.get_parent()
	if instance != null and is_instance_valid(instance):		
		if multiplayer.is_server():
			var fighter_count = 0
			for u in parent.get_children():
				fighter_count += 1
			
			if fighter_count <= 1:
				main.unregister_battle()
				check_battle_status()
		instance.queue_free()
		
# server func
func check_battle_status():	
	if not multiplayer.is_server(): return
	
	if main.get_num_of_battles() <= 0 and not main.get_timer().is_preparing():
		# all battles have finished => go right into prep phase
		main.get_timer().change_phase()

func _on_visibility_changed():
	print("test")
	set_collision_layer_value(6, visible)
