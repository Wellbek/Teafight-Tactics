extends StaticBody3D

@export var item_texture: Texture

@export_category("Stats")
@export var attackrange = 0
@export var health = 0
@export var attack_dmg = 0
@export var armor = 0
@export var attack_speed = 0
@export var crit_chance = 0

var dragging = false

var initial_pos: Vector3

var coll

var multisync: MultiplayerSynchronizer

var main
var timer

var equipped = false

func _ready():
	main = get_tree().root.get_child(0)	
	timer = main.get_timer()
	
	set_multiplayer_authority(get_parent().get_parent().get_id())
	
	multisync = find_child("MultiplayerSynchronizer", false)

func _input_event(camera, event, position, normal, shape_idx):
	if not is_multiplayer_authority(): return

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT and !is_dragging():
		set_dragging(true)
		initial_pos = global_transform.origin

		transform.origin.y += 1

func _input(event):
	if not is_multiplayer_authority(): return
	
	if is_dragging():
		if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
			place_item()
		elif event is InputEventMouseMotion:
			var viewport := get_viewport()
			var mouse_position := viewport.get_mouse_position()
			var camera := viewport.get_camera_3d()
			
			var origin := camera.project_ray_origin(mouse_position)
			var direction := camera.project_ray_normal(mouse_position)

			var ray_length := camera.far
			var end := origin + direction * ray_length
			
			var space_state := get_world_3d().direct_space_state
			var query := PhysicsRayQueryParameters3D.create(origin, end, 0b00000000_00000000_00000110_00011111)
			var result := space_state.intersect_ray(query)
			if not result.is_empty() and result.collider != null:
				if (result.collider.get_collision_layer() in [8,24] and result.collider.is_multiplayer_authority()) or result.collider.get_collision_layer() == (512 if main.get_player().defender else 1024):
					if result.collider != coll:
						if coll:
							# reset highlight of last unit
							pass
						# highlight current unit
						coll = result.collider
						# ...
				else: 
					coll = null
					
				var mouse_position_3D:Vector3 = result.get("position", initial_pos if coll == null else coll.global_transform.origin)

				global_transform.origin = Vector3(mouse_position_3D.x, global_transform.origin.y, mouse_position_3D.z)
				
func set_dragging(value):
	dragging = value
	toggle_sync(!value)
	
func is_dragging():
	return dragging
	
func toggle_sync(value):
	if not is_multiplayer_authority(): return
	
	for prop in multisync.replication_config.get_properties():
		#print(prop)
		multisync.replication_config.property_set_watch(prop, value)

func place_item():
	if is_dragging():
		transform.origin.y -= 1
		set_dragging(false)
		
		if coll == null:  
			global_transform.origin = initial_pos
		elif coll.get_collision_layer() in [8, 24]:
			if not coll.can_equip_item():
				coll = null
				global_transform.origin = initial_pos
			else:
				equipped = true
				coll.equip_item.rpc(get_path())
				
func is_equipped():
	return equipped
	
func unequip():
	equipped = false
				
func get_attack_range():
	return attackrange
	
func get_health():
	return health
	
func get_attack_dmg():
	return attack_dmg
	
func get_armor():
	return armor
	
func get_attack_speed():
	return attack_speed	
	
func get_texture():
	return item_texture
	
func get_crit_chance():
	return crit_chance

