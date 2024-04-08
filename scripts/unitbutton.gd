extends Button

@export_dir var unitFolder: String

@onready var button_content = get_node("SubViewport/ButtonContent")
@onready var name_label = button_content.get_node("Name")
@onready var cost_label = button_content.get_node("Cost")
@onready var background = button_content.get_node("BackgroundColor")
@onready var image = button_content.get_node("Image")

var unit_path: String

var unit = null

var preparing = true

var main

var unit_cost
var unit_name

var bought = false

@onready var drop_rates = [
	[1.0, 0.0, 0.0, 0.0, 0.0],  # Level 1
	[1.0, 0.0, 0.0, 0.0, 0.0],  # Level 2
	[0.75, 0.25, 0.0, 0.0, 0.0],  # Level 3
	[0.55, 0.30, 0.15, 0.0, 0.0],  # Level 4
	[0.45, 0.33, 0.20, 0.02, 0.0],  # Level 5
	[0.30, 0.40, 0.25, 0.05, 0.0],  # Level 6
	[0.19, 0.30, 0.40, 0.10, 0.01],  # Level 7
	[0.18, 0.25, 0.32, 0.22, 0.03],  # Level 8
	[0.10, 0.20, 0.25, 0.35, 0.10],  # Level 9
	[0.05, 0.10, 0.20, 0.40, 0.25]  # Level 10
]

func _ready():
	main = get_tree().root.get_child(0)
	preparing = false
	generateButton()
	
func _on_player_gold_changed(new_amount):
	if bought: return
	
	if new_amount < unit_cost:
		disabled = true
	else:
		disabled = false

func _on_pressed():	
	spawnUnit.rpc_id(1, multiplayer.get_unique_id(), main.getPlayer().get_path(), unit_path) # tell server to spawn unit
	# Note the called rpc sends feedback back to the client (see handleSpawn func)
			
@rpc("any_peer", "call_local", "unreliable") # change call_local if server dedicated
func spawnUnit(_feedbackid, _player_path, _unit_path):
	var player = get_tree().root.get_node(_player_path)
	
	var instance = load(_unit_path + ".tscn").instantiate()
	instance.name = str(_feedbackid) + "#" + instance.name

	player.find_child("Units").call("add_child", instance, true)
	
	if _feedbackid != multiplayer.get_unique_id():
		handleSpawn.rpc_id(_feedbackid, instance.get_path())
	else: handleSpawn(instance.get_path())
	
@rpc("authority", "call_local", "unreliable")
func handleSpawn(_unit_path):
	var instance = get_tree().root.get_node(_unit_path)
	
	var player = main.getPlayer()
	
	var instance_cost = instance.get_cost()
	player.decrease_gold(instance_cost)
	change_bought(true)
	
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
	change_bought(false)
	
	var player_level = 1 if main.getPlayer() == null else main.getPlayer().get_level()
	
	var rarity = randf() # number between 0 and 1
	var drop_table = drop_rates[player_level - 1]
	for i in range(len(drop_table)):
		if rarity < drop_table[i]:
			unit_cost = i+1
			break
		rarity -= drop_table[i]
		
	# temporary constraint
	if unit_cost > 2: 
		print(unit_cost)
		unit_cost = 2
	
	var folder = unitFolder + "//" + str(unit_cost)
	var dir = DirAccess.open(folder)
	var unitArray = dir.get_files()
	var unitFileName = unitArray[randi() % unitArray.size()].get_slice(".",0)
	unit_path = folder + "//" + unitFileName
	image.texture = load(unit_path + ".png")
	cost_label.text = str(unit_cost)
	unit_name = unitFileName.replacen("_", " ").to_pascal_case()
	name_label.text = unit_name
	match unit_cost:
		1: background.color = Color(0.275, 0.306, 0.353)
		2: background.color = Color(0.146, 0.481, 0.21)
		3: background.color = Color(0.016, 0.381, 0.4)
		4: background.color = Color(0.667, 0.181, 0.701)
		5: background.color = Color(0.791, 0.469, 0.036)
	disabled = false

func change_bought(val):
	bought = val
	button_content.visible = !val
