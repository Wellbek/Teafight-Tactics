extends CharacterBody3D

var dragging: bool = false
@onready var sell_unit_gui = main.get_ui().get_node("UnitShop/SellUnit")
var initial_pos: Vector3

var coll
var tile

var main
var player
var timer: Timer

var myid

var multisync

@export_file("*.png", "*.jpg") var image
@export var unit_name: String
@export_enum("NONE","1", "2", "3") var star: int = 1
@export_enum("Herbal Heroes", "Green Guardians", "Black Brigade", "Floral Fighters", "Exotic Enchanters", "Fruitful Forces", "Aromatic Avatars") var type: int = 0
const CLASS_NAMES = ["Herbal Heroes", "Green Guardians", "Black Brigade", "Floral Fighters", "Exotic Enchanters", "Fruitful Forces", "Aromatic Avatars"]
var ui: Control

@export_category("Animations")
@onready var anim_player:AnimationPlayer = find_child("AnimationPlayer")
@export_enum("Melee", "Ranged", "Magic") var attack_anim1: int = 0
@export_enum("1H", "2H") var attack_anim2: int = 0
@export var one_hand_melee_anim: String = "1H_Melee_Attack_Chop"
@export var one_hand_ranged_anim: String = "1H_Ranged_Shoot"
@export var one_hand_magic_anim: String = "Spellcast_Shoot"
@export var two_hand_melee_anim: String = "2H_Melee_Attack_Chop"
@export var two_hand_range_anim: String = "2H_Ranged_Shoot"
@export var two_hand_magic_anim: String = "Spellcast_Shoot"
@export var idle_anim: String = "Idle"
@export var walking_anim: String = "Walking_A"
@export var die_anim: String = "Death_A"

enum {SQUARE, HEX}
enum {PREP, BATTLE}

var mode = PREP

var target = null
var targetable = false 
var attacking = false
var targeting_neutral = false

var dead = false

@export_category("Stats")
@export var cost = 1
@onready var rarity = cost
@export var move_speed = 5.0
@export var attackrange = 4.0
@export var max_health = 100.0
@onready var curr_health = max_health
@export var max_mana = 100.0
@export var start_mana = 0
@onready var curr_mana = start_mana
@export var attack_dmg = 20.0
@export var ability_power = 100.0
@export var armor = 30.0
@export var mr = 30.0
@export var attack_speed = 0.8
var crit_chance = 0.25
var crit_damage = 0.3
@export var attack_timer: Timer
var dodge_chance = 0.0
var bonus_attack_speed = 0.0 # in raw (not percent)
var duelist_counter = 0
var omnivamp = 0.0 # heal of RAW dmg
var bonus_dmg = 0.0 # in percent

@export_category("Ability")
@export_enum("Enhanced Auto") var ability_id = 0
const ABILITY_TYPES = ["Enhanced AA"]
@export_enum("AD", "AP", "True") var ability_dmg_type = 1
const ABILITY_DMG_TYPES = ["AD", "AP", "TrueDMG"]
@export var scaling1: float = 1.0
@export var scaling2: float = 1.5
@export var scaling3: float = 2.25
var ability_crit = false
const MANA_PER_ATTACK = 10

const LOCAL_COLOR = Color(0.2, 0.898, 0.243)
const ENEMY_HOST_COLOR = Color(0.757, 0.231, 0.259)
const ENEMY_ATTACKER_COLOR = Color(0.918, 0.498, 0.176)

var items = [null, null, null]

var affected_by_urf = false

func _ready():
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	var viewport = find_child("SubViewport")
	ui = viewport.get_child(0)
	find_child("Sprite3D").texture = viewport.get_texture()
	ui.get_node("HPBar").self_modulate = LOCAL_COLOR if is_multiplayer_authority() else ENEMY_HOST_COLOR
	
	refresh_manabar()
	
func _enter_tree():
	myid = name.get_slice("#", 0).to_int()
	set_multiplayer_authority(myid)
	#print(str(multiplayer.get_unique_id()) + ": " + str(get_multiplayer_authority()))
	
	main = get_tree().root.get_child(0)
	timer = main.get_timer()
	player = main.find_child("World").get_node(str(myid))
	multisync = find_child("MultiplayerSynchronizer", false)
	
func _process(_delta):
	if not is_inside_tree() or dead or not is_multiplayer_authority(): return
	
	if mode == BATTLE and target == null and is_multiplayer_authority() and not main.get_timer().is_transitioning():
		find_target()

