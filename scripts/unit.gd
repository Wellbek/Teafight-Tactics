extends CharacterBody3D

var dragging: bool = false
@onready var sell_unit_gui = main.getUI().get_node("UnitShop/SellUnit")
var initialPos: Vector3

var coll
var tile

var main
var player
var timer: Timer

var myid

var multisync

@export_file("*.png", "*.jpg") var image
@export var unitName: String
@export_enum("NONE","1", "2", "3") var star: int = 1
@export_enum("Herbal Heroes", "Green Guardians", "Black Brigade", "Floral Fighters", "Exotic Enchanters", "Fruitful Forces", "Aromatic Avatars") var type: int = 0
var ui: Control

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
@export var move_speed = 5.0
@export var attackrange = 4.0
@export var max_health = 100.0
@onready var curr_health = max_health
@export var attack_dmg = 20.0
@export var armor = 30.0
@export var attack_speed = 0.8
@export var crit_change = 0.25
@export var attack_timer: Timer

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
	
func _enter_tree():
	myid = name.get_slice("#", 0).to_int()
	set_multiplayer_authority(myid)
	#print(str(multiplayer.get_unique_id()) + ": " + str(get_multiplayer_authority()))
	
	main = get_tree().root.get_child(0)
	timer = main.get_timer()
	player = main.find_child("World").get_node(str(myid))
	multisync = find_child("MultiplayerSynchronizer", false)
	
func _process(_delta):
	if mode == BATTLE and target == null and is_multiplayer_authority() and not main.get_timer().is_transitioning():
		find_target()

func _physics_process(_delta):	
	if target and (not is_instance_valid(target) or target.dead): 
		target = null
		
	if target and mode == BATTLE:
		var distance = global_transform.origin.distance_to(target.global_transform.origin)

		if distance > attackrange:
			attacking = false
			velocity = (target.global_transform.origin - global_transform.origin).normalized() * move_speed
			move_and_slide()
		elif not attacking: in_attack_range()
		
		look_at(target.global_transform.origin)
		rotation.x = 0
		rotation.z = 0

func setTile(newTile):
	tile = newTile
	change_target_status.rpc(true if tile.get_parent().getType() == HEX else false)
	
@rpc("any_peer", "call_local", "reliable")
func change_target_status(value):
	targetable = value
	
func is_targetable():
	return targetable
	
func getTile():
	return tile
	
func getTileType():
	return tile.get_parent().getType()

func _input_event(_camera, event, _position, _normal, _shape_idx):
	if not is_multiplayer_authority() or not mode == PREP: return

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT and !isDragging():
		setDragging(true)
		toggleGrid(true)
		changeColor(tile.find_children("MeshInstance3D")[0], Color.WHITE)	
		initialPos = global_transform.origin

		transform.origin.y += 1

func _input(event):
	if not is_multiplayer_authority() or not mode == PREP: return
	
	if isDragging():
		if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
			if main.is_unit_sellable():
				sell_unit()
			else:
				placeUnit()
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
				if result.collider.get_collision_layer() == 2 and result.collider != coll and result.collider.is_multiplayer_authority():
					if coll:
						# reset highlight of last tile
						changeColor(coll.find_children("MeshInstance3D")[0], Color.CYAN)
					# highlight current tile
					coll = result.collider
					changeColor(coll.find_children("MeshInstance3D")[0], Color.WHITE)

				var mouse_position_3D:Vector3 = result.get("position", initialPos if coll == null else coll.global_transform.origin)

				global_transform.origin = Vector3(mouse_position_3D.x, global_transform.origin.y, mouse_position_3D.z)

func change_mode(_mode: int):	
	mode = _mode
	
	if mode == BATTLE:
		set_collision_layer_value(5, true) # only collide with battling units (hidden prep units should be ignored)
	else:
		set_collision_layer_value(5, false)
			
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

func changeColor(mesh, color):
	var newMaterial = StandardMaterial3D.new()
	newMaterial.albedo_color = color
	mesh.set_surface_override_material(0, newMaterial)

