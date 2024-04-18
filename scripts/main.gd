extends Node

var local_player
@export var timer: Timer
@export var gui: Control

var players = []
var num_of_battles = 0 # server var

var unit_sellable = false

const DROP_RATES = [
	[1.0, 0.0, 0.0, 0.0, 0.0],  # Level 1
	[1.0, 0.0, 0.0, 0.0, 0.0],  # Level 2
	[0.75, 0.25, 0.0, 0.0, 0.0],  # Level 3
	[0.55, 0.30, 0.15, 0.0, 0.0],  # Level 4
	[0.45, 0.33, 0.20, 0.02, 0.0],  # Level 5
	[0.30, 0.40, 0.25, 0.05, 0.0],  # Level 6
	[0.19, 0.30, 0.40, 0.10, 0.01],  # Level 7
	[0.18, 0.25, 0.32, 0.22, 0.03],  # Level 8
	[0.10, 0.20, 0.25, 0.35, 0.10],  # Level 9
	[0.05, 0.10, 0.20, 0.40, 0.25]  # Level 10
]

func _input(event):
	for i in range(len(multiplayer.get_peers())+1):
		if event.is_action_pressed("spectate" + str(i)):
			change_camera(i)

func set_player(_player):
	local_player = _player

func get_player():
	return local_player
	
func get_timer():
	return timer
	
func get_ui():
	return gui

# server func
func register_battle():
	num_of_battles += 1

# server func	
func unregister_battle():
	num_of_battles = max(0, num_of_battles-1)
	
# server func
func get_num_of_battles():
	return num_of_battles
	
func change_camera(_index):
	if not local_player: return
			
	if _index == 0: 
		local_player.get_camera().change_current(true)
	else:	
		var ids = multiplayer.get_peers()
		if _index-1 >= ids.size(): return
		ids.sort()
		var peername = str(ids[_index-1])
		var peer = get_tree().root.get_child(0).find_child("World").get_node(peername)
		peer.get_enemy_cam().change_current(true)
		
func change_camera_by_id(_id):		
	if not local_player: return
	
	if _id == multiplayer.get_unique_id(): 
		local_player.get_camera().change_current(true)
	else:	
		var peer = get_tree().root.get_child(0).find_child("World").get_node(str(_id))
		if peer:
			peer.get_enemy_cam().change_current(true)
			
@rpc("any_peer", "call_local", "reliable")
func free_object(_path):
	var instance = get_tree().root.get_node(_path)
	if instance != null and is_instance_valid(instance):
		instance.queue_free()

func _on_sell_unit_mouse_entered():
	unit_sellable = true
	
func _on_sell_unit_mouse_exited():
	unit_sellable = false
	
func is_unit_sellable():
	return unit_sellable
