extends CharacterBody3D

var dragging: bool = false
@onready var sell_unit_gui = main.get_ui().get_node("UnitShop/SellUnit")
var initial_pos: Vector3

var coll
var tile

var main
var player
var round_timer: Timer

var myid

var multisync

@export_file("*.png", "*.jpg") var image
@export var unit_name: String
@export var unit_id = 0
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
var shield = 0.0
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
var bonus_dmg = 0.0 # slayer in percent

# (mostly) item related stats
# adapt and shojin
var mana_on_dmg = 0
var mana_per_attack = 10
#archangels
var as_bonus_ap = 0
# gunblade
var heal_lowest_ally = false
# hand of justice
var double = {} # 1: attackdmg und ap; 2: omnivamp
# guinsoo
var rageblade_stacking = false
var rageblade_stacks = 0
var rageblade_labels = {}
# titans resolve
var titans_stacking = false
var tr_stacks = 0
var titans_labels = {}
# giant slayer
var giant_slayer = false
# deathblade
var deathblade_bonus_dmg = 0.0
# steadfast
var steadfast_reduction = 0.0
# rabadons
var rabadons_bonus_dmg = 0.0
# more and sunfire # red buff
var wounded = false
var wound = 0.0
var burned_enemies = {} # enemy: stacks | at 4 stacks remove
var burn_timer = null
var morello = false
var redbuff = false
const RB_BONUS_DMG = 0.06
# bloodthirster 
var bt_passive_ready = false
var bt_shield = 0
# bramble
var bramble = false
var bramble_ready = false
var bramble_dmg = 0
# crownguard 
var crownguards = 0
# guardbreaker
var guardbreaker_bonus_dmg = 0.0
var guardbreaker_bonus_active = false
# blue buff
const BB_BONUS_DMG = 0.08
var bb_active = false
# edge of night
var eon_target = null
var eon_passive_ready = false
# steraks gage
var sg_bonus_ad = 0
var sg_bonus_health = 0
var sg_passive_ready = false
# runaans
var runaans_count = 0
const RUNAANS_DMG = 0.55
# stattiks
var statikks = false
var statikk_attack_counter = 0
var curr_shred = 0.0
const STATIKK_MAGIC_DMG = 35
const STATIKK_SHRED_AMOUNT = 0.30
const STATIKK_SHRED_DURATION = 5.0
const STATIKK_CHAIN_COUNT = 4
# last whisper
var last_whisper = false
var curr_sunder = 0.0
const LAST_WHISPER_SUNDER_AMOUNT = 0.3
const LAST_WHISPER_DURATION = 3
# nashors tooth
const NASHORS_AS_BUFF = 0.4
const NASHORS_DURATION = 5.0
var nashor_as_bonus = 0.0
# gargoyle
var targeting_count = 0
var gargoyle_count = 0
const GARGOYLE_BUFF = 10
# protectors vow
var pv_count = 0
var pv_passive_ready = false
# ionic spark
const SPARK_SHRED = 0.45
# evenshroud
const EVS_SUNDER = 0.3
const EVS_START_BUFF = 25
var evs_count = 0

@export_category("Ability")
@export_enum("Enhanced Auto", "Poison Bomb") var ability_id = 0
const ABILITY_TYPES = ["Enhanced AA", "Poison Bomb"]
@onready var ABILITY_TT = [
	"Enhanced Autoattack (ACTIVE): \nStrike the current target with " + str(int(scaling1*100)) + "% / " + str(int(scaling2*100)) + "% / " + str(int(scaling3*100)) + "% " + ABILITY_DMG_TYPES[ability_dmg_type] + " damage.",
	"Poison Bomb (ACTIVE): \n Throw a bag of spoiled tea ingredients at the current target, poisoning them for \n" + str(int(scaling1*100)) + "% / " + str(int(scaling2*100)) + "% / " + str(int(scaling3*100)) + "% " + ABILITY_DMG_TYPES[ability_dmg_type] + " damage over 10 seconds. \nPoison Bomb cannot be stacked on one target by the same unit."
]
@export_enum("AD", "AP", "True") var ability_dmg_type = 1
const ABILITY_DMG_TYPES = ["AD", "AP", "TrueDMG"]
@export var scaling1: float = 1.0
@export var scaling2: float = 1.5
@export var scaling3: float = 2.25
@export var melee_ability_anim: String = "2H_Melee_Attack_Spin"
@export var ranged_ability_anim: String = "2H_Ranged_Shoot"
@export var magic_ability_anim: String = "Spellcast_Raise"
var ability_crit = false
var poisoned_enemies = {} # unit: counter

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
	
	anim_player.get_animation(idle_anim).loop_mode = (Animation.LOOP_LINEAR)
	play_animation(idle_anim, false)
	
func _enter_tree():
	myid = name.get_slice("#", 0).to_int()
	set_multiplayer_authority(myid)
	#print(str(multiplayer.get_unique_id()) + ": " + str(get_multiplayer_authority()))
	
	main = get_tree().root.get_child(0)
	round_timer = main.get_timer()
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
			if anim_player.current_animation != walking_anim: play_animation.rpc(walking_anim, false)
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

	if not is_multiplayer_authority() or not mode == PREP or (get_tile_type() == HEX and not round_timer.is_preparing()): return

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT and !is_dragging():
		set_dragging(true)
		toggle_grid(true)
		change_color(tile.find_children("MeshInstance3D")[0], Color.WHITE)	
		initial_pos = global_transform.origin

		transform.origin.y += 1

