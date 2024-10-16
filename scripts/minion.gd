extends CharacterBody3D

var main
var player
var timer: Timer
var parent

@export var unit_name: String
var ui: Control

var target = null
var eon_target = null
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
@export var mr = 30.0
@export var attack_speed = 0.8
@export var attack_timer: Timer
var shield = 0.0

var wounded = false
var wound = 0.0

var curr_sunder = 0.0
var curr_shred = 0.0

const BAR_COLOR = Color(0.757, 0.231, 0.259)

# tft is to complicated and couldn't figure out orb droprate
# still here for reference: https://twitter.com/Mortdog/status/1761019549506490633

# [nothing, item component, 2g, 4g, 6g, 8g]
const DROP_RATES = [0.55, 0.25, 0.09, 0.06, 0.03, 0.02]

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
	if dead: return
	
	if parent.visible and not timer.is_transitioning() and not timer.is_preparing() and not target:
		find_target()

func _physics_process(delta):	
	if dead: return
	
	if target and (not is_instance_valid(target) or target.dead): 
		target = null
		
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
	
	var player_units = player.find_child("Units").get_children()
	
	for unit in player_units:	
		if not unit.is_targetable() or unit.dead or unit == eon_target: continue
		
		if not target or global_transform.origin.distance_to(unit.global_transform.origin) < global_transform.origin.distance_to(target.global_transform.origin):
			if target: target.decrease_targeting_count.rpc_id(target.get_owner_id())
			target = unit
			target.increase_targeting_count.rpc_id(target.get_owner_id())
			eon_target = null
			
	# in case no other valid target was found but there is still the untargetable edge of night one
	if not target and eon_target:
		target = eon_target
		target.increase_targeting_count.rpc_id(target.get_owner_id())
		eon_target = null
		
func toggle_ui(value):
	ui.visible = value
	
func get_ui():
	return ui

func in_attack_range():
	if dead: 
		attacking = false
		return
	
	if attack_timer == null: attack_timer = $AttackTimer
	attacking = true
	attack_timer.wait_time = 1/attack_speed
	attack_timer.start()
	
func _on_attack_timer_timeout():
	if main.get_timer().is_transitioning() or dead: 
		attacking = false
		get_node("AttackTimer").stop()
	else: auto_attack(target)

func auto_attack(_target):
	if _target == null or _target.get_mode() != 1: return
	
	_target.take_dmg.rpc_id(_target.get_owner_id(), attack_dmg, 0, true, get_path())

func change_attack_speed(val):
	attack_speed = val
	attack_timer.wait_time = 1/attack_speed
	if attacking == true: attack_timer.start()

@rpc("any_peer", "call_local", "unreliable")
func take_dmg(raw_dmg, dmg_type, dodgeable, source: NodePath):
	var dmg = raw_dmg / (1+armor/100) # https://leagueoflegends.fandom.com/wiki/Armor
	
	curr_health = 0 if dmg >= curr_health else curr_health-dmg
	
	ui.get_node("HPBar").value = curr_health/max_health * 100
	
	if curr_health <= 0 and not dead: 
		var attacker = get_node_or_null(source) if source else null
		if attacker: attacker._on_kill.rpc_id(attacker.get_multiplayer_authority(), get_path())
		dead = true
		death.rpc(get_path())
		main.free_object.rpc(get_path())
		
@rpc("any_peer", "call_local", "unreliable")
func apply_sunder(_amount, _duration):
	if not is_multiplayer_authority(): return
	
	# only overwrite current sunder if new effect is stronger or same
	if _amount >= curr_sunder:
		var sunder_timer = get_node_or_null("sunder_timer")
		
		if not sunder_timer: # If timer doesn't exist, create it
			sunder_timer = Timer.new()
			add_child(sunder_timer)
			sunder_timer.name = "sunder_timer"
			sunder_timer.one_shot = true
			sunder_timer.connect("timeout", _on_sunder_end)
		else:
			sunder_timer.stop() # Stop the timer if it's already running
		
		# Set the timer duration and start it
		sunder_timer.wait_time = _duration
		sunder_timer.start()
		
		# Remove old sunder effect by dividing by (1 - curr_sunder)
		if curr_sunder != 0:
			armor /= (1 - curr_sunder)
			
		# Store new sunder amount
		curr_sunder = _amount
		
		# Apply new sunder effect by multiplying by (1 - new_sunder)
		armor *= (1 - curr_sunder)
		
		#print("Sundered now for ", curr_sunder, "// new armor is hence ", armor)

func _on_sunder_end():
	var sunder_timer = get_node_or_null("sunder_timer")
	
	if sunder_timer: sunder_timer.stop() # Just stop it, don't free
	
	# Reset armor and current sunder amount
	armor /= (1 - curr_sunder)
	curr_sunder = 0
	
	#print("Sunder end // new armor is hence ", armor)