func _physics_process(_delta):	
	if not is_inside_tree() or dead or not is_multiplayer_authority(): return
	
	if target and (not is_instance_valid(target) or target.dead): 
		target = null
		
	if target and mode == BATTLE:
		var distance = global_transform.origin.distance_to(target.global_transform.origin)

		if distance > attackrange:
			attacking = false
			velocity = (target.global_transform.origin - global_transform.origin).normalized() * move_speed
			if anim_player.current_animation != walking_anim: play_animation.rpc(walking_anim)
			move_and_slide()
		elif not attacking: in_attack_range()
		
		look_at(target.global_transform.origin)
		rotation.x = 0
		rotation.z = 0

func set_tile(new_tile):
	tile = new_tile
	change_target_status.rpc(true if tile.get_parent().get_type() == HEX else false)
	
@rpc("any_peer", "call_local", "reliable")
func change_target_status(value):
	targetable = value
	
func is_targetable():
	return targetable
	
func get_tile():
	return tile
	
func get_tile_type():
	if not tile: return -1
	return tile.get_parent().get_type()

func _input_event(_camera, event, _position, _normal, _shape_idx):
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT and !is_dragging() and not dead and visible:
		main.get_ui().get_node("UnitInspec").set_unit(self)

	if not is_multiplayer_authority() or not mode == PREP or (get_tile_type() == HEX and not timer.is_preparing()): return

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT and !is_dragging():
		set_dragging(true)
		toggle_grid(true)
		change_color(tile.find_children("MeshInstance3D")[0], Color.WHITE)	
		initial_pos = global_transform.origin

		transform.origin.y += 1

func _input(event):
	if not is_multiplayer_authority() or not mode == PREP or (get_tile_type() == HEX and not timer.is_preparing()): return
	
	if is_dragging():
		if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
			if main.is_unit_sellable():
				sell_unit()
			else:
				place_unit()
		elif event is InputEventMouseMotion:
			var viewport := get_viewport()
			var mouse_position := viewport.get_mouse_position()
			var camera := viewport.get_camera_3d()
			
			var origin := camera.project_ray_origin(mouse_position)
			var direction := camera.project_ray_normal(mouse_position)

			var ray_length := camera.far
			var end := origin + direction * ray_length
			
			var space_state := get_world_3d().direct_space_state
			var query := PhysicsRayQueryParameters3D.create(origin, end, 0b00000000_00000000_00000010_00000111)
			var result := space_state.intersect_ray(query)
			if not result.is_empty() and result.collider != null:
				if result.collider.get_collision_layer() == 2 and result.collider != coll and result.collider.is_multiplayer_authority() and result.collider.get_parent().visible:
					if coll:
						# reset highlight of last tile
						change_color(coll.find_children("MeshInstance3D")[0], Color.CYAN)
					# highlight current tile
					coll = result.collider
					change_color(coll.find_children("MeshInstance3D")[0], Color.WHITE)

				var mouse_position_3D:Vector3 = result.get("position", initial_pos if coll == null else coll.global_transform.origin)

				global_transform.origin = Vector3(mouse_position_3D.x, global_transform.origin.y, mouse_position_3D.z)

