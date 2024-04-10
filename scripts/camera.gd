extends Camera3D

@export_category("Camera Zoom")
@export var current_fov: float = 75.0
@export var min_fov: float = 40.0
@export var max_fov: float = 75.0
@export var zoom_step: float = 3.0

@export_category("Camera Movement")
@export var cam_speed: float = 10.0
@export var max_movement: Vector2 = Vector2(.5,3)
@onready var default_pos = global_transform.origin

var move_vec = Vector2(0,0)
var moving = false

func _input(event):
	if event.is_action_released("MWU"):
		current_fov -= zoom_step 
		current_fov = clamp(current_fov, min_fov, max_fov)
		set_fov(current_fov)
	elif event.is_action_released("MWD"):
		current_fov += zoom_step
		current_fov = clamp(current_fov, min_fov, max_fov)
		set_fov(current_fov)
	elif event is InputEventMouseMotion:
		var screen_size = Vector2(get_viewport().size)
		var pos_ratio = (screen_size - event.position)/screen_size
		move_vec = Vector2(0,0)
		if pos_ratio.x > .9 and pos_ratio.x < 1:
			move_vec.x = -1
		elif pos_ratio.x < .1 and pos_ratio.x > 0:
			move_vec.x = 1
		if pos_ratio.y > .9 and pos_ratio.y < 1:
			move_vec.y = -1
		elif pos_ratio.y < .1 and pos_ratio.y > 0:
			move_vec.y = 1
		
		moving = true if move_vec != Vector2.ZERO else false
			
func _process(delta):
	if moving: move_camera(move_vec)
		
func change_current(val):
	current = val
	current_fov = max_fov
	set_fov(current_fov)
	global_transform.origin = default_pos
	
func move_camera(direction):
	global_transform.origin.x += direction.x/100 * cam_speed
	global_transform.origin.x = clamp(global_transform.origin.x, default_pos.x - max_movement.x, default_pos.x + max_movement.x)
	
	global_transform.origin.z += direction.y/100 * cam_speed
	global_transform.origin.z = clamp(global_transform.origin.z, default_pos.z - max_movement.y, default_pos.z)