func _input(event):
	if not is_multiplayer_authority() or not mode == PREP or (get_tile_type() == HEX and not round_timer.is_preparing()): return
	
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
	
	mode = _mode
	
	if not is_multiplayer_authority(): return
		
	play_animation(idle_anim, false)
	
	# reset buff
	_on_nashor_end()
	for i in range(targeting_count):
		decrease_targeting_count() # gargoyle
	
	if _mode == BATTLE:
		
		# ========== ITEMS =================
		
		var item_index = 0
		for item in items:
			if item == null: continue
			
			match item.get_item_name():
				"Adaptive Helm":
					# Combat start: Gain different bonuses based on starting position.
					if tile.get_row() < 2:
						# Front Two Rows: 40 Armor and Magic Resist. Gain 1 Mana when struck by an attack.
						armor += 40
						mr += 40
						mana_on_dmg += 1
					else:
						# Back Two Rows: 20 Ability Power. Gain 10 Mana every 3 seconds.
						ability_power += 20
						var timer = Timer.new()
						add_child(timer)
						timer.name = str(item.name)
						timer.wait_time = 3
						timer.one_shot = false
						timer.connect("timeout", _on_adaptive_helm_3sec)
						timer.start()	
				"Archangel's Staff":
					#Combat start: Grant 30 Ability Power every 5 seconds.
					var timer = Timer.new()
					add_child(timer)
					timer.name = str(item.name)
					timer.wait_time = 5
					timer.one_shot = false
					timer.connect("timeout", _on_archangels_staff)
					timer.start()	
				"Bloodthirster":
					# Once per combat at 40% Health, gain a 25% maximum Health shield that lasts up to 5 seconds.
					if curr_health/max_health >= 0.4: 
						bt_passive_ready = true
					bt_shield += 0.25
				"Edge of Night":
					# Once per combat: At 60% Health, briefly become untargetable and shed negative effects. Then, gain 15% bonus Attack Speed.
					if curr_health/max_health >= 0.6:
						eon_passive_ready = true
				"Bramble Vest":
					bramble = true
					bramble_ready = true
					bramble_dmg += 100
					max_health *= 1.05
					curr_health = max_health
					refresh_hpbar()
					var timer = get_node_or_null("bramble_timer")
					if not timer:
						timer = Timer.new()
						add_child(timer)
						timer.name = "bramble_timer"
						timer.wait_time = 2
						timer.one_shot = true
						timer.connect("timeout", _on_bramble)
				"Crownguard":
					shield += 0.3*max_health
					refresh_shieldbar()
					crownguards += 1
					var timer = get_node_or_null("crownguard_timer")
					if not timer:
						timer = Timer.new()
						add_child(timer)
						timer.name = "crownguard_timer"
						timer.wait_time = 8 + main.get_timer().TRANSITION_TIME
						timer.one_shot = false
						timer.connect("timeout", _on_crownguard)
						timer.start()
				"Deathblade":
					deathblade_bonus_dmg += 0.08
				"Dragon's Claw":
					# Every 2 seconds, regenerate 5% maximum Health.
					var timer = Timer.new()
					add_child(timer)
					timer.name = str(item.name)
					timer.wait_time = 2
					timer.one_shot = false
					timer.connect("timeout", _on_dragons_claw)
					timer.start()	
				"Titan's Resolve":
					# Grants 2 Attack Damage and 2 Ability Power when attacking or taking damage, stacking up to 25 times. At full stacks, grant 20 Armor and 20 Magic Resist.
					titans_labels[item] = get_ui().get_node("HBoxContainer/" + str(item_index) + "/Counter")
					titans_labels[item].visible = true
					titans_labels[item].text = str(tr_stacks)
					titans_stacking = true
				"Guardbreaker":
					guardbreaker_bonus_dmg += 0.25
				"Giant Slayer":
					giant_slayer = true
				"Guinsoo's Rageblade":
					rageblade_labels[item] = get_ui().get_node("HBoxContainer/" + str(item_index) + "/Counter")
					rageblade_labels[item].visible = true
					rageblade_labels[item].text = str(rageblade_stacks)
					rageblade_stacking = true
				"Hand of Justice":
					#Grant 2 effects:
					#+15 Attack Damage and +15 Ability Power
					#15% Omnivamp
					#Each round, randomly double 1 of these effects.
					double[item] = randi_range(0,1)
					if double[item] == 0: 
						attack_dmg += 15
						ability_power += 15
					else: omnivamp += .15
				"Hextech Gunblade":
					heal_lowest_ally = true
				"Morellonomicon":
					if not burn_timer: 
						var timer = Timer.new()
						add_child(timer)
						timer.name = "burn_timer"
						timer.wait_time = 1
						timer.one_shot = false
						timer.connect("timeout", _on_burn)
						timer.start()
					morello = true
				"Red Buff":
					if not burn_timer: 
						var timer = Timer.new()
						add_child(timer)
						timer.name = "burn_timer"
						timer.wait_time = 1
						timer.one_shot = false
						timer.connect("timeout", _on_burn)
						timer.start()
					redbuff = true
				"Sunfire Cape":
					var sunfire_timer = get_node_or_null("sunfire_timer")
					if not sunfire_timer:
						# Every 2 seconds, an enemy within 2 hexes is 1% Burned and 33% Wounded for 10 seconds.
						var timer = Timer.new()
						add_child(timer)
						timer.name = "sunfire_timer"
						timer.wait_time = 2
						timer.one_shot = false
						timer.connect("timeout", _on_sunfire)
						timer.start()
					if not burn_timer: 
						var timer = Timer.new()
						add_child(timer)
						timer.name = "burn_timer"
						timer.wait_time = 1
						timer.one_shot = false
						timer.connect("timeout", _on_burn)
						timer.start()
				"Ionic Spark":
					var spark_timer = get_node_or_null("spark_timer")
					if not spark_timer:
						# Every second shred enemies within 2 hexes for 1 second
						var timer = Timer.new()
						add_child(timer)
						timer.name = "spark_timer"
						timer.wait_time = 1
						timer.one_shot = false
						timer.connect("timeout", _on_spark)
						timer.start()
				"Evenshroud":
					evs_count += 1
					armor += EVS_START_BUFF
					mr += EVS_START_BUFF
					var evs_start_timer = get_node_or_null("evs_start_timer")
					if not evs_start_timer:
						# Gain 25 Armor and Magic Resist for the first 10 seconds of combat
						var timer = Timer.new()
						add_child(timer)
						timer.name = "evs_start_timer"
						timer.wait_time = 10
						timer.one_shot = true
						timer.connect("timeout", _on_evs_start)
						timer.start()
					
					var evs_timer = get_node_or_null("evs_timer")
					if not evs_timer:
						# Every second sunder enemies within 2 hexes for 1 second
						var timer = Timer.new()
						add_child(timer)
						timer.name = "evs_timer"
						timer.wait_time = 1
						timer.one_shot = false
						timer.connect("timeout", _on_evs)
						timer.start()
				"Spear of Shojin":
					mana_per_attack += 5
				"Steadfast Heart":
					# Take 8% less damage. While above 50% Health, take 15% less damage, instead.
					steadfast_reduction += 0.08
				"Sterak's Gage":
					sg_bonus_ad += 35
					sg_bonus_health += 0.25
					sg_passive_ready = true
				"Statikk Shiv":
					statikks = true
				"Warmog's Armor":
					max_health *= 1.08
					curr_health = max_health
					refresh_hpbar()
				"Rabadon's Deathcap":
					rabadons_bonus_dmg += 0.2
				"Runaan's Hurricane":
					runaans_count += 1
				"Last Whisper":
					last_whisper = true
				"Nashor's Tooth":
					nashor_as_bonus += NASHORS_AS_BUFF
				"Gargoyle Stoneplate":
					gargoyle_count += 1
				"Protector's Vow":
					pv_passive_ready = true
					pv_count += 1
				_: pass
			item_index += 1
		
		# ========== TRAITS ================	
		
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
	else: #================================================ RESET ===============================================
		for item in items:
			if item == null: continue
			
			match item.get_item_name():
				"Adaptive Helm":
					# Combat start: Gain different bonuses based on starting position.
					if tile.get_row() < 2:
						# Front Two Rows: 40 Armor and Magic Resist. Gain 1 Mana when struck by an attack.
						armor -= 40
						mr -= 40
						mana_on_dmg -= 1
					else:
						# Back Two Rows: 20 Ability Power. Gain 10 Mana every 3 seconds.
						ability_power -= 20
						var adapt_timer = get_node_or_null(str(item.name))
						if adapt_timer: adapt_timer.queue_free()
				"Archangel's Staff":
					# Combat start: Grant 30 Ability Power every 5 seconds.
					ability_power -= as_bonus_ap
					var arch_timer = get_node_or_null(str(item.name))
					if arch_timer: arch_timer.queue_free()
				"Bloodthirster":
					# Once per combat at 40% Health, gain a 25% maximum Health shield that lasts up to 5 seconds.
					bt_passive_ready = false
					bt_shield -= 0.25
					var bt_timer = get_node_or_null("bt_timer")
					if bt_timer: bt_timer.queue_free()
				"Edge of Night":
					if not eon_passive_ready:
						change_attack_speed(attack_speed / 1.15)
					else: eon_passive_ready = false
				"Bramble Vest":
					bramble = false
					bramble_ready = false
					bramble_dmg -= 100
					var bramble_timer = get_node_or_null("bramble_timer")
					if bramble_timer: bramble_timer.queue_free()
					max_health /= 1.05
					if curr_health > max_health: curr_health = max_health
				"Crownguard":
					var timer = get_node_or_null("crownguard_timer")
					if timer: timer.queue_free()
					ability_power -= crownguards*35
					crownguards = 0
				"Deathblade":
					deathblade_bonus_dmg -= 0.08
				"Dragon's Claw":
					var dragons_claw_timer = get_node_or_null(str(item.name))
					if dragons_claw_timer: dragons_claw_timer.queue_free()
				"Titan's Resolve":
					titans_labels[item].visible = false
					titans_stacking = false
					attack_dmg -= 2 * tr_stacks * len(titans_labels)
					ability_power -= 2 * tr_stacks * len(titans_labels)
					if tr_stacks >= 25:
						armor -= 20 * len(titans_labels)
						mr -= 20 * len(titans_labels)
					tr_stacks = 0
					titans_labels.erase(item)
				"Guardbreaker":
					guardbreaker_bonus_dmg -= 0.25
				"Giant Slayer":
					giant_slayer = true
				"Guinsoo's Rageblade":
					rageblade_labels[item].visible = false
					rageblade_stacking = false
					rageblade_stacks = 0
					rageblade_labels.erase(item)
				"Hand of Justice":
					#Grant 2 effects:
					#+15 Attack Damage and +15 Ability Power
					#15% Omnivamp
					#Each round, randomly double 1 of these effects.
					if double[item] == 0: 
						attack_dmg -= 15
						ability_power -= 15
					else: omnivamp -= .15
					double.erase(item)
				"Hextech Gunblade":
					heal_lowest_ally = false
				"Morellonomicon":
					morello = true
					var burn_timer = get_node_or_null("burn_timer")
					if burn_timer: burn_timer.queue_free()
				"Red Buff":
					redbuff = true
					var burn_timer = get_node_or_null("burn_timer")
					if burn_timer: burn_timer.queue_free()
				"Sunfire Cape":
					var sunfire_timer = get_node_or_null("sunfire_timer")
					if sunfire_timer: sunfire_timer.queue_free()
					
					var burn_timer = get_node_or_null("burn_timer")
					if burn_timer: burn_timer.queue_free()
				"Ionic Spark":
					var spark_timer = get_node_or_null("spark_timer")
					if spark_timer: spark_timer.queue_free()
				"Evenshroud":
					var evs_timer = get_node_or_null("evs_timer")
					if evs_timer: evs_timer.queue_free()
					
					_on_evs_start()
				"Spear of Shojin":
					mana_per_attack -= 5
				"Steadfast Heart":
					steadfast_reduction -= 0.08
				"Sterak's Gage":
					if sg_bonus_ad > 0:
						attack_dmg -= sg_bonus_ad
						sg_bonus_ad = 0
					if sg_bonus_health > 0:
						max_health /= (1+sg_bonus_health)
						sg_bonus_health = 0
					sg_passive_ready = false
				"Statikk Shiv":
					statikks = false
				"Warmog's Armor":
					max_health /= 1.08
					if curr_health > max_health: curr_health = max_health
				"Rabadon's Deathcap":
					rabadons_bonus_dmg += 0.2
				"Runaan's Hurricane":
					runaans_count = 0
				"Last Whisper":
					last_whisper = false
				"Nashor's Tooth":
					nashor_as_bonus -= NASHORS_AS_BUFF
				"Gargoyle Stoneplate":
					gargoyle_count -= 1
				"Protector's Vow":
					if not pv_passive_ready: # meaning it was used in combat
						armor -= 20
						mr -= 20
					pv_count -= 1
				_: pass
		
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
		
		# reset duelist trait (and guinsoos item) stacking attackspeed
		change_attack_speed(attack_speed - bonus_attack_speed)
		bonus_attack_speed = 0
		duelist_counter = 0
		
		# reset shurima
		var fruit_timer = get_node_or_null("fruit_trait")
		if fruit_timer: fruit_timer.queue_free()
		
		# reset item
		_on_sunder_end()
	
		set_collision_layer_value(5, false)
		
		if not is_multiplayer_authority():
			set_bar_color(ENEMY_HOST_COLOR)
			
		curr_mana = start_mana
		
		refresh_manabar()
	
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
	