func change_mode(_mode: int):
	if mode == _mode: return
	
	play_animation(idle_anim)
	
	if _mode == BATTLE:
		# bastion (kinda): - aromatic 
		# all bastion units increased armor and mr (in combat): increased by 100% for first 10 sec
		if type == 6:
			var class_level = main.get_classes().get_class_level(CLASS_NAMES[6])
			if class_level >= 1:
				var timer = Timer.new()
				add_child(timer)
				timer.name = "aromatic_trait"
				timer.wait_time = 10.0 + main.get_timer().TRANSITION_TIME # not ideal but works for now without needing to change system 
				timer.one_shot = true
				timer.connect("timeout", _on_aromatic_10sec)
				timer.start()
				match class_level:
					1: 
						armor += 50
						mr += 50
					2: 
						armor += 100
						mr += 100
					3: 
						armor += 190
						mr += 190
					_: pass
			
		# bruiser: - herbal
		# 100 max health all, bruisers bonus:
		# 20% health
		# 40% health
		# 65% health
		match main.get_classes().get_class_level(CLASS_NAMES[0]):
			1: 
				max_health += 100
				if type == 0: max_health *= 1.2
				curr_health = max_health
			2: 
				max_health += 100
				if type == 0: max_health *= 1.4
				curr_health = max_health
			3: 
				max_health += 100
				if type == 0: max_health *= 1.65
				curr_health = max_health
			_: pass
		
		# wing (kinda): - floral
		# all allies gain dodge chance: 15% -> 25% -> 35%
		match main.get_classes().get_class_level(CLASS_NAMES[3]):
			1: dodge_chance += .15
			2: dodge_chance += .25
			3: dodge_chance += .35
			_: pass
			
		# slayer: - green
		# all slayers:
		# 15% omnivamp, bonus dmg (doubled at 66%) - 5% b dmg -> 10% -> 30%
		if type == 1:
			match main.get_classes().get_class_level(CLASS_NAMES[1]):
				1: 
					omnivamp += .15
					bonus_dmg += 0.05
				2: 
					omnivamp += .15
					bonus_dmg += 0.1
				3: 
					omnivamp += .15
					bonus_dmg += 0.3
				_: pass
				
		# shurima (kinda): - fruit
		# heal % every 4 seconds
		if type == 5:
			var class_level = main.get_classes().get_class_level(CLASS_NAMES[5])
			if class_level >= 1:
				var timer = Timer.new()
				add_child(timer)
				timer.name = "fruit_trait"
				timer.wait_time = 4.0
				timer.one_shot = false
				timer.connect("timeout", _on_shurima)
				timer.start()
				
		# cybernatic (kinda): - exotic
		# cybernatic champions with atleast one item gain health and attack dmg:
		# 200 health 35 attack dmg
		# 400 health 50 attack dmg
		# 700 health and 70 attack dmg
		if type == 4 and items[0]:
			match main.get_classes().get_class_level(CLASS_NAMES[4]):
				1: 
					max_health += 200
					curr_health = max_health
					attack_dmg += 35
				2: 
					max_health += 400
					curr_health = max_health
					attack_dmg += 50
				3: 
					max_health += 700
					curr_health = max_health
					attack_dmg += 70
				_: pass
	
		
		set_collision_layer_value(5, true) # only collide with battling units (hidden prep units should be ignored)
	else:
		# reset bastion trait
		if type == 6:		
			if get_node_or_null("aromatic_trait"): _on_aromatic_10sec()
			match main.get_classes().get_class_level(CLASS_NAMES[6]):
				1: 
					armor -= 25
					mr -= 25
				2: 
					armor -= 50
					mr -= 50
				3: 
					armor -= 95
					mr -= 95
				_: pass
				
		# reset bruiser trait
		match main.get_classes().get_class_level(CLASS_NAMES[0]):
			1: 
				if type == 0: max_health /= 1.2
				max_health -= 100
				curr_health = max_health
			2: 
				if type == 0: max_health /= 1.4
				max_health -= 100
				curr_health = max_health
			3: 
				if type == 0: max_health /= 1.65
				max_health -= 100
				curr_health = max_health
			_: pass
		
		# reset wing trait
		match main.get_classes().get_class_level(CLASS_NAMES[3]):
			1: dodge_chance -= .15
			2: dodge_chance -= .25
			3: dodge_chance -= .35
			_: pass
		
		# reset slayer trait
		if type == 1:
			match main.get_classes().get_class_level(CLASS_NAMES[1]):
				1: 
					omnivamp -= .15
					bonus_dmg -= 0.05
				2: 
					omnivamp -= .15
					bonus_dmg -= 0.1
				3: 
					omnivamp -= .15
					bonus_dmg -= 0.3
				_: pass
				
		# reset cybernatic trait
		if type == 4 and items[0]:
			match main.get_classes().get_class_level(CLASS_NAMES[4]):
				1: 
					max_health -= 200
					curr_health = max_health
					attack_dmg -= 35
				2: 
					max_health -= 400
					curr_health = max_health
					attack_dmg -= 50
				3: 
					max_health -= 700
					curr_health = max_health
					attack_dmg -= 70
				_: pass
		
		# reset duelist trait
		attack_speed -= bonus_attack_speed
		bonus_attack_speed = 0
		duelist_counter = 0
		
		# reset shurima
		var fruit_timer = get_node_or_null("fruit_trait")
		if fruit_timer: fruit_timer.queue_free()
	
		set_collision_layer_value(5, false)
		
		if not is_multiplayer_authority():
			set_bar_color(ENEMY_HOST_COLOR)
			
		curr_mana = start_mana
		
		refresh_manabar()
		
	mode = _mode
	
