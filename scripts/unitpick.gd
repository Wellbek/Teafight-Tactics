extends CollisionObject3D

var dragging: bool = false
var initialPos: Vector3

var coll
var tile

var main
var player
var timer: Timer

var myid

@export_file("*.png", "*.jpg") var image
@export var unitName: String
@export_enum("NONE","1", "2", "3") var star: int = 1
@export var ui: Control

func _enter_tree():
	myid = name.get_slice("#", 0).to_int()
	set_multiplayer_authority(myid)
	#print(str(multiplayer.get_unique_id()) + ": " + str(get_multiplayer_authority()))
	
	main = get_tree().root.get_child(0)
	timer = main.getTimer()
	player = main.getPlayer()

func setTile(newTile):
	tile = newTile

func _input_event(camera, event, position, normal, shape_idx):
	if not is_multiplayer_authority(): return
	
	if not timer.isPreparing(): return
	
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT and !dragging:
		dragging = true
		toggleUI(false)
		toggleGrid(true)
		changeColor(tile.find_children("MeshInstance3D")[0], Color.WHITE)	
		initialPos = global_transform.origin

		transform.origin.y += 1

func _input(event):
	if not is_multiplayer_authority(): return
	
	if not timer.isPreparing(): return
	
	if dragging:
		if event is InputEventMouseButton and event.is_released() and event.button_index == MOUSE_BUTTON_LEFT:
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

func changeColor(mesh, color):
	var newMaterial = StandardMaterial3D.new()
	newMaterial.albedo_color = color
	mesh.set_surface_override_material(0, newMaterial)

func placeUnit():
	if not dragging: return
	
	dragging = false
	transform.origin.y -= 1
	toggleGrid(false)
	changeColor(coll.find_children("MeshInstance3D")[0], Color.CYAN)
	
	if tile == coll: 
		global_transform.origin = Vector3(tile.global_transform.origin.x, global_transform.origin.y, tile.global_transform.origin.z)
		if tile.get_parent().type == tile.get_parent().Type.HEX: 
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
		
func toggleUI(value):
	ui.visible = value
	
func toggleGrid(value):
	player.getBoardGrid().visible = value
	player.getBenchGrid().visible = value

'
extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()'
