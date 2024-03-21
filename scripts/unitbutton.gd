extends Button

var unitGrid

@export_dir var unitFolder: String

var unitFileName: String
var unitArray = []

var unit = null

var preparing = true

func _ready():
	var dir = DirAccess.open(unitFolder)
	unitArray = dir.get_files()
	unitGrid = get_tree().root.get_child(0).getUnitGrid()
	preparing = false
	generateButton()

func _on_pressed():
	disabled = true
	
	var tile = unitGrid.getFirstFreeTile()
	
	if tile != null:
		var instance = load(unitFolder + "//" + unitFileName + ".tscn").instantiate()
		instance.tile = tile
		get_tree().root.get_child(0).playerUnits.append(instance)
		unitGrid.add_child(instance)
		tile.registerUnit(instance)


func _on_visibility_changed():
	if visible:
		generateButton()
		
func generateButton():
	if preparing: return
	unitFileName = unitArray[randi() % unitArray.size()].get_slice(".",0)
	icon = load(unitFolder + "//" + unitFileName + ".png")
	disabled = false
