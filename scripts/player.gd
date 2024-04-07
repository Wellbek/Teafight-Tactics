extends Node3D

var main

@export var benchGrid: Node3D
@export var boardGrid: Node3D
@export var camera: Camera3D
@export var enemyCam: Camera3D

@export var multiplayerSpawner: MultiplayerSpawner

enum {SQUARE, HEX}

var units = []

var myid

var current_enemy = null

@export_category("Player Stats")
@export var start_gold: int = 2
var gold = 0
@onready var gold_label = main.getUI().get_node("UnitShop/Gold/HBoxContainer/GoldLabel")
@export var p_max_health = 100
var p_curr_health = p_max_health
var cons_wins = 0
var cons_loss = 0

func _enter_tree():
	main = get_tree().root.get_child(0)
	myid = name.to_int()
	set_multiplayer_authority(myid)
	#print(str(multiplayer.get_unique_id()) + ": " + str(get_multiplayer_authority()))
	multiplayerSpawner.set_multiplayer_authority(1)

func _ready():
	if (is_multiplayer_authority()):
		main.setPlayer(self)
	
		var ids = multiplayer.get_peers()
		ids.append(myid)
		ids.sort()
		var i = ids.find(myid)

		global_transform.origin.x += 19 * i
		camera.current = true	
		
		set_gold(start_gold)

@rpc("any_peer", "call_local", "reliable")
func combatphase_setup(enemy_path, host:bool):
	current_enemy = get_tree().root.get_node(enemy_path)
	
	var unit_parent = find_child("Units")
	unit_parent.visible = false
	var combatunit_parent = find_child("CombatUnits")	
	
	if not host:	
		combatunit_parent.global_transform.origin = current_enemy.find_child("CombatUnits").global_transform.origin
		combatunit_parent.rotate_y(deg_to_rad(180))
		main.changeCameraByID(current_enemy.name.to_int())
				
	for unit in unit_parent.get_children():
			copyUnit.rpc(unit.get_path(), combatunit_parent.get_path())

	combatunit_parent.visible = true

@rpc("any_peer", "call_local", "reliable")
func reset_combatphase():	
	var unit_parent = find_child("Units")
	var combatunit_parent = find_child("CombatUnits")	
	
	for unit in combatunit_parent.get_children():
		main.freeObject.rpc(unit.get_path())
		
	combatunit_parent.visible = false
		
	combatunit_parent.global_transform.origin = unit_parent.global_transform.origin
	combatunit_parent.rotation = Vector3.ZERO
	
	current_enemy = null
	
	unit_parent.visible = true	
	main.changeCamera(0)

@rpc("any_peer", "call_local", "reliable")
func copyUnit(unit_path, parent_path):
	var unit = get_tree().root.get_node(unit_path)
	var parent = get_tree().root.get_node(parent_path)
	var copy = unit.duplicate()
	parent.call("add_child", copy, true)
	while true:
		if copy.is_inside_tree(): break
	if unit.is_targetable():
		copy.change_mode(copy.BATTLE)
		copy.change_target_status(true)

func appendUnit(unit):
	units.append(unit)

func eraseUnit(unit):
	units.erase(unit)

func removeUnit(index):
	units.remove(index)
	
func getUnits():
	return units

func getBenchGrid():
	return benchGrid

func getBoardGrid():
	return boardGrid
	
func getCamera():
	return camera
	
func getEnemyCam():
	return enemyCam
	
func getID():
	return myid
	
func getCurrentEnemy():
	return current_enemy
	
func get_gold():
	return gold
	
func set_gold(val):
	gold = max(0, val)
	gold_label.text = str(gold)
	for i in range(1,6):
		var econ_object = find_child("Econ").get_node(str(i))
		if gold >= i*10:
			econ_object.visible = true
		else:
			econ_object.visible = false
	
	var buttons = main.getUI().get_node("UnitShop/HBoxContainer").get_children()
	for button in buttons:
		button._on_player_gold_changed(gold)
	
func increase_gold(amount):
	set_gold(gold+amount)

func decrease_gold(amount):
	set_gold(gold-amount)
	
func get_winstreak():
	return cons_wins
	
func get_lossstreak():
	return cons_loss
	