func _on_bramble():
	if dead: return
	bramble_ready = true
	
func _on_shurima():
	if dead: return
	
	var heal = 0
	
	match main.get_classes().get_class_level(CLASS_NAMES[5]):
		1: heal = min(max_health*0.05, max_health-curr_health)
		2: heal = min(max_health*0.1, max_health-curr_health)
		3: heal = min(max_health*0.2, max_health-curr_health)
		_: pass
		
	if wounded: heal -= heal * wound
		
	curr_health += heal
		
	if heal > 0:	
		refresh_hpbar()
		
		var heal_popup = preload("res://src/damage_popup.tscn").instantiate()
		heal_popup.modulate = Color.LIME_GREEN
		heal_popup.text = "+" + str(int(heal))
		add_child(heal_popup)
		heal_popup.global_transform.origin += Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)

func _on_adaptive_helm_3sec():
	curr_mana = min(curr_mana+10, max_mana)
	refresh_manabar()
	
func _on_archangels_staff():
	as_bonus_ap += 30
	ability_power += 30

func _on_dragons_claw():
	var heal = min(max_health * .05, max_health-curr_health)
	if wounded: heal -= heal * wound
	if heal > 0:
		curr_health += heal
		refresh_hpbar()
		var heal_popup = preload("res://src/damage_popup.tscn").instantiate()
		heal_popup.modulate = Color.LIME_GREEN
		heal_popup.text = "+" + str(int(heal))
		add_child(heal_popup)
		heal_popup.global_transform.origin += Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)

func _on_evs_start():
	var evs_start_timer = get_node_or_null("evs_start_timer")
	if evs_start_timer:
		armor -= evs_count*EVS_START_BUFF
		mr -= evs_count*EVS_START_BUFF
		evs_start_timer.queue_free()
	