func _on_aromatic_10sec():
	match main.get_classes().get_class_level(CLASS_NAMES[6]):
		1: 
			armor -= 25
			mr -= 25
		2: 
			armor -= 50
			mr -= 50
		3: 
			armor -= 95
			mr -= 95
		_: pass
	get_node("aromatic_trait").queue_free()
	
func _on_shurima():
	if dead: return
	
	var heal = 0
	
	match main.get_classes().get_class_level(CLASS_NAMES[5]):
		1: heal = min(max_health*0.05, max_health-curr_health)
		2: heal = min(max_health*0.1, max_health-curr_health)
		3: heal = min(max_health*0.2, max_health-curr_health)
		_: pass
		
	curr_health += heal
		
	if heal > 0:	
		refresh_hpbar()
		
		var heal_popup = preload("res://src/damage_popup.tscn").instantiate()
		heal_popup.modulate = Color.LIME_GREEN
		heal_popup.text = str(int(heal))
		add_child(heal_popup)
		heal_popup.global_transform.origin += Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)

func get_mode():
	return mode
			
func find_target():
	if mode != BATTLE or not is_multiplayer_authority(): return
	
	if not player.get_current_enemy(): # pve round
		for pve_round in player.get_node("PVERounds").get_children():	
			if pve_round.visible:
				for minion in pve_round.get_children():
					if not minion.is_targetable(): continue
				
					if not target or global_transform.origin.distance_to(minion.global_transform.origin) < global_transform.origin.distance_to(target.global_transform.origin):
						target = minion
						targeting_neutral = true
				return
	
	var enemy_units = player.get_current_enemy().find_child("Units").get_children()
	
	for unit in enemy_units:	
		if not unit.is_targetable() or unit.dead: continue
		
		#if multiplayer.is_server(): print(unit.name, ": ", global_transform.origin.distance_to(unit.global_transform.origin))
		
		if not target or global_transform.origin.distance_to(unit.global_transform.origin) < global_transform.origin.distance_to(target.global_transform.origin):
			target = unit
			targeting_neutral = false
			
	#if multiplayer.is_server():
	#	if target != null: print(self, " targets ", target)

func change_color(mesh, color):
	var newMaterial = StandardMaterial3D.new()
	newMaterial.albedo_color = color
	mesh.set_surface_override_material(0, newMaterial)

func place_unit(_tile: Node = coll):
	if is_dragging():
		transform.origin.y -= 1
		set_dragging(false)
	elif _tile == coll: return

	toggle_grid(false)
	
	if _tile == null: _tile = tile # if mouse never passes over a collider coll will be null => precaution against this error
	
	change_color(_tile.find_children("MeshInstance3D")[0], Color.CYAN)
	
	if tile == _tile: 
		global_transform.origin = Vector3(tile.global_transform.origin.x, global_transform.origin.y, tile.global_transform.origin.z)
	elif tile != null: 
		if _tile.has_unit(): 
			tile.swap_unit(_tile)
		else:
			if _tile.get_parent().can_place_unit() or get_tile_type() == 1:
				tile.unregister_unit()
				tile = _tile
				tile.register_unit(self)
			else: 
				global_transform.origin = Vector3(tile.global_transform.origin.x, global_transform.origin.y, tile.global_transform.origin.z)

func level_up():
	if star < 3:
		star += 1
		ui.find_child("Star").text = str(star)
		scale += Vector3(.1,.1,.1)
		cost *= 3
		# stats: https://tftactics.gg/db/champion-stats/
		attack_dmg *= 1.8
		max_health *= 1.8
		curr_health = max_health
		
func toggle_ui(value):
	ui.visible = value
	
func get_ui():
	return ui
	
func toggle_grid(value):
	player.get_board_grid().visible = value and timer.is_preparing() and not timer.is_transitioning()
	player.get_bench_grid().visible = value

func set_dragging(value):
	dragging = value
	sell_unit_gui.visible = dragging
	sell_unit_gui.get_node("CostLabel").text = "Sell for " + str(cost) + "g"
	toggle_sync(!value)
	
func is_dragging():
	return dragging
	
func get_owner_id():
	return player.get_id()

func toggle_sync(value):
	if not is_multiplayer_authority(): return
	
	for prop in multisync.replication_config.get_properties():
		#print(prop)
		multisync.replication_config.property_set_watch(prop, value)

