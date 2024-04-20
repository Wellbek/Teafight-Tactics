extends Node3D

var unit = null
@onready var main = get_tree().root.get_child(0)

func register_unit(new_unit):
	if new_unit == null:
		printerr("ERROR: parameter new_unit is null")
		unregister_unit()
		return
	
	unregister_unit()
	unit = new_unit
	unit.set_tile(self)
	unit.global_transform.origin = Vector3(global_transform.origin.x, unit.global_transform.origin.y, global_transform.origin.z)
	
	get_parent().increase_number_of_units()
	
	if get_parent().type == 1:
		var player = main.get_player()
		if unit.get_unit_name() not in player.combat_unit_set:
			player.combat_unit_set[unit.get_unit_name()] = 0
			main.get_classes().increase_count(unit.get_class_name())
		player.combat_unit_set[unit.get_unit_name()] += 1

func unregister_unit():
	if unit == null: return
	
	get_parent().decrease_number_of_units()
	
	if get_parent().type == 1:
		var player = main.get_player()
		if unit.get_unit_name() in player.combat_unit_set:
			player.combat_unit_set[unit.get_unit_name()] -= 1
			if player.combat_unit_set[unit.get_unit_name()] <= 0:
				main.get_classes().decrease_count(unit.get_class_name())
				player.combat_unit_set.erase(unit.get_unit_name())
		
	unit = null
	
func swap_unit(old_tile):
	if get_script() != old_tile.get_script(): 
		printerr("oldTile parameter of function swap_unit(newUnit, oldTile) is not of valid type")
		return 
	var old_unit = unit
	register_unit(old_tile.get_unit())
	old_tile.register_unit(old_unit)
	
func has_unit():
	return unit != null

func get_unit():
	return unit