func _on_evs():
	if not player.get_current_enemy(): # pve round
		for pve_round in player.get_node("PVERounds").get_children():	
			if pve_round.visible:
				for minion in pve_round.get_children():
					if not minion.is_targetable(): continue
				
					if global_transform.origin.distance_to(minion.global_transform.origin) < 4:
						minion.apply_sunder(EVS_SUNDER, 1)
		return
	
	var enemy_units = player.get_current_enemy().find_child("Units").get_children()
	
	for unit in enemy_units:	
		if not unit.is_targetable() or unit.dead: continue
	
		if global_transform.origin.distance_to(unit.global_transform.origin) < 4:
			unit.apply_sunder.rpc_id(unit.get_owner_id(), EVS_SUNDER, 1)
	
func _on_spark():
	if not player.get_current_enemy(): # pve round
		for pve_round in player.get_node("PVERounds").get_children():	
			if pve_round.visible:
				for minion in pve_round.get_children():
					if not minion.is_targetable(): continue
				
					if global_transform.origin.distance_to(minion.global_transform.origin) < 4:
						minion.apply_shred(SPARK_SHRED, 1)
		return
	
	var enemy_units = player.get_current_enemy().find_child("Units").get_children()
	
	for unit in enemy_units:	
		if not unit.is_targetable() or unit.dead: continue
	
		if global_transform.origin.distance_to(unit.global_transform.origin) < 4:
			unit.apply_shred.rpc_id(unit.get_owner_id(), SPARK_SHRED, 1)
	
func _on_sunfire():
	if not player.get_current_enemy(): # pve round
		for pve_round in player.get_node("PVERounds").get_children():	
			if pve_round.visible:
				for minion in pve_round.get_children():
					if not minion.is_targetable(): continue
				
					if global_transform.origin.distance_to(minion.global_transform.origin) < 4:
						minion.be_wounded.rpc()
						burned_enemies[minion] = 4
		return
	
	var enemy_units = player.get_current_enemy().find_child("Units").get_children()
	
	for unit in enemy_units:	
		if not unit.is_targetable() or unit.dead: continue
	
		if global_transform.origin.distance_to(unit.global_transform.origin) < 4:
			unit.be_wounded.rpc()
			burned_enemies[unit] = 4
			
func _on_edge_of_night():
	change_attack_speed(attack_speed * 1.15)
	
	var enemy_units = []
	
	if not player.get_current_enemy(): # pve round
		for pve_round in player.get_node("PVERounds").get_children():	
			if pve_round.visible:
				enemy_units = pve_round.get_children()
	else:
		enemy_units = player.get_current_enemy().find_child("Units").get_children()
	
	for unit in enemy_units:	
		if unit.dead: continue
		
		unit.receive_eon_effect.rpc_id(unit.get_multiplayer_authority(), get_path())

@rpc("any_peer", "call_local", "unreliable")
func receive_eon_effect(eon_owner_path: NodePath):
	var eon_owner = get_node(eon_owner_path)
	
	if eon_owner == target:
		eon_target = target
		target.decrease_targeting_count.rpc_id(target.get_owner_id())
		target = null

func _on_burn():
	for e in burned_enemies:
		if not e or not is_instance_valid(e): 
			burned_enemies.erase(e)
			continue
		
		var damage = e.get_max_health() * 0.01
		if bb_active: damage *= 1+BB_BONUS_DMG
		if redbuff: damage *= 1+RB_BONUS_DMG
		
		var dmg_popup = preload("res://src/damage_popup.tscn").instantiate()
		dmg_popup.modulate = Color.WHITE
		dmg_popup.text = str(int(damage))
		add_child(dmg_popup)
		dmg_popup.global_transform.origin = e.global_transform.origin + Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
	
		e.take_dmg.rpc_id(e.get_multiplayer_authority(), damage, 2, false, get_path())
		
		burned_enemies[e] -= 1
		if burned_enemies[e] <= 0:
			burned_enemies.erase(e)
			
func _on_bt_passive_end():
	shield = max(0, shield-(bt_shield*max_health))
	refresh_shieldbar()
	var bt_timer = get_node_or_null("bt_timer")
	if bt_timer: bt_timer.queue_free()
	
func _on_pv_passive_end():
	shield = max(0, shield-(0.25*pv_count*max_health))
	refresh_shieldbar()
	var pv_timer = get_node_or_null("pv_timer")
	if pv_timer: pv_timer.queue_free()
	
func _on_crownguard():
	ability_power += 35*crownguards
	shield = max(0, shield-(max_health*0.3*crownguards))
	refresh_shieldbar()
	var timer = get_node_or_null("crownguard_timer")
	if timer: timer.queue_free()
	
func _on_guardbreaker_end():
	guardbreaker_bonus_active = false
	var timer = get_node_or_null("guardbreaker_timer")
	if timer: timer.queue_free()
	
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
		if not unit.is_targetable() or unit.dead or unit == eon_target: continue
		
		#if multiplayer.is_server(): print(unit.name, ": ", global_transform.origin.distance_to(unit.global_transform.origin))
		
		if not target or global_transform.origin.distance_to(unit.global_transform.origin) < global_transform.origin.distance_to(target.global_transform.origin):
			if target: target.decrease_targeting_count.rpc_id(target.get_owner_id())
			target = unit
			target.increase_targeting_count.rpc_id(target.get_owner_id())
			eon_target = null
			targeting_neutral = false
			
	# in case no other valid target was found but there is still the untargetable edge of night one
	if not target and eon_target:
		target = eon_target
		target.increase_targeting_count.rpc_id(target.get_owner_id())
		eon_target = null

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
		
		if star == 3: main.exclude_from_pool(get_unit_id())
		
func toggle_ui(value):
	ui.visible = value
	
func get_ui():
	return ui
	
func toggle_grid(value):
	player.get_board_grid().visible = value and round_timer.is_preparing() and not round_timer.is_transitioning()
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
		play_animation.rpc(idle_anim, false)
	
	attacking = true
	attack_timer.wait_time = 1/attack_speed
	attack_timer.start()
	
func _on_attack_timer_timeout():	
	if main.get_timer().is_transitioning() or dead:
		attacking = false 
		attack_timer.stop()
	else: auto_attack(target, targeting_neutral)

func apply_statikk_effect(_target, id):
	statikk_attack_counter += 1
	if statikk_attack_counter >= 3:
		statikk_attack_counter = 0
		
		var potential_targets = []
		
		# Handle PVE rounds
		if not player.get_current_enemy():
			for pve_round in player.get_node("PVERounds").get_children():
				if not pve_round.visible:
					continue
					
				for minion in pve_round.get_children():
					if not minion.is_targetable() or minion == _target:
						continue
					# Store distance to main target for sorting
					var distance_to_target = minion.global_transform.origin.distance_to(_target.global_transform.origin)
					potential_targets.append({"unit": minion, "distance": distance_to_target})
		
		# Handle PVP rounds
		else:
			var enemy_units = player.get_current_enemy().find_child("Units").get_children()
			for unit in enemy_units:
				if not unit.is_targetable() or unit.dead or unit == _target:
					continue
				# Store distance to main target for sorting
				var distance_to_target = unit.global_transform.origin.distance_to(_target.global_transform.origin)
				potential_targets.append({"unit": unit, "distance": distance_to_target})
		
		# Sort potential targets by distance to main target
		potential_targets.sort_custom(func(a, b): return a.distance < b.distance)
		
		# Apply chain lightning to closest targets (up to STATIKK_CHAIN_COUNT)
		for i in range(min(STATIKK_CHAIN_COUNT, potential_targets.size())):
			var target_unit = potential_targets[i].unit
			
			# Apply magic damage and shred
			target_unit.apply_shred.rpc_id(id, STATIKK_SHRED_AMOUNT, STATIKK_SHRED_DURATION)
			target_unit.take_dmg.rpc_id(id, STATIKK_MAGIC_DMG, 0, false, get_path())  # Magic damage
			
			# Create damage popup for Statikk
			var dmg_popup = preload("res://src/damage_popup.tscn").instantiate()
			dmg_popup.modulate = Color.BLUE 
			dmg_popup.text = str(STATIKK_MAGIC_DMG)
			add_child(dmg_popup)
			dmg_popup.global_transform.origin = target_unit.global_transform.origin + Vector3(randf_range(-.5, .5), randf_range(0, 1), 0.5)