func in_attack_range():
	if dead:
		attacking = false
		return
		
	if anim_player.current_animation == walking_anim: 
		play_animation.rpc(idle_anim)
	
	attacking = true
	attack_timer.wait_time = 1/attack_speed
	attack_timer.start()
	
func _on_attack_timer_timeout():	
	if main.get_timer().is_transitioning() or dead:
		attacking = false 
		attack_timer.stop()
	else: auto_attack(target, targeting_neutral)

func auto_attack(_target, pve = false):
	if _target == null or (not pve and _target.get_mode() != BATTLE) or dead: return
	
	match attack_anim1:
		0:
			if attack_anim2 == 0: play_animation.rpc(one_hand_melee_anim, -1, attack_speed)
			else: play_animation.rpc(two_hand_melee_anim, -1, attack_speed)
		1:
			if attack_anim2 == 0: play_animation.rpc(one_hand_ranged_anim, -1, attack_speed)
			else: play_animation.rpc(two_hand_range_anim, -1, attack_speed)
		2:
			if attack_anim2 == 0: play_animation.rpc(one_hand_magic_anim, -1, attack_speed)
			else: play_animation.rpc(two_hand_magic_anim, -1, attack_speed)

	var id = get_multiplayer_authority() if pve else _target.get_owner_id() 

	var rng = randf()
	
	var damage = attack_dmg if rng > crit_chance else attack_dmg * (1+crit_damage)
	damage *= (1+(bonus_dmg*2)) if (_target.get_curr_health()/_target.get_max_health() < 0.66) and type == 1 else (1+bonus_dmg)
	
	var dmg_popup = preload("res://src/damage_popup.tscn").instantiate()
	dmg_popup.modulate = Color.CRIMSON
	if rng <= crit_chance: 
		dmg_popup.modulate = Color.RED
		dmg_popup.scale *= 1.5
	dmg_popup.text = str(int(damage))
	add_child(dmg_popup)
	dmg_popup.global_transform.origin = _target.global_transform.origin + Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
	
	_target.take_dmg.rpc_id(id, damage)
	
	# omnivamp - (we just do raw dmg here as actual dmg is computed in take_dmg func)
	if omnivamp > 0:
		var heal = min(damage*omnivamp, max_health-curr_health)
		curr_health += heal
		if heal > 0:	
			refresh_hpbar()
			
			var heal_popup = preload("res://src/damage_popup.tscn").instantiate()
			heal_popup.modulate = Color.LIME_GREEN
			heal_popup.text = str(int(heal))
			add_child(heal_popup)
			heal_popup.global_transform.origin += Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
	
	# duelist (kinda): - black 
	# for duelists: stacking attack speed up to 12; 5% -> 10% -> 15%
	if type == 2:
		if duelist_counter < 12:
			var tmp = attack_speed
			match main.get_classes().get_class_level(CLASS_NAMES[2]):
				1: attack_speed *= 1.05
				2: attack_speed *= 1.10
				3: attack_speed *= 1.15
				_: pass
			bonus_attack_speed += attack_speed - tmp
			duelist_counter += 1
			
	# mana
	curr_mana = min(max_mana, curr_mana + MANA_PER_ATTACK)
	
	refresh_manabar()
	
	if curr_mana >= max_mana: ability(target, pve)
			
func get_curr_health():
	return curr_health
	
func get_max_health():
	return max_health

func change_attack_speed(val):
	attack_speed = val
	attack_timer.wait_time = 1/attack_speed
	if attacking == true: attack_timer.start()

@rpc("any_peer", "call_local", "unreliable")
func take_dmg(raw_dmg, dmg_type = 0):
	if mode != BATTLE or dead: return
	
	# dodge
	var rng = randf()
	if rng < dodge_chance: return
	
	# https://leagueoflegends.fandom.com/wiki/Armor
	var dmg = raw_dmg / (1+armor/100) if dmg_type == 0 else raw_dmg / (1+mr/100)
	
	# and taking damage generates (1% of pre-mitigation damage taken and 7% of post-mitigation damage taken) mana, up to 42.5 Mana[1][2], depending on the pre-mitigated damage.
	var mana_increase = min(42.5, (.01 * raw_dmg) + (.07 * dmg))
	
	curr_mana = min(max_mana, curr_mana+mana_increase)
		
	refresh_manabar()
	
	if curr_mana >= max_mana: ability(target, targeting_neutral)
	
	curr_health = 0 if dmg >= curr_health else curr_health-dmg
	
	refresh_hpbar()
	
	if curr_health <= 0 and not dead:
		death.rpc()
		
