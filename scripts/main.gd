extends Node

var local_player
@export var timer: Timer
@export var gui: Control

var players = []

func _input(event):
	for i in range(multiplayer.get_peers().size()):
		if event.is_action_pressed("spectate" + str(i)):
			changeCamera(i)
		elif event.is_action_released("spectate" + str(i)):
			changeCamera(-1)

func setPlayer(_player):
	local_player = _player

func getPlayer():
	return local_player
	
func getTimer():
	return timer
	
func getUI():
	return gui
	
func changeCamera(_index):		
	if _index == -1: 
		local_player.getCamera().current = true
	else:	
		var ids = multiplayer.get_peers()
		if _index >= ids.size(): return
		ids.sort()
		var peername = str(ids[_index])
		var peer = get_tree().root.get_child(0).find_child("World").get_node(peername)
		peer.getCamera().current = true