func auto_attack(_target, pve = false):
	if _target == null or (not pve and _target.get_mode() != BATTLE) or _target.dead or dead: return
	
	match attack_anim1:
		0:
			if attack_anim2 == 0: play_animation.rpc(one_hand_melee_anim, true, -1, attack_speed)
			else: play_animation.rpc(two_hand_melee_anim, true, -1, attack_speed)
		1:
			if attack_anim2 == 0: play_animation.rpc(one_hand_ranged_anim, true, -1, attack_speed)
			else: play_animation.rpc(two_hand_range_anim, true, -1, attack_speed)
		2:
			if attack_anim2 == 0: play_animation.rpc(one_hand_magic_anim, true, -1, attack_speed)
			else: play_animation.rpc(two_hand_magic_anim, true, -1, attack_speed)

	var id = get_multiplayer_authority() if pve else _target.get_owner_id() 

	var rng = randf()
	
	var damage = attack_dmg if rng > crit_chance else attack_dmg * (1+crit_damage)
	damage *= 1+deathblade_bonus_dmg
	damage *= 1+rabadons_bonus_dmg
	if guardbreaker_bonus_active: damage *= 1+guardbreaker_bonus_dmg
	if bb_active: damage *= 1+BB_BONUS_DMG
	if redbuff: damage *= 1+RB_BONUS_DMG
	damage *= (1+(bonus_dmg*2)) if (_target.get_curr_health()/_target.get_max_health() < 0.66) and type == 1 else (1+bonus_dmg)
	if _target.get_max_health() > 1750 and giant_slayer: 
		damage*=1.25
		
	if morello or redbuff: 
		_target.be_wounded.rpc_id(_target.get_multiplayer_authority())
		burned_enemies[_target] = 4
	
	var dmg_popup = preload("res://src/damage_popup.tscn").instantiate()
	dmg_popup.modulate = Color.CRIMSON
	if rng <= crit_chance: 
		dmg_popup.modulate = Color.RED
		dmg_popup.scale *= 1.5
	dmg_popup.text = str(int(damage))
	add_child(dmg_popup)
	dmg_popup.global_transform.origin = _target.global_transform.origin + Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
	
	# runaans
	if runaans_count > 0:
		var potential_targets = []
		
	 # Handle PVE rounds
		if not player.get_current_enemy():
			for pve_round in player.get_node("PVERounds").get_children():
				if not pve_round.visible:
					continue
					
				for minion in pve_round.get_children():
					if not minion.is_targetable() or minion == _target:
						continue
					# Store distance to main target for sorting
					var distance_to_target = minion.global_transform.origin.distance_to(_target.global_transform.origin)
					potential_targets.append({"unit": minion, "distance": distance_to_target})
		
		# Handle PVP rounds
		else:
			var enemy_units = player.get_current_enemy().find_child("Units").get_children()
			for unit in enemy_units:
				if not unit.is_targetable() or unit.dead or unit == _target:
					continue
				# Store distance to main target for sorting
				var distance_to_target = unit.global_transform.origin.distance_to(_target.global_transform.origin)
				potential_targets.append({"unit": unit, "distance": distance_to_target})
		
		# Sort potential targets by distance to main target
		potential_targets.sort_custom(func(a, b): return a.distance < b.distance)
		
		# Attack the closest units (up to runaans_count)
		for i in range(min(runaans_count, potential_targets.size())):
			var target_unit = potential_targets[i].unit
			
			if last_whisper:
				target_unit.apply_sunder.rpc_id(id, LAST_WHISPER_SUNDER_AMOUNT, LAST_WHISPER_DURATION)
			
			# Apply Runaan's damage
			target_unit.take_dmg.rpc_id(id, damage * RUNAANS_DMG, 0, true, get_path())
			
			var dmg_popup_rn = preload("res://src/damage_popup.tscn").instantiate()
			dmg_popup_rn.modulate = Color.CRIMSON
			if rng <= crit_chance: 
				dmg_popup_rn.modulate = Color.RED
				dmg_popup_rn.scale *= 1.5
			dmg_popup_rn.text = str(int(damage * RUNAANS_DMG))
			add_child(dmg_popup_rn)
			dmg_popup_rn.global_transform.origin = target_unit.global_transform.origin + Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)	
	
	if statikks: apply_statikk_effect(_target, id)
	
	if last_whisper: target.apply_sunder.rpc_id(id, LAST_WHISPER_SUNDER_AMOUNT, LAST_WHISPER_DURATION)
	_target.take_dmg.rpc_id(id, damage, 0, true, get_path())
	
	# guardbreaker
	if _target.is_shielded() and guardbreaker_bonus_dmg > 0:
		guardbreaker_bonus_active = true
		var timer = get_node_or_null("guardbreaker_timer")
		if not timer:
			timer = Timer.new()
			timer.name = "guardbreaker_timer"
			add_child(timer)
		timer.wait_time = 3
		timer.one_shot = false
		timer.connect("timeout", _on_guardbreaker_end)
		timer.start()
	
	# omnivamp - (we just do raw dmg here as actual dmg is computed in take_dmg func)
	if omnivamp > 0:
		var heal = min(damage*omnivamp, max_health-curr_health)
		if wounded: heal -= heal * wound
		curr_health += heal
		if heal > 0:	
			refresh_hpbar()
			
			var heal_popup = preload("res://src/damage_popup.tscn").instantiate()
			heal_popup.modulate = Color.LIME_GREEN
			heal_popup.text = "+" + str(int(heal))
			add_child(heal_popup)
			heal_popup.global_transform.origin += Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
		if heal_lowest_ally:
			var lowest_ally = null
			var lowest_percent = 1
			for unit in get_parent().get_children():
				if unit == self: continue
				
				var percent = unit.get_curr_health()/unit.get_max_health()
				if unit.get_mode() == BATTLE and percent < lowest_percent:
					lowest_ally = unit
					lowest_percent = percent
			if lowest_ally:
				var ally_heal = min(damage*0.2, lowest_ally.get_max_health()-lowest_ally.get_curr_health())
				lowest_ally.curr_health += ally_heal #0.2 gunblade heal
				lowest_ally.refresh_hpbar()
			
				var heal_popup = preload("res://src/damage_popup.tscn").instantiate()
				heal_popup.modulate = Color.LIME_GREEN
				heal_popup.text = "+" + str(int(ally_heal))
				lowest_ally.add_child(heal_popup)
				heal_popup.global_transform.origin += Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
	
	# rageblade
	if rageblade_stacking and not affected_by_urf:
		rageblade_stacks += 1
		for item in rageblade_labels:
			rageblade_labels[item].text = str(rageblade_stacks)
			bonus_attack_speed += attack_speed*1.05 - attack_speed
			change_attack_speed(attack_speed*1.05)
			
	# Titans resolve
	if titans_stacking and tr_stacks < 25:
		tr_stacks += 1
		for item in titans_labels:
			titans_labels[item].text = str(tr_stacks)
			attack_dmg += 2
			ability_power += 2
			if tr_stacks >= 25:
				armor += 20
				mr += 20
	
	# duelist (kinda): - black 
	# for duelists: stacking attack speed up to 12; 5% -> 10% -> 15%
	if type == 2 and not affected_by_urf:
		if duelist_counter < 12:
			match main.get_classes().get_class_level(CLASS_NAMES[2]):
				1: 
					bonus_attack_speed += attack_speed*1.05 - attack_speed
					change_attack_speed(attack_speed*1.05)
				2: 
					bonus_attack_speed += attack_speed*1.05 - attack_speed
					change_attack_speed(attack_speed*1.1)
				3: 
					bonus_attack_speed += attack_speed*1.05 - attack_speed
					change_attack_speed(attack_speed*1.15)
				_: pass
			duelist_counter += 1
			
	# mana
	curr_mana = min(max_mana, curr_mana + mana_per_attack)
	
	refresh_manabar()
	
	if curr_mana >= max_mana: ability(target, pve)
			
