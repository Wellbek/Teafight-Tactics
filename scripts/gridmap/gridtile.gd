extends Node3D

var unit = null

func registerUnit(newUnit):
	if newUnit == null:
		printerr("newUnit is null")
		unregisterUnit()
		return
	
	unregisterUnit()
	unit = newUnit
	unit.global_transform.origin = Vector3(global_transform.origin.x, unit.global_transform.origin.y, global_transform.origin.z)

func unregisterUnit():
	unit = null
	
func swapUnit(oldTile):
	if get_script() != oldTile.get_script(): 
		printerr("oldTile parameter of function swapUnit(newUnit, oldTile) is not of valid type")
		return 
	var oldUnit = unit
	registerUnit(oldTile.getUnit())
	oldTile.registerUnit(oldUnit)
	
	unit.setTile(self)
	oldUnit.setTile(oldTile)
	
func hasUnit():
	return unit != null

func getUnit():
	return unit
