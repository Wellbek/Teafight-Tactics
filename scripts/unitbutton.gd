extends Button

var unitGrid

func _ready():
	unitGrid = get_tree().root.get_child(0).getUnitGrid()

func _on_pressed():
	disabled = true
	
	var tile = unitGrid.getFirstFreeTile()
	
	if tile != null:
		var unit = preload("res://src/units/test_unit.tscn").instantiate()
		unit.tile = tile
		unitGrid.add_child(unit)
		tile.registerUnit(unit)
