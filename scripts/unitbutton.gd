extends Button

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
	preparing = false
	generateButton()

func _on_pressed():	
	spawnUnit.rpc_id(1, multiplayer.get_unique_id(), main.getPlayer().get_path(), unitFileName) # tell server to spawn unit
	# Note the called rpc sends feedback back to the client (see handleSpawn func)
			
@rpc("any_peer", "call_local", "unreliable") # change call_local if server dedicated
func spawnUnit(_feedbackid, _player_path, _unit_file_name):
	var player = get_tree().root.get_node(_player_path)
	
	var instance = load(unitFolder + "//" + _unit_file_name + ".tscn").instantiate()
	instance.name = str(_feedbackid) + "#" + instance.name

	player.find_child("Units").call("add_child", instance, true)
	
	if _feedbackid != multiplayer.get_unique_id():
		handleSpawn.rpc_id(_feedbackid, instance.get_path())
	else: handleSpawn(instance.get_path())
	
@rpc("authority", "call_local", "unreliable")
func handleSpawn(_unit_path):
	var instance = get_tree().root.get_node(_unit_path)
	
	var player = main.getPlayer()
	
	var unit_cost = instance.get_cost()
	player.decrease_gold(unit_cost)
	
	var upgradedUnit = upgrade(instance)

	if upgradedUnit:
		disabled = true
		while(upgradedUnit):
			upgradedUnit = upgrade(upgradedUnit)
	else:
		var tile = player.getBenchGrid().getFirstFreeTile()
	
		if tile != null:
			instance.tile = tile
			player.appendUnit(instance)
			tile.registerUnit(instance)
			disabled = true
		else: 
			main.freeObject.rpc(instance.get_path())

func upgrade(_unit):
	if _unit.star >= 3: return null
	
	var sameUnits = []
	# check if there are 2 more units of same name and star
	for u in main.getPlayer().getUnits():
		if u.unitName == _unit.unitName and u.star == _unit.star and _unit != u:
			sameUnits.append(u)
			if sameUnits.size() >= 2:
				main.getPlayer().eraseUnit(_unit) # this has to be done for the recursive upgrade. If _unit not in playerUnits nothing happens
				main.freeObject.rpc(_unit.get_path()) #unload
				# prioritze units on board, remove in bank
				if sameUnits[0].tile.get_parent().type == sameUnits[0].tile.get_parent().SQUARE:
					sameUnits[0].tile.unregisterUnit()
					main.getPlayer().eraseUnit(sameUnits[0])
					main.freeObject.rpc(sameUnits[0].get_path())
					sameUnits[1].levelUp()
					return sameUnits[1]
				else: 
					sameUnits[1].tile.unregisterUnit()
					main.getPlayer().eraseUnit(sameUnits[1])
					main.freeObject.rpc(sameUnits[1].get_path())
					sameUnits[0].levelUp()
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