func placeUnit(_tile: Node = coll):
	if isDragging():
		transform.origin.y -= 1
		setDragging(false)
	elif _tile == coll: return

	toggleGrid(false)
	
	if _tile == null: _tile = tile # if mouse never passes over a collider coll will be null => precaution against this error
	
	changeColor(_tile.find_children("MeshInstance3D")[0], Color.CYAN)
	
	if tile == _tile: 
		global_transform.origin = Vector3(tile.global_transform.origin.x, global_transform.origin.y, tile.global_transform.origin.z)
	elif tile != null: 
		if _tile.hasUnit(): 
			tile.swapUnit(_tile)
		else:
			if _tile.get_parent().can_place_unit() or getTileType() == 1:
				tile.unregisterUnit()
				tile = _tile
				tile.registerUnit(self)
			else: 
				global_transform.origin = Vector3(tile.global_transform.origin.x, global_transform.origin.y, tile.global_transform.origin.z)

func levelUp():
	if star < 3:
		star += 1
		ui.find_child("Star").text = str(star)
		scale += Vector3(.1,.1,.1)
		cost *= 3
		# stats: https://tftactics.gg/db/champion-stats/
		attack_dmg *= 1.8
		max_health *= 1.8
		curr_health = max_health
		
func toggleUI(value):
	ui.visible = value
	
func get_ui():
	return ui
	
func toggleGrid(value):
	player.getBoardGrid().visible = value and timer.is_preparing()
	player.getBenchGrid().visible = value

func setDragging(value):
	dragging = value
	sell_unit_gui.visible = dragging
	sell_unit_gui.get_node("CostLabel").text = "Sell for " + str(cost) + "g"
	toggleSync(!value)
	
func isDragging():
	return dragging
	
func get_owner_id():
	return player.getID()

func toggleSync(value):
	if not is_multiplayer_authority(): return
	
	for prop in multisync.replication_config.get_properties():
		#print(prop)
		multisync.replication_config.property_set_watch(prop, value)

func in_attack_range():
	attacking = true
	attack_timer.wait_time = 1/attack_speed
	attack_timer.start()
	
func _on_attack_timer_timeout():
	if main.get_timer().is_transitioning(): get_node("AttackTimer").stop()
	else: auto_attack(target, targeting_neutral)

func auto_attack(_target, pve = false):
	if _target == null or (not pve and _target.get_mode() != BATTLE): return

	var id = get_multiplayer_authority() if pve else _target.get_owner_id() 

	_target.take_dmg.rpc_id(id, attack_dmg)

func change_attack_speed(val):
	attack_speed = val
	attack_timer.wait_time = 1/attack_speed
	if attacking == true: attack_timer.start()

@rpc("any_peer", "call_local", "unreliable")
func take_dmg(raw_dmg):
	if mode != BATTLE: return
	
	var dmg = raw_dmg / (1+armor/100) # https://leagueoflegends.fandom.com/wiki/Armor
	
	curr_health = 0 if dmg >= curr_health else curr_health-dmg
	
	refresh_hpbar()
	
	if curr_health <= 0 and not dead:
		death.rpc()
		
# synced via multiplayersync
func refresh_hpbar():
	ui.get_node("HPBar").value = curr_health/max_health * 100
		
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
			
			player.increment_lossstreak.rpc_id(player.getID())
			
			if enemy: enemy.increment_winstreak.rpc_id(enemy.getID())

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
	setDragging(false)
	toggleGrid(false)
	tile.unregisterUnit()
	if coll == null: coll = tile # if mouse never passes over a collider coll will be null => precaution against this error
	changeColor(coll.find_children("MeshInstance3D")[0], Color.CYAN)
	player.eraseUnit(self)
	unequip_items()
	main.freeObject.rpc(get_path())
	
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
		armor += item.get_armor()
		attack_speed *= 1+item.get_attack_speed()/100
		
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
		armor -= item.get_armor()
		attack_speed /= 1-item.get_attack_speed()/100
	
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
	else: toggleUI(false)
