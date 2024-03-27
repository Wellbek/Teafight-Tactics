extends Node

var player
@export var timer: Timer
@export var gui: Control

func _input(event):
	
	for i in range(multiplayer.get_peers().size()):
		if event.is_action_pressed("spectate" + str(i)):
			changeCamera(i)
		elif event.is_action_released("spectate" + str(i)):
			changeCamera(-1)
		
	#if str("spectate").is_subsequence_of(event.as_text()):
		#if event.is_action_pressed(event.as_text()):
			#var id = event.as_text().trim_prefix("spectate")
			#changeCamera(id+1)
		#elif event.is_action_released(event.as_text()):
			#changeCamera(0)

func setPlayer(_player):
	player = _player

func getPlayer():
	return player
	
func getTimer():
	return timer
	
func getUI():
	return gui
	
func changeCamera(_index):		
	if _index == -1: 
		player.getCamera().current = true
	else:	
		var ids = multiplayer.get_peers()
		if _index >= ids.size(): return
		ids.sort()
		var peername = str(ids[_index])
		var peer = get_tree().root.get_child(0).find_child("World").get_node(peername)
		peer.getCamera().current = true

