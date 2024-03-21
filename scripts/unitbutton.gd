extends Button

var unitGrid

@export_dir var unitFolder: String

var unitFileName: String
var unitArray = []

var unit = null

var preparing = true

var main

func _ready():
	var dir = DirAccess.open(unitFolder)
	unitArray = dir.get_files()
	main = get_tree().root.get_child(0)
	unitGrid = main.getUnitGrid()
	preparing = false
	generateButton()

func _on_pressed():	
	var instance = load(unitFolder + "//" + unitFileName + ".tscn").instantiate()
	var upgradedUnit = upgrade(instance)

	if upgradedUnit:
		disabled = true
		while(upgradedUnit):
			upgradedUnit = upgrade(upgradedUnit)
	else:
		var tile = unitGrid.getFirstFreeTile()
	
		if tile != null:
			instance.tile = tile
			main.playerUnits.append(instance)
			unitGrid.add_child(instance)
			tile.registerUnit(instance)
			disabled = true
		else: 
			instance.queue_free()

func upgrade(_unit):
	if _unit.star >= 3: return null
	
	var sameUnits = []
	# check if there are 2 more units of same name and star
	for u in main.playerUnits:
		if u.unitName == _unit.unitName and u.star == _unit.star and _unit != u:
			sameUnits.append(u)
			if sameUnits.size() >= 2:
				main.playerUnits.erase(_unit) # this has to be done for the recursive upgrade. If _unit not in playerUnits nothing happens
				_unit.queue_free() #unload
				# prioritze units on board, remove in bank
				if sameUnits[0].tile.get_parent().type == sameUnits[0].tile.get_parent().Type.SQUARE:
					sameUnits[0].tile.unregisterUnit()
					main.playerUnits.erase(sameUnits[0])
					sameUnits[0].queue_free()
					sameUnits[1].star += 1
					return sameUnits[1]
				else: 
					sameUnits[1].tile.unregisterUnit()
					main.playerUnits.erase(sameUnits[1])
					sameUnits[1].queue_free()
					sameUnits[0].star += 1
					return sameUnits[0]
	return null

func _on_visibility_changed():
	if visible:
		generateButton()
		
func generateButton():
	if preparing: return
	unitFileName = unitArray[randi() % unitArray.size()].get_slice(".",0)
	icon = load(unitFolder + "//" + unitFileName + ".png")
	disabled = false
