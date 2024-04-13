extends TextureButton

@export_dir var unitFolder: String

@onready var button_content = get_node("SubViewport/ButtonContent")
@onready var name_label = button_content.get_node("Name")
@onready var cost_label = button_content.get_node("Cost")
@onready var background = button_content.get_node("BackgroundColor")
@onready var image = button_content.get_node("Image")

var unit_path: String

var unit = null

var main

var unit_cost
var unit_name

var bought = false

func _ready():
	main = get_tree().root.get_child(0)
	generateButton()
	
func _on_player_gold_changed(new_amount):
	if bought: return
	
	if new_amount < unit_cost:
		disabled = true
		self_modulate = Color(0.251, 0.251, 0.251, 0.89)
	else:
		self_modulate = Color(1, 1, 1, 1)
		disabled = false

func _on_pressed():		
	if bought: return
	
	change_bought(true)
	spawnUnit.rpc_id(1, multiplayer.get_unique_id(), main.getPlayer().get_path(), unit_path) # tell server to spawn unit
	# Note the called rpc sends feedback back to the client (see handleSpawn func)
			
@rpc("any_peer", "call_local", "reliable") # change call_local if server dedicated
func spawnUnit(_feedbackid, _player_path, _unit_path):
	var player = get_tree().root.get_node(_player_path)
	
	var instance = load(_unit_path + ".tscn").instantiate()
	instance.name = str(_feedbackid) + "#" + instance.name

	player.find_child("Units").call("add_child", instance, true)
	
	while true:
		if instance.is_inside_tree(): break
	
	if _feedbackid != multiplayer.get_unique_id():
		handleSpawn.rpc_id(_feedbackid, instance.get_path())
	else:
		handleSpawn(instance.get_path())
	
@rpc("authority", "call_local", "reliable")
func handleSpawn(_unit_path):
	var instance = get_tree().root.get_node(_unit_path)
			
	instance.toggleUI(main.get_timer().is_preparing() and not main.get_timer().is_transitioning())
	
	var player = main.getPlayer()
	
	var instance_cost = instance.get_cost()
	player.decrease_gold(instance_cost)
	
	var upgradedUnit = upgrade(instance)

	if upgradedUnit:
		while(upgradedUnit):
			upgradedUnit = upgrade(upgradedUnit)
		return
		
	var tile = player.getBenchGrid().getFirstFreeTile()
	
	if tile != null:
		instance.tile = tile
		player.appendUnit(instance)
		tile.registerUnit(instance)
	else: 
		main.freeObject.rpc(instance.get_path())
		change_bought(false)

func upgrade(_unit):
	if _unit.star >= 3: return null
	
	var sameUnits = []
	# check if there are 2 more units of same name and star
	for u in main.getPlayer().getUnits():
		if u.unitName == _unit.unitName and u.star == _unit.star and _unit != u and u.get_mode() != u.BATTLE:
			sameUnits.append(u)
			if sameUnits.size() >= 2:
				if _unit.getTile():
					_unit.tile.unregisterUnit()
				_unit.transfer_items(sameUnits[0])
				main.getPlayer().eraseUnit(_unit) # this has to be done for the recursive upgrade. If _unit not in playerUnits nothing happens
				main.freeObject.rpc(_unit.get_path()) #unload
				# prioritze units on board, remove in bank
				if sameUnits[0].tile.get_parent().type == sameUnits[0].tile.get_parent().SQUARE:
					sameUnits[0].tile.unregisterUnit()
					main.getPlayer().eraseUnit(sameUnits[0])
					sameUnits[0].transfer_items(sameUnits[1])
					main.freeObject.rpc(sameUnits[0].get_path())
					sameUnits[1].levelUp()
					return sameUnits[1]
				else: 
					sameUnits[1].tile.unregisterUnit()
					main.getPlayer().eraseUnit(sameUnits[1])
					sameUnits[1].transfer_items(sameUnits[0])
					main.freeObject.rpc(sameUnits[1].get_path())
					sameUnits[0].levelUp()
					return sameUnits[0]
	return null
		
func generateButton():
	change_bought(false)
	
	var player_level = 1 if main.getPlayer() == null else main.getPlayer().get_level()
	
	var rarity = randf() # number between 0 and 1
	var drop_table = main.drop_rates[player_level - 1]
	for i in range(len(drop_table)):
		if rarity < drop_table[i]:
			unit_cost = i+1
			break
		rarity -= drop_table[i]
	
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
		1: background.color = Color(0.561, 0.561, 0.561)
		2: background.color = Color(0.027, 0.722, 0.161)
		3: background.color = Color(0.051, 0.671, 0.937)
		4: background.color = Color(0.623, 0.141, 1)
		5: background.color = Color(0.957, 0.773, 0.215)
	
	if main.getPlayer() == null or main.getPlayer().get_gold() < unit_cost:
		self_modulate = Color(0.251, 0.251, 0.251, 0.89)
		disabled = true
	else: 
		self_modulate = Color(1, 1, 1, 1)
		disabled = false

func change_bought(val):
	bought = val
	button_content.visible = !val
