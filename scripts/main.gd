extends Node

var local_player
@export var timer: Timer
@export var gui: Control

var players = []
var num_of_battles = 0 # server var

func _input(event):
	for i in range(len(multiplayer.get_peers())+1):
		if event.is_action_pressed("spectate" + str(i)):
			changeCamera(i)

func setPlayer(_player):
	local_player = _player

func getPlayer():
	return local_player
	
func get_timer():
	return timer
	
func getUI():
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
	
func changeCamera(_index):		
	if _index == 0: 
		local_player.getCamera().current = true
	else:	
		var ids = multiplayer.get_peers()
		if _index-1 >= ids.size(): return
		ids.sort()
		var peername = str(ids[_index-1])
		var peer = get_tree().root.get_child(0).find_child("World").get_node(peername)
		peer.getEnemyCam().current = true
		
func changeCameraByID(_id):		
	if _id == multiplayer.get_unique_id(): 
		local_player.getCamera().current = true
	else:	
		var peer = get_tree().root.get_child(0).find_child("World").get_node(str(_id))
		if peer:
			peer.getEnemyCam().current = true
			
@rpc("any_peer", "call_local", "unreliable")
func freeObject(_path):
	var instance = get_tree().root.get_node(_path)
	if instance != null and is_instance_valid(instance):
		instance.queue_free()