func get_curr_health():
	return curr_health
	
func get_max_health():
	return max_health
	
func get_curr_shield():
	return shield

func change_attack_speed(val):
	attack_speed = val
	attack_timer.wait_time = 1/attack_speed
	if attacking == true: attack_timer.start()
	
func apply_nashor():
	var nashor_timer = get_node_or_null("nashor_timer")
	
	if nashor_timer: nashor_timer.queue_free() # Remove old timer if it exists
	
	# Create and start a new timer for Nashor's effect duration
	var timer = Timer.new()
	add_child(timer)
	timer.name = "nashor_timer"
	timer.wait_time = NASHORS_DURATION
	timer.one_shot = true
	timer.connect("timeout", _on_nashor_end)
	timer.start()
	
	change_attack_speed(attack_speed * (1 + nashor_as_bonus))

	# print("Nashor's Tooth applied: +", nashor_as_bonus * 100, "% AS bonus")

# Remove Nashor's Tooth effect
func _on_nashor_end():
	var nashor_timer = get_node_or_null("nashor_timer")
	
	if nashor_timer: nashor_timer.queue_free()
	
	# Remove the Nashor's Tooth attack speed bonus
	change_attack_speed(attack_speed / (1 + nashor_as_bonus))

	# print("Nashor's Tooth ended, AS bonus reset")
	
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
func take_dmg(raw_dmg, dmg_type, dodgeable, source: NodePath):
	if mode != BATTLE or dead: return
	
	# dodge
	var rng = randf()
	if rng < dodge_chance and dodgeable: 
		var dodge_popup = preload("res://src/damage_popup.tscn").instantiate()
		dodge_popup.modulate = Color.DIM_GRAY
		dodge_popup.text = "Dodged"
		add_child(dodge_popup)
		dodge_popup.global_transform.origin += Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
		return
	
	# https://leagueoflegends.fandom.com/wiki/Armor
	var dmg = raw_dmg
	if dmg_type == 0:
		dmg /= (1+armor/100) 
	elif dmg_type == 1: 
		raw_dmg / (1+mr/100)
		
	if dmg_type != 2: 
		dmg -= (steadfast_reduction*dmg) if curr_health/max_health < 0.5 else (steadfast_reduction*dmg*2)
		if dmg_type == 0:
			dmg -= (0.08*dmg) # bramble vest: Take 8% reduced damage from attacks.
	
	# and taking damage generates (1% of pre-mitigation damage taken and 7% of post-mitigation damage taken) mana, up to 42.5 Mana[1][2], depending on the pre-mitigated damage.
	var mana_increase = min(42.5, (.01 * raw_dmg) + (.07 * dmg)) + mana_on_dmg
	
	curr_mana = min(max_mana, curr_mana+mana_increase)
		
	refresh_manabar()
	
	if curr_mana >= max_mana: ability(target, targeting_neutral)
	
	if dmg_type != 2 and shield > 0:
		var tmp = shield
		shield = max(0, shield-dmg)
		dmg = dmg - tmp
		refresh_shieldbar()
	
	if dmg > 0: 
		curr_health = 0 if dmg >= curr_health else curr_health-dmg
		refresh_hpbar()
		
		if sg_passive_ready and curr_health/max_health <= 0.6:
			sg_passive_ready = false
			attack_dmg += sg_bonus_ad
			var old_max_health = max_health
			max_health *= 1+sg_bonus_health
			var health_increase = max_health - old_max_health
			curr_health += health_increase
			
		if bt_passive_ready and curr_health/max_health <= 0.4:
			bt_passive_ready = false
			var timer = Timer.new()
			add_child(timer)
			shield += bt_shield*max_health
			refresh_shieldbar()
			timer.name = "bt_timer"
			timer.wait_time = 5
			timer.one_shot = true
			timer.connect("timeout", _on_bt_passive_end)
			timer.start()
			
		if pv_passive_ready and curr_health/max_health <= 0.4:
			pv_passive_ready = false
			mr += 20*pv_count
			armor += 20*pv_count
			var timer = Timer.new()
			add_child(timer)
			shield += 0.25*pv_count*max_health
			refresh_shieldbar()
			timer.name = "pv_timer"
			timer.wait_time = 5
			timer.one_shot = true
			timer.connect("timeout", _on_pv_passive_end)
			timer.start()
			
		if eon_passive_ready and curr_health/max_health <= 0.6:
			eon_passive_ready = false
			_on_edge_of_night()
		
		if dmg_type == 0 and bramble:
			# Bramble Vest: When struck by any attack, deal 100 magic damage to all adjacent enemies. (once every 2 seconds). 
			if bramble_ready:
				var reflect_dmg = bramble_dmg
				if bb_active: reflect_dmg *= 1+BB_BONUS_DMG
				if redbuff: reflect_dmg *= 1+RB_BONUS_DMG
				
				if not player.get_current_enemy(): # pve round
					for pve_round in player.get_node("PVERounds").get_children():	
						if pve_round.visible:
							for minion in pve_round.get_children():
								if not minion.is_targetable(): continue
								
								if global_transform.origin.distance_to(minion.global_transform.origin) < 2:
									var dmg_popup = preload("res://src/damage_popup.tscn").instantiate()
									dmg_popup.modulate = Color.DODGER_BLUE
									dmg_popup.text = str(int(reflect_dmg))
									add_child(dmg_popup)
									dmg_popup.global_transform.origin = minion.global_transform.origin + Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
					
									minion.take_dmg.rpc_id(minion.get_multiplayer_authority(), reflect_dmg, 1, false, get_path())
				else:		
					var enemy_units = player.get_current_enemy().find_child("Units").get_children()
					
					for unit in enemy_units:	
						if not unit.is_targetable() or unit.dead: continue
					
						if global_transform.origin.distance_to(unit.global_transform.origin) < 2:
							var dmg_popup = preload("res://src/damage_popup.tscn").instantiate()
							dmg_popup.modulate = Color.DODGER_BLUE
							dmg_popup.text = str(int(reflect_dmg))
							add_child(dmg_popup)
							dmg_popup.global_transform.origin = unit.global_transform.origin + Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
							unit.take_dmg.rpc_id(unit.get_multiplayer_authority(), reflect_dmg, 1, false, get_path())
		
				bramble_ready = false
				var bramble_timer = get_node_or_null("bramble_timer")
				if bramble_timer:
					bramble_timer.wait_time = 2
					bramble_timer.start()
	
	if curr_health <= 0 and not dead:
		var attacker = get_node_or_null(source) if source else null
		if attacker: attacker._on_kill.rpc_id(attacker.get_multiplayer_authority(), get_path())
		death.rpc()

