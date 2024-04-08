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
var ui: Control

enum {SQUARE, HEX}
enum {PREP, BATTLE}

var mode = PREP

var target = null
var targetable = false 
var attacking = false

var dead = false

@export_category("Stats")
@export var cost = 1
@export var movespeed = 5.0
@export var attackrange = 4.0
@export var max_health = 100.0
var curr_health = max_health
@export var attack_dmg = 20.0
@export var armor = 30.0
@export var attack_speed = 0.8
@export var attack_timer: Timer

func _ready():
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	var viewport = find_child("SubViewport")
	ui = viewport.get_child(0)
	find_child("Sprite3D").texture = viewport.get_texture()
	
func _enter_tree():
	myid = name.get_slice("#", 0).to_int()
	set_multiplayer_authority(myid)
	#print(str(multiplayer.get_unique_id()) + ": " + str(get_multiplayer_authority()))
	
	main = get_tree().root.get_child(0)
	timer = main.get_timer()
	player = main.find_child("World").get_node(str(myid))
	multisync = find_child("MultiplayerSynchronizer", false)
	
func _process(delta):
	if mode == BATTLE and target == null and is_multiplayer_authority():
		find_target()

func _physics_process(delta):	
	if target and not is_instance_valid(target): target = null
		
	if target and mode == BATTLE:
		var distance = global_transform.origin.distance_to(target.global_transform.origin)
		
		if distance > attackrange:
			attacking = false
			velocity = (target.global_transform.origin - global_transform.origin).normalized() * movespeed
			move_and_slide()
			look_at(target.global_transform.origin)
		elif not attacking: in_attack_range()

func setTile(newTile):
	tile = newTile
	change_target_status.rpc(true if tile.get_parent().getType() == HEX else false)
	
@rpc("any_peer", "call_local", "unreliable")
func change_target_status(value):
	targetable = value
	
func is_targetable():
	return targetable
	
func getTile():
	return tile
	
func getTileType():
	return tile.get_parent().getType()

func _input_event(camera, event, position, normal, shape_idx):
	if not is_multiplayer_authority() or not timer.isPreparing() or not mode == PREP: return

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT and !isDragging():
		setDragging(true)
		toggleUI(false)
		toggleGrid(true)
		changeColor(tile.find_children("MeshInstance3D")[0], Color.WHITE)	
		initialPos = global_transform.origin

		transform.origin.y += 1

func _input(event):
	if not is_multiplayer_authority() or not timer.isPreparing() or not mode == PREP: return
	
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
			var query := PhysicsRayQueryParameters3D.create(origin, end, 0b00000000_00000000_00000000_00000111)
			var result := space_state.intersect_ray(query)
			if not result.is_empty() and result.collider != null and result.collider.is_multiplayer_authority(): # can only move and place on own board
				if result.collider.get_collision_layer() == 2 and result.collider != coll:
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
			
func get_mode():
	return mode
			
func find_target():
	if not player.getCurrentEnemy() or mode != BATTLE or not is_multiplayer_authority(): return
	
	var enemy_units = player.getCurrentEnemy().find_child("CombatUnits").get_children()
	
	for unit in enemy_units:	
		if not unit.is_targetable(): continue
		
		#if multiplayer.is_server(): print(unit.name, ": ", global_transform.origin.distance_to(unit.global_transform.origin))
		
		if not target or global_transform.origin.distance_to(unit.global_transform.origin) < global_transform.origin.distance_to(target.global_transform.origin):
			target = unit
			
	#if multiplayer.is_server():
	#	if target != null: print(self, " targets ", target)

func changeColor(mesh, color):
	var newMaterial = StandardMaterial3D.new()
	newMaterial.albedo_color = color
	mesh.set_surface_override_material(0, newMaterial)

func placeUnit():
	if not isDragging(): return
	
	transform.origin.y -= 1
	setDragging(false)

	toggleGrid(false)
	
	if coll == null: coll = tile # if mouse never passes over a collider coll will be null => precaution against this error
	
	changeColor(coll.find_children("MeshInstance3D")[0], Color.CYAN)
	
	if tile == coll: 
		global_transform.origin = Vector3(tile.global_transform.origin.x, global_transform.origin.y, tile.global_transform.origin.z)
		if tile.get_parent().type == tile.get_parent().HEX: 
			toggleUI(true)
	elif tile != null: 
		if coll.hasUnit(): 
			tile.swapUnit(coll)
		else:
			tile.unregisterUnit()
			tile = coll
			tile.registerUnit(self)

func levelUp():
	if star < 3:
		star += 1
		ui.find_child("Star").text = str(star)
		scale += Vector3(.1,.1,.1)
		cost *= 3
		
func toggleUI(value):
	ui.visible = value
	
func toggleGrid(value):
	player.getBoardGrid().visible = value
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
	auto_attack(target)

func auto_attack(_target):
	if _target == null or _target.get_mode() != BATTLE: return
	
	_target.take_dmg.rpc_id(_target.get_owner_id(), attack_dmg)

@rpc("any_peer", "call_local", "unreliable")
func take_dmg(raw_dmg):
	if mode != BATTLE: return
	
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
				if u.get_mode() == BATTLE: fighter_count += 1
			
			if fighter_count <= 1:
				main.unregister_battle()
				var player = parent.get_parent()
				# TODO: do dmg computation here https://lolchess.gg/guide/damage?hl=en
				player.lose_health.rpc(35) # NOTE: TEMPORARY
				check_battle_status()
		instance.queue_free()
		
# server func
func check_battle_status():	
	if not multiplayer.is_server(): return
	
	#print(main.get_num_of_battles() )
	
	if main.get_num_of_battles() <= 0 and not main.get_timer().isPreparing():
		# all battles have finished => go right into prep phase
		main.get_timer().change_phase()
		
func get_cost():
	return cost
	
func sell_unit():
	player.increase_gold(get_cost())
	setDragging(false)
	toggleGrid(false)
	if coll == null: coll = tile # if mouse never passes over a collider coll will be null => precaution against this error
	changeColor(coll.find_children("MeshInstance3D")[0], Color.CYAN)
	player.eraseUnit(self)
	main.freeObject.rpc(get_path())
