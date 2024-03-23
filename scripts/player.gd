extends Node3D

var main

@export var unitGrid: Node3D

var units = []

func _enter_tree():
	main = get_tree().root.get_child(0)
	set_multiplayer_authority(multiplayer.get_unique_id())
	print(is_multiplayer_authority())
	main.setPlayer(self)

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