@rpc("any_peer", "call_local", "unreliable")
func apply_shred(_amount, _duration):
	if not is_multiplayer_authority(): return
	
	# only overwrite current shred if new effect is stronger or same
	if _amount >= curr_shred:
		var shred_timer = get_node_or_null("shred_timer")
		
		if not shred_timer: # If timer doesn't exist, create it
			shred_timer = Timer.new()
			add_child(shred_timer)
			shred_timer.name = "shred_timer"
			shred_timer.one_shot = true
			shred_timer.connect("timeout", on_shred_end)
		else:
			shred_timer.stop() # Stop the timer if it's already running
		
		# Set the timer duration and start it
		shred_timer.wait_time = _duration
		shred_timer.start()
		
		# Remove old shred effect by dividing by (1 - curr_shred)
		if curr_shred != 0:
			mr /= (1 - curr_shred)
			
		# Store new shred amount
		curr_shred = _amount
		
		# Apply new shred effect by multiplying by (1 - new_shred)
		mr *= (1 - curr_shred)
		
		# print("Shred applied // new mr is hence ", mr)

func on_shred_end():
	var shred_timer = get_node_or_null("shred_timer")
	
	if shred_timer: shred_timer.stop() # Just stop it, don't free
	
	mr /= (1 - curr_shred)
	curr_shred = 0
	
	# print("Shred end // new mr is hence ", mr)

	
@rpc("any_peer", "call_local", "unreliable")
func _on_kill(_target_path):
	var _target = get_node(_target_path)
	print(name, " killed ", _target)
		
@rpc("any_peer", "call_local", "reliable")
func death(_path):
	var instance = get_tree().root.get_node(_path)
	var parent = instance.get_parent()
	
	if instance != null and is_instance_valid(instance):
		instance.dead = true	
			
		if target: target.decrease_targeting_count.rpc_id(target.get_owner_id())
		
		if multiplayer.is_server():
			drop()
			
			var fighter_count = 0
			for u in parent.get_children():
				fighter_count += 1
			
			if fighter_count <= 1:
				main.unregister_battle()
				check_battle_status()
		instance.visible = false
		
# server func
func check_battle_status():	
	if not multiplayer.is_server(): return
	
	if main.get_num_of_battles() <= 0 and not main.get_timer().is_preparing():
		# all battles have finished => go right into prep phase
		main.get_timer().change_phase()

func _on_visibility_changed():
	set_collision_layer_value(6, visible)
	
func drop():
	var rarity = randf() # number between 0 and 1
	var index = 0
	for i in range(len(DROP_RATES)):
		if rarity < DROP_RATES[i]:
			index = i
			break
		rarity -= DROP_RATES[i]
		
	match index:
		1:
			#print(player.get_id(),": item")
			var folder = "res://src/items"
			var dir = DirAccess.open(folder)
			var itemArray = dir.get_files()
			var itemFileName = itemArray[randi() % itemArray.size()].get_slice(".",0)
			
			var instance_path = folder + "//" + itemFileName + ".tscn"
			
			player.spawn_item.rpc_id(get_multiplayer_authority(), instance_path)
		2:
			player.increase_gold(2)
		3:
			player.increase_gold(4)
		4:
			player.increase_gold(6)
		5:
			player.increase_gold(8)
		_: 
			pass
			
func get_curr_health():
	return curr_health
	
func get_max_health():
	return max_health

@rpc("any_peer", "call_local", "reliable")
func be_wounded(percent = 0.33, duration = 10.0):
	wounded = true
	wound = percent
	var timer = get_node_or_null("wound_timer")
	if not timer: 
		timer = Timer.new()
		add_child(timer)
		timer.name = "wound_timer"
		timer.connect("timeout", _on_wounded_end)
	timer.wait_time = duration
	timer.one_shot = true
	timer.start()	
	# particle
	var particles = get_node_or_null("wounded_burn")
	if not particles:
		spawn_particle.rpc("res://src/wounded_burn.tscn", "wounded_burn")

func _on_wounded_end():
	wounded = false
	wound = 0
	var timer = get_node_or_null("wound_timer")
	if timer: timer.queue_free()
	
	# particles
	remove_particle.rpc("wounded_burn")
	
@rpc("any_peer", "call_local", "unreliable")
func spawn_particle(_path, _name):
	var particle = load(_path).instantiate()
	particle.name = _name
	add_child(particle)
	
@rpc("any_peer", "call_local", "unreliable")
func remove_particle(_name):
	var particle = main.get_node_or_null(_name)
	if particle: particle.queue_free()
	
func is_shielded():
	return shield > 0

@rpc("any_peer", "call_local", "unreliable")
func receive_eon_effect(eon_owner_path: NodePath):
	var eon_owner = get_node(eon_owner_path)
	
	if eon_owner == target:
		eon_target = target
		target = null

@rpc("any_peer", "call_local", "unreliable")		
func decrease_targeting_count():
	pass

@rpc("any_peer", "call_local", "unreliable")
func increase_targeting_count():
	pass