@rpc("any_peer", "call_local", "unreliable")
func _on_kill(_target_path):
	var _target = get_node(_target_path)
	#print(name, " killed ", _target.name)
	
	# Blue Buff: When the holder gets a takedown, they deal 7% more damage for 8 seconds.
	bb_active = true
	var timer = get_node_or_null("blue_buff")
	if not timer:
		timer = Timer.new()
		add_child(timer)
		timer.name = "blue_buff"
	timer.wait_time = 8.0
	timer.one_shot = true
	timer.connect("timeout", _on_blue_buff_timeout)
	timer.start()
	
func _on_blue_buff_timeout():
	var timer = get_node_or_null("blue_buff")
	if timer: timer.queue_free()
	bb_active = false

# synced via multiplayersync
func refresh_hpbar():
	ui.get_node("HPBar").value = curr_health/max_health * 100
	
# synced via multiplayersync
func refresh_shieldbar():
	ui.get_node("ShieldBar").value = shield/max_health * 100
	
# synced via multiplayersync
func refresh_manabar():
	ui.get_node("MPBar").value = curr_mana/max_mana * 100
		
@rpc("any_peer", "call_local", "reliable")
func death():
	if dead: return
	
	dead = true
	change_mode(PREP)
	visible = false
	
	if target: target.decrease_targeting_count.rpc_id(target.get_owner_id())
	
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
	var pool_amt = 1
	if star == 2: pool_amt = 3
	elif star == 3: 
		pool_amt = 9
		main.free_from_pool(get_unit_id())
	main.add_to_pool.rpc_id(1, get_unit_id(), pool_amt)
	main.free_object.rpc(get_path())
	
func set_bar_color(color: Color):
	ui.get_node("HPBar").self_modulate = color
	
@rpc("any_peer", "call_local", "reliable")
func equip_item(item_path):	
	var item = get_node(item_path)
	
	if item.is_component():
		if not can_equip_component(): return
	elif not can_equip_item(item): return
	
	for i in range(len(items)):
		if items[i] == null:
			items[i] = item 
			ui.get_node("HBoxContainer/" + str(i)).set_texture(item.get_texture() if item else null) 
			break
		elif item.is_component() and items[i].is_component():
			var curr_item = items[i]
			unequip_item(i)
			item.upgrade(curr_item)
			return
		
	var sprite = get_node("Sprite3D")
	if sprite.position.y == 1: sprite.position.y += 0.5
	
	if is_multiplayer_authority() and item:	
		attackrange += item.get_attack_range()
		max_health += item.get_health()
		attack_dmg += item.get_attack_dmg()
		ability_power += item.get_ability_power()
		armor += item.get_armor()
		mr += item.get_mr()
		change_attack_speed(attack_speed * (1+item.get_attack_speed()))
		crit_chance = min(1, crit_chance + item.get_crit_chance())
		start_mana = min(max_mana, start_mana + item.get_mana())
		if item.get_item_name() == "Blue Buff": max_mana = max(1, max_mana - 10)
		if item.get_ability_crit():
			if ability_crit:
				crit_damage += 0.1
			else: ability_crit = true
		omnivamp += item.get_omnivamp()
		if mode == PREP: 
			curr_mana = start_mana
			refresh_manabar()
			curr_health = max_health
			refresh_hpbar()
		
		item.visible = false
	
func can_equip_item(to_equip = null):
	for item in items:
		if item == null: return true 
		elif to_equip and to_equip.is_unique() and to_equip.get_item_name() == item.get_item_name(): return false 
	
	return false

func can_equip_component():
	for item in items:
		if item == null or item.is_component(): return true 
	
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
		change_attack_speed(attack_speed / (1+item.get_attack_speed()))
		crit_chance = max(0, crit_chance - item.get_crit_chance())
		start_mana = max(0, start_mana - item.get_mana()) # NOTE: this can cause issues if item mana was constrained when equipping (rarely happens as there is no feature yet to unequip items except upgrading and selling)
		if item.get_ability_crit(): # not optimal but w.e
			if crit_damage > 0.3:
				crit_damage -= 0.1
			ability_crit = false
		omnivamp -= item.get_omnivamp()
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
		if item.is_component():
			if to_unit.can_equip_component():
				to_unit.equip_item.rpc(item.get_path())
		elif to_unit.can_equip_item(item):
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
func play_animation(name: StringName = "", force = true, custom_blend: float = -1, custom_speed: float = 1.0, from_end: bool = false):
	if force: anim_player.stop()
	anim_player.play(name, custom_blend, custom_speed, from_end)
	