# synced via multiplayersync
func refresh_hpbar():
	ui.get_node("HPBar").value = curr_health/max_health * 100
	
# synced via multiplayersync
func refresh_manabar():
	ui.get_node("MPBar").value = curr_mana/max_mana * 100
		
@rpc("any_peer", "call_local", "reliable")
func death():
	if dead: return
	
	dead = true
	change_mode(PREP)
	visible = false
	
	if multiplayer.is_server():
		var fighter_count = 0
		for u in get_parent().get_children():
			if u.get_mode() == BATTLE: fighter_count += 1
		
		if fighter_count <= 0:
			main.unregister_battle()
			var enemy = player.get_current_enemy()
			
			player.increment_lossstreak.rpc_id(player.get_id())
			
			if enemy: enemy.increment_winstreak.rpc_id(enemy.get_id())

			# https://lolchess.gg/guide/damage?hl=en
			var stage_damage = 0
			var curr_stage = main.get_timer().get_stage()
			if curr_stage == 3: stage_damage = 3
			elif curr_stage == 4: stage_damage = 5
			elif curr_stage == 5: stage_damage = 7
			elif curr_stage == 6: stage_damage = 9
			elif curr_stage == 7: stage_damage = 15
			elif curr_stage >= 8: stage_damage = 150
			
			var unit_damage = 2
			if enemy != null:
				var enemy_unit_count = 0
				for u in enemy.get_node("Units").get_children():
					if is_instance_valid(u) and u != null and u.get_mode() == BATTLE: enemy_unit_count += 1
				match enemy_unit_count:
					1: unit_damage = 2
					2: unit_damage = 4
					3,4,5,6,7,8,9,10: unit_damage = enemy_unit_count+3
			
			player.lose_health.rpc(stage_damage + unit_damage)
			check_battle_status()

# server func
func check_battle_status():	
	if not multiplayer.is_server(): return
	
	#print(main.get_num_of_battles() )
	
	if main.get_num_of_battles() <= 0 and not main.get_timer().is_preparing():
		# all battles have finished => go right into prep phase
		main.get_timer().change_phase()
		
func get_cost():
	return cost
	
func sell_unit():
	player.increase_gold(get_cost())
	set_dragging(false)
	toggle_grid(false)
	tile.unregister_unit()
	if coll == null: coll = tile # if mouse never passes over a collider coll will be null => precaution against this error
	change_color(coll.find_children("MeshInstance3D")[0], Color.CYAN)
	player.erase_unit(self)
	unequip_items()
	main.free_object.rpc(get_path())
	
func set_bar_color(color: Color):
	ui.get_node("HPBar").self_modulate = color
	
@rpc("any_peer", "call_local", "reliable")
func equip_item(item_path):
	if not can_equip_item(): return
	
	var item = get_node(item_path)
	
	for i in range(len(items)):
		if items[i] == null:
			items[i] = item 
			ui.get_node("HBoxContainer/" + str(i)).set_texture(item.get_texture() if item else null) 
			break
		
	var sprite = get_node("Sprite3D")
	if sprite.position.y == 1: sprite.position.y += 0.5
	
	if is_multiplayer_authority() and item:	
		attackrange += item.get_attack_range()
		max_health += item.get_health()
		attack_dmg += item.get_attack_dmg()
		ability_power += item.get_ability_power()
		armor += item.get_armor()
		mr += item.get_mr()
		attack_speed *= 1+item.get_attack_speed()
		crit_chance = min(1, crit_chance + item.get_crit_chance())
		start_mana = min(max_mana, start_mana + item.get_mana())
		if mode == PREP: 
			curr_mana = start_mana
			refresh_manabar()
			curr_health = max_health
			refresh_hpbar()
		
		item.visible = false
	
func can_equip_item():
	for item in items:
		if item == null: return true 
	
	return false
	
func unequip_items():
	for i in range(len(items)):
		if items[i] == null: return
		unequip_item(i)
		
