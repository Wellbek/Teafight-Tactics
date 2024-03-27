extends Node3D

var main

@export var benchGrid: Node3D
@export var boardGrid: Node3D
@export var camera: Camera3D

@export var multiplayerSpawner: MultiplayerSpawner

var units = []

var myid

func _enter_tree():
	main = get_tree().root.get_child(0)
	myid = name.to_int()
	set_multiplayer_authority(myid)
	#print(str(multiplayer.get_unique_id()) + ": " + str(get_multiplayer_authority()))
	multiplayerSpawner.set_multiplayer_authority(1)
	
func _ready():
	if (is_multiplayer_authority()):
		main.setPlayer(self)
	
		var ids = multiplayer.get_peers()
		ids.append(myid)
		ids.sort()
		var i = ids.find(myid)

		global_transform.origin.x += 19 * i
		camera.current = true

func appendUnit(unit):
	units.append(unit)

func eraseUnit(unit):
	units.erase(unit)

func removeUnit(index):
	units.remove(index)
	
func getUnits():
	return units

func getBenchGrid():
	return benchGrid

func getBoardGrid():
	return boardGrid
	
func getCamera():
	return camera
