extends StaticBody3D

@export_category("Stats")
@export var attackrange = 0
@export var max_health = 0
@export var attack_dmg = 0
@export var armor = 0
@export var attack_speed = 0

var dragging = false

var initialPos: Vector3

var coll

var multisync: MultiplayerSynchronizer

func _ready():
	multisync = find_child("MultiplayerSynchronizer", false)

func _input_event(camera, event, position, normal, shape_idx):
	#if not is_multiplayer_authority(): return

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT and !isDragging():
		setDragging(true)
		initialPos = global_transform.origin

		transform.origin.y += 1

func _input(event):
	#if not is_multiplayer_authority(): return
	
	if isDragging():
		if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
			placeItem()
		elif event is InputEventMouseMotion:
			var viewport := get_viewport()
			var mouse_position := viewport.get_mouse_position()
			var camera := viewport.get_camera_3d()
			
			var origin := camera.project_ray_origin(mouse_position)
			var direction := camera.project_ray_normal(mouse_position)

			var ray_length := camera.far
			var end := origin + direction * ray_length
			
			var space_state := get_world_3d().direct_space_state
			var query := PhysicsRayQueryParameters3D.create(origin, end, 0b00000000_00000000_00000001_00000111)
			var result := space_state.intersect_ray(query)
			if not result.is_empty() and result.collider != null and result.collider.is_multiplayer_authority(): # can only move and place on own board
				if result.collider.get_collision_layer() == 2 and result.collider != coll:
					if coll:
						# reset highlight of last unit
						pass
					# highlight current unit
					coll = result.collider
					# ...

				var mouse_position_3D:Vector3 = result.get("position", initialPos if coll == null else coll.global_transform.origin)

				global_transform.origin = Vector3(mouse_position_3D.x, global_transform.origin.y, mouse_position_3D.z)
				
func setDragging(value):
	dragging = value
	toggleSync(!value)
	
func isDragging():
	return dragging
	
func toggleSync(value):
	if not is_multiplayer_authority(): return
	
	for prop in multisync.replication_config.get_properties():
		#print(prop)
		multisync.replication_config.property_set_watch(prop, value)

func placeItem():
	if isDragging():
		transform.origin.y -= 1
		setDragging(false)