func ability(_target, pve = false):	
	if _target == null or (not pve and _target.get_mode() != BATTLE) or _target.dead or dead: return
	
	curr_mana = 0
	
	refresh_manabar()

	match attack_anim1:
		0: play_animation.rpc(melee_ability_anim)
		1: play_animation.rpc(ranged_ability_anim)
		2: play_animation.rpc(magic_ability_anim)

	var id = get_multiplayer_authority() if pve else _target.get_owner_id() 
	
	match ability_id:
		0: 
			var damage = ability_power * scaling1 if ability_dmg_type == 1 else attack_dmg * scaling1
			var crit = false
			if ability_crit:
				var rng = randf()
			
				damage = damage if rng > crit_chance else damage * (1+crit_damage)
				if rng <= crit_chance: crit = true
			
			damage *= 1+deathblade_bonus_dmg
			damage *= 1+rabadons_bonus_dmg
			if bb_active: damage *= 1+BB_BONUS_DMG
			if redbuff: damage *= 1+RB_BONUS_DMG
			damage *= (1+(bonus_dmg*2)) if (_target.get_curr_health()/_target.get_max_health() < 0.66) and type == 1 else (1+bonus_dmg)
			if _target.get_max_health() > 1750 and giant_slayer: damage*=1.25
			
			var dmg_popup = preload("res://src/damage_popup.tscn").instantiate()
			dmg_popup.modulate = Color.CRIMSON if ability_dmg_type == 0 else Color.DODGER_BLUE
			if crit: 
				dmg_popup.modulate = Color.BLUE
				dmg_popup.scale *= 1.5
			dmg_popup.text = str(int(damage))
			add_child(dmg_popup)
			dmg_popup.global_transform.origin = _target.global_transform.origin + Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
			
			if morello or redbuff: 
				_target.be_wounded.rpc_id(_target.get_multiplayer_authority())
				burned_enemies[_target] = 4
			_target.take_dmg.rpc_id(id, damage, ability_dmg_type, false, get_path()) # can't dodge attack
			
			# omnivamp - (we just do raw dmg here as actual dmg is computed in take_dmg func)
			if omnivamp > 0:
				var heal = min(damage*omnivamp, max_health-curr_health)
				if wounded: heal -= heal * wound
				curr_health += heal
				if heal > 0:	
					refresh_hpbar()
					
					var heal_popup = preload("res://src/damage_popup.tscn").instantiate()
					heal_popup.modulate = Color.LIME_GREEN
					heal_popup.text = "+" + str(int(heal))
					add_child(heal_popup)
					heal_popup.global_transform.origin += Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
				
				if heal_lowest_ally:
					var lowest_ally = null
					var lowest_percent = 1
					for unit in get_parent().get_children():
						if unit == self: continue
						
						var percent = unit.get_curr_health()/unit.get_max_health()
						if unit.get_mode() == BATTLE and percent < lowest_percent:
							lowest_ally = unit
							lowest_percent = percent
					if lowest_ally:
						var ally_heal = min(damage*0.2, lowest_ally.get_max_health()-lowest_ally.get_curr_health())
						lowest_ally.curr_health += ally_heal #0.2 gunblade heal
						lowest_ally.refresh_hpbar()
					
						var heal_popup = preload("res://src/damage_popup.tscn").instantiate()
						heal_popup.modulate = Color.LIME_GREEN
						heal_popup.text = "+" + str(int(ally_heal))
						lowest_ally.add_child(heal_popup)
						heal_popup.global_transform.origin += Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
		1:
			var timer = get_node_or_null("poison_bomb")
			if not timer:
				timer = Timer.new()
				add_child(timer)
				timer.name = "poison_bomb"
			timer.wait_time = 1.0
			timer.one_shot = false
			timer.connect("timeout", _on_poison_bomb_timeout)
			timer.start()
			poisoned_enemies[_target] = 10
		_: pass
		
	if nashor_as_bonus > 0: apply_nashor()
	
func _on_poison_bomb_timeout():	
	if not poisoned_enemies:
		var timer = get_node_or_null("poison_bomb")
		if timer: timer.queue_free()
	else:
		for _target in poisoned_enemies:
			if _target == null or (not targeting_neutral and _target.get_mode() != BATTLE) or _target.dead or poisoned_enemies[target] <= 0:
				poisoned_enemies.erase(_target)
				continue
				
			poisoned_enemies[_target] -= 1
			
			var id = get_multiplayer_authority() if targeting_neutral else _target.get_owner_id() 
			
			var damage = ability_power * scaling1 if ability_dmg_type == 1 else attack_dmg * scaling1
			damage /= 10 # to equally spread damage
			var crit = false
			if ability_crit:
				var rng = randf()
			
				damage = damage if rng > crit_chance else damage * (1+crit_damage)
				if rng <= crit_chance: crit = true
			
			damage *= 1+deathblade_bonus_dmg
			damage *= 1+rabadons_bonus_dmg
			if bb_active: damage *= 1+BB_BONUS_DMG
			if redbuff: damage *= 1+RB_BONUS_DMG
			damage *= (1+(bonus_dmg*2)) if (_target.get_curr_health()/_target.get_max_health() < 0.66) and type == 1 else (1+bonus_dmg)
			if _target.get_max_health() > 1750 and giant_slayer: damage*=1.25
			
			var dmg_popup = preload("res://src/damage_popup.tscn").instantiate()
			dmg_popup.modulate = Color.CRIMSON if ability_dmg_type == 0 else Color.DODGER_BLUE
			if crit: 
				dmg_popup.modulate = Color.BLUE
				dmg_popup.scale *= 1.5
			dmg_popup.text = str(int(damage))
			add_child(dmg_popup)
			dmg_popup.global_transform.origin = _target.global_transform.origin + Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
			
			_target.take_dmg.rpc_id(id, damage, ability_dmg_type, false, get_path()) # can't dodge attack
			
			# omnivamp - (we just do raw dmg here as actual dmg is computed in take_dmg func)
			if omnivamp > 0:
				var heal = min(damage*omnivamp, max_health-curr_health)
				if wounded: heal -= heal * wound
				curr_health += heal
				if heal > 0:	
					refresh_hpbar()
					
					var heal_popup = preload("res://src/damage_popup.tscn").instantiate()
					heal_popup.modulate = Color.LIME_GREEN
					heal_popup.text = "+" + str(int(heal))
					add_child(heal_popup)
					heal_popup.global_transform.origin += Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)
				
			if heal_lowest_ally:
				var lowest_ally = null
				var lowest_percent = 1
				for unit in get_parent().get_children():
					if unit == self: continue
					
					var percent = unit.get_curr_health()/unit.get_max_health()
					if unit.get_mode() == BATTLE and percent < lowest_percent:
						lowest_ally = unit
						lowest_percent = percent
				if lowest_ally:
					var ally_heal = min(damage*0.2, lowest_ally.get_max_health()-lowest_ally.get_curr_health())
					lowest_ally.curr_health += ally_heal #0.2 gunblade heal
					lowest_ally.refresh_hpbar()
				
					var heal_popup = preload("res://src/damage_popup.tscn").instantiate()
					heal_popup.modulate = Color.LIME_GREEN
					heal_popup.text = "+" + str(int(ally_heal))
					lowest_ally.add_child(heal_popup)
					heal_popup.global_transform.origin += Vector3(randf_range(-.5,.5), randf_range(0,1), 0.5)

func get_unit_id():
	return unit_id
	
@rpc("any_peer", "call_local", "reliable")
func be_wounded(percent = 0.33, duration = 10.0):
	wounded = true
	wound = percent
	var timer = get_node_or_null("wound_timer")
	if not timer: 
		timer = Timer.new()
		add_child(timer)
		timer.name = "wound_timer"
	timer.wait_time = duration
	timer.one_shot = true
	timer.connect("timeout", _on_wounded_end)
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
func increase_targeting_count():
	if not is_multiplayer_authority(): return
	
	targeting_count += 1
	
	armor += gargoyle_count * GARGOYLE_BUFF
	mr += gargoyle_count * GARGOYLE_BUFF
	
@rpc("any_peer", "call_local", "unreliable")
func decrease_targeting_count():
	if not is_multiplayer_authority(): return
	
	if gargoyle_count > 0 and targeting_count > 0: 
		armor -= gargoyle_count * GARGOYLE_BUFF
		mr -= gargoyle_count * GARGOYLE_BUFF
	
	targeting_count = max(0, targeting_count-1)
