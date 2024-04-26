extends Node

var local_player
@export var timer: Timer
@export var gui: Control
@export var classes: Control

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

var unit_pool = {
	0: 44,
	1: 44,
	2: 44,
	3: 44,
	4: 44,
	5: 44,
	6: 44,
	7: 40,
	8: 40,
	9: 40,
	10: 40,
	11: 40,
	12: 40,
	13: 40,
	14: 34,
	15: 34,
	16: 34,
	17: 34,
	18: 34,
	19: 34,
	20: 20,
	21: 20,
	22: 20,
	23: 20,
	24: 20,
	25: 20,
	26: 18,
	27: 18,
	28: 18,
	29: 18
}

# inclusive, exclusive
const COST_RANGES = {
	1: Vector2(0,7),
	2: Vector2(7, 14),
	3: Vector2(14, 20),
	4: Vector2(20, 26),
	5: Vector2(26, 30)
}

var excluded_from_pool = { }

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
		for bar in get_ui().get_node("PlayerBars/VBoxContainer").get_children():
			bar.hp_bar.set_tint_under(Color(0.169, 0.169, 0.169))
		local_player.get_camera().change_current(true)
	else:	
		var ids = multiplayer.get_peers()
		if _index-1 >= ids.size(): return
		ids.sort()
		var peername = str(ids[_index-1])
		var peer = get_tree().root.get_child(0).find_child("World").get_node(peername)
		peer.get_enemy_cam().change_current(true)
	
		# reset highlight		
		for bar in get_ui().get_node("PlayerBars/VBoxContainer").get_children():
			if bar == get_ui().get_node("PlayerBars/VBoxContainer").get_node(str(ids[_index-1])):
				bar.hp_bar.set_tint_under(Color.YELLOW)
			else:
				bar.hp_bar.set_tint_under(Color(0.169, 0.169, 0.169))
	
func change_camera_by_id(_id):		
	if not local_player: return
	
	if _id == multiplayer.get_unique_id(): 
		local_player.get_camera().change_current(true)
	else:	
		var peer = get_tree().root.get_child(0).find_child("World").get_node(str(_id))
		if peer:
			peer.get_enemy_cam().change_current(true)
	
	# reset highlight		
	for bar in get_ui().get_node("PlayerBars/VBoxContainer").get_children():
		bar.hp_bar.set_tint_under(Color(0.169, 0.169, 0.169))
	
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
	
func get_classes():
	return classes
	
@rpc("any_peer", "call_local", "reliable")
func remove_from_pool(_id, _amount = 1):
	if _id >= len(unit_pool): return
	if unit_pool[_id] - _amount < 0: 
		unit_pool[_id] = 0
		printerr("ERROR: cant remove more units from pool than available")
	unit_pool[_id] -= _amount
	
@rpc("any_peer", "call_local", "reliable")
func add_to_pool(_id, _amount = 1):
	if _id >= len(unit_pool)-1: return
	unit_pool[_id] += _amount
	
func is_in_pool(_id):
	if _id >= len(unit_pool)-1: return false
	return unit_pool[_id] > 0
	
func get_pool_amount(_id):
	if _id >= len(unit_pool)-1: return -1
	return unit_pool[_id]
	
func get_unit_pool():
	return unit_pool
	
func exclude_from_pool(_id):
	excluded_from_pool[_id] = null
	
func free_from_pool(_id):
	excluded_from_pool.erase(_id)
	
func is_excluded_from_pool(_id):
	return _id in excluded_from_pool
