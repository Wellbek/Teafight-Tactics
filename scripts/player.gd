extends Node3D

var main

@export var unitGrid: Node3D
@export var camera: Camera3D

var units = []

var myid

func _enter_tree():
	main = get_tree().root.get_child(0)
	main.setPlayer(self)
	
func _ready():
	print(name)
	myid = name.to_int()
	set_multiplayer_authority(myid)
	
	var ids = multiplayer.get_peers()
	ids.append(myid)
	ids.sort()
	var i = ids.find(myid)
	
	if is_multiplayer_authority():
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

func getUnitGrid():
	return unitGrid