@rpc("any_peer", "call_local", "unreliable")
func unequip_item(index):
	var item = items[index]
	items[index] = null
	item.position = Vector3.ZERO
	
	ui.get_node("HBoxContainer/" + str(index)).set_texture(null)

	if is_multiplayer_authority():
		attackrange -= item.get_attack_range()
		max_health -= item.get_health()
		attack_dmg -= item.get_attack_dmg()
		ability_power -= item.get_ability_power()
		armor -= item.get_armor()
		mr -= item.get_mr()
		attack_speed /= 1-item.get_attack_speed()/100
		crit_chance = max(0, crit_chance - item.get_crit_chance())
		start_mana = max(0, start_mana - item.get_mana()) # NOTE: this can cause issues if item mana was constrained when equipping (rarely happens as there is no feature yet to unequip items except upgrading and selling)
		if mode == PREP: 
			curr_mana = start_mana
			refresh_manabar()
			curr_health = max_health
			refresh_hpbar()
	
		item.visible = true
	
func transfer_items(to_unit):
	for i in range(len(items)):
		var item = items[i]
		if item == null: continue
		unequip_item.rpc(i)
		if to_unit.can_equip_item():
			to_unit.equip_item.rpc(item.get_path())
				
@rpc("any_peer", "call_local", "reliable")
func combatphase_setup(host: bool, host_id: int, attacker_id: int = -1):
	if is_targetable():
		change_mode(BATTLE)
		if not host: 
			var client_id = multiplayer.get_unique_id()
			if attacker_id == -1 or client_id != attacker_id and client_id != host_id:
				set_bar_color(ENEMY_ATTACKER_COLOR)
	else: toggle_ui(false)
	
func get_class_name():
	return CLASS_NAMES[type]
	
func get_unit_name():
	return unit_name
	
func get_image():
	return image
	
func get_trait():
	return type
	
@rpc("any_peer", "call_local", "unreliable")
func play_animation(name: StringName = "", custom_blend: float = -1, custom_speed: float = 1.0, from_end: bool = false):
	anim_player.play(name, custom_blend, custom_speed, from_end)
	
func ability(_target, pve = false):	
	curr_mana = 0
	
	refresh_manabar()
	
	match ability_id:
		0: 
			if _target == null or (not pve and _target.get_mode() != BATTLE) or dead: return
	
			match attack_anim1:
				0:
					if attack_anim2 == 0: play_animation.rpc(one_hand_melee_anim, -1, attack_speed)
					else: play_animation.rpc(two_hand_melee_anim, -1, attack_speed)
				1:
					if attack_anim2 == 0: play_animation.rpc(one_hand_ranged_anim, -1, attack_speed)
					else: play_animation.rpc(two_hand_range_anim, -1, attack_speed)
				2:
					if attack_anim2 == 0: play_animation.rpc(one_hand_magic_anim, -1, attack_speed)
					else: play_animation.rpc(two_hand_magic_anim, -1, attack_speed)

			var id = get_multiplayer_authority() if pve else _target.get_owner_id() 

			var damage = ability_power * scaling1 if ability_dmg_type == 1 else attack_dmg * scaling1
			var crit = false
			if ability_crit:
				var rng = randf()
			
				damage = damage if rng > crit_chance else damage * (1+crit_damage)
				if rng <= crit_chance: crit = true
			
			damage *= (1+(bonus_dmg*2)) if (_target.get_curr_health()/_target.get_max_health() < 0.66) and type == 1 else (1+bonus_dmg)
			
			var dmg_popup = preload("res://src/damage_popup.tscn").instantiate()
			dmg_popup.modulate = Color.CRIMSON if type == 0 else Color.DODGER_BLUE
			if crit: 
				dmg_popup.modulate = Color.BLUE
				dmg_popup.scale *= 1.5
			dmg_popup.text = str(int(damage))
			add_child(dmg_popup)
			dmg_popup.global_transform.origin = _target.global_transform.origin + Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
			
			_target.take_dmg.rpc_id(id, damage, ability_dmg_type)
			
			# omnivamp - (we just do raw dmg here as actual dmg is computed in take_dmg func)
			if omnivamp > 0:
				var heal = min(damage*omnivamp, max_health-curr_health)
				curr_health += heal
				if heal > 0:	
					refresh_hpbar()
					
					var heal_popup = preload("res://src/damage_popup.tscn").instantiate()
					heal_popup.modulate = Color.LIME_GREEN
					heal_popup.text = str(int(heal))
					add_child(heal_popup)
					heal_popup.global_transform.origin += Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
		_: pass
