extends Node3D

var unit = null

func registerUnit(newUnit):
	if newUnit == null:
		printerr("newUnit is null")
		unregisterUnit()
		return
	
	unregisterUnit()
	unit = newUnit
	unit.setTile(self)
	unit.toggleUI(get_parent().type == get_parent().HEX)
	unit.global_transform.origin = Vector3(global_transform.origin.x, unit.global_transform.origin.y, global_transform.origin.z)
	
	get_parent().increase_number_of_units()

func unregisterUnit():
	if unit == null: return
	
	unit = null
	get_parent().decrease_number_of_units()
	
func swapUnit(oldTile):
	if get_script() != oldTile.get_script(): 
		printerr("oldTile parameter of function swapUnit(newUnit, oldTile) is not of valid type")
		return 
	var oldUnit = unit
	registerUnit(oldTile.getUnit())
	oldTile.registerUnit(oldUnit)
	
func hasUnit():
	return unit != null

func getUnit():
	return unit
