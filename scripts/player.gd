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

var current_enemy = null # client sided but server sees it also

var my_bar

var defender = true

@export_category("Player Stats")
@export var start_gold: int = 1
var gold = 0
@onready var gold_label = main.getUI().get_node("UnitShop/Gold/HBoxContainer/GoldLabel")
@export var p_max_health = 100
var p_curr_health = p_max_health
var cons_wins = 0
var cons_loss = 0
var level = 0
var current_xp = 0
var xp_table = [
	0, # 1
	0, # 2
	2, # 3
	6, # 4
	10, # 5
	20, # 6
	36, # 7
	48, # 8
	72, # 9
	84 # 10
]

var defeated = false

var xp_button: Button
var rr_button: Button
const XP_COST = 4
const RR_COST = 2

var xp_bar: ProgressBar
var xp_label: Label
var level_label: Label

func _enter_tree():
	main = get_tree().root.get_child(0)
	myid = name.to_int()
	set_multiplayer_authority(myid)
	#print(str(multiplayer.get_unique_id()) + ": " + str(get_multiplayer_authority()))
	multiplayerSpawner.set_multiplayer_authority(1)

func _ready():
	while not is_instance_valid(my_bar) or my_bar == null:
		my_bar = main.getUI().get_node("PlayerBars/ColorRect/VBoxContainer").get_node(str(myid))
	
	if (is_multiplayer_authority()):
		main.setPlayer(self)
	
		var ids = multiplayer.get_peers()
		ids.append(myid)
		ids.sort()
		var i = ids.find(myid)

		global_transform.origin.x += 500 * i
		camera.change_current(true)	
		
		var sidebar = main.getUI().get_node("UnitShop/Sidebar")
		
		xp_button = sidebar.get_node("XPButton")
		xp_button.pressed.connect(buy_xp)
		rr_button = sidebar.get_node("RerollButton")
		rr_button.pressed.connect(reroll_shop)
		
		level_label = sidebar.get_node("LevelLabel")
		xp_bar = sidebar.get_node("XPBar")
		xp_label = sidebar.get_node("XPLabel")
		
		set_gold(start_gold)
	
		increase_level()

@rpc("any_peer", "call_local", "reliable")
func combatphase_setup(enemy_path = null, host:bool = true):
	if is_defeated(): return
	
	var unit_parent = find_child("Units")
	
	current_enemy = null
	
	defender = host
	
	if enemy_path == null: # pve phase	
		for unit in unit_parent.get_children():
			unit.combatphase_setup.rpc(host, myid)
		return

	current_enemy = get_tree().root.get_node(enemy_path)

	if not host:
		var item_parent = find_child("Items")
		var econ_parent = find_child("Econ")
		
		econ_parent.position = Vector3(-econ_parent.position.x, econ_parent.position.y, -econ_parent.position.z)
		econ_parent.rotate_y(deg_to_rad(180))
		econ_parent.global_transform.origin += current_enemy.global_transform.origin - global_transform.origin
		
		item_parent.position = Vector3(-item_parent.position.x, item_parent.position.y, -item_parent.position.z)
		item_parent.rotate_y(deg_to_rad(180))
		item_parent.global_transform.origin += current_enemy.global_transform.origin - global_transform.origin
		
		benchGrid.position = Vector3(-(benchGrid.position.x + 2*benchGrid.get_parent().position.x), benchGrid.position.y, -(benchGrid.position.z + 2*benchGrid.get_parent().position.z))
		benchGrid.rotate_y(deg_to_rad(180))
		benchGrid.global_transform.origin += current_enemy.global_transform.origin - global_transform.origin
			
		unit_parent.global_transform.origin = current_enemy.find_child("Units").global_transform.origin
		unit_parent.rotate_y(deg_to_rad(180))
		main.changeCameraByID(current_enemy.name.to_int())
				
	for unit in unit_parent.get_children():
		var host_id = myid if host else current_enemy.getID()
		var attacker_id = current_enemy.getID() if host else myid
		
		unit.combatphase_setup.rpc(host, host_id, attacker_id)


@rpc("any_peer", "call_local", "reliable")
func reset_combatphase():	
	if not is_defeated() and p_curr_health <= 0: # ensure player defeat if packet was lost during dmg
		defeat()
		
	if is_defeated(): return
	
	var unit_parent = find_child("Units")
	var item_parent = find_child("Items")
	var econ_parent = find_child("Econ")
	
	if is_multiplayer_authority():
		if not defender:
			econ_parent.position = Vector3(-econ_parent.position.x, econ_parent.position.y, -econ_parent.position.z)
			econ_parent.global_transform.origin += current_enemy.global_transform.origin - global_transform.origin
			econ_parent.rotation = Vector3.ZERO
			
			item_parent.position = Vector3(-item_parent.position.x, item_parent.position.y, -item_parent.position.z)
			item_parent.global_transform.origin += current_enemy.global_transform.origin - global_transform.origin
			item_parent.rotation = Vector3.ZERO
			
			benchGrid.position = Vector3(-(benchGrid.position.x + 2*benchGrid.get_parent().position.x), benchGrid.position.y, -(benchGrid.position.z + 2*benchGrid.get_parent().position.z))
			benchGrid.global_transform.origin += current_enemy.global_transform.origin - global_transform.origin
			benchGrid.rotation = Vector3.ZERO
			
			unit_parent.global_transform.origin = global_transform.origin
			unit_parent.rotation = Vector3.ZERO

		main.changeCamera(0)
		
	current_enemy = null
	
	for unit in unit_parent.get_children():
		unit.target = null
		unit.change_mode(unit.PREP)
		unit.dead = false
		
		if unit.is_multiplayer_authority():
			unit.curr_health = unit.max_health
			unit.target = null
			unit.visible = true
			unit.refresh_hpbar()
			unit.toggleUI(true)
			var tile_pos = unit.getTile().global_transform.origin
			unit.global_transform.origin = Vector3(tile_pos.x, unit.global_transform.origin.y, tile_pos.z)

@rpc("any_peer", "call_local", "reliable")
func copyUnit(unit_path, parent_path, host: bool, host_id: int, attacker_id: int = -1):
	var unit = get_tree().root.get_node(unit_path)
	var parent = get_tree().root.get_node(parent_path)
	var copy = unit.duplicate()
	parent.call("add_child", copy, true)
	while true:
		if copy.is_inside_tree(): break
	if unit.is_targetable():
		copy.change_mode(copy.BATTLE)
		copy.change_target_status(true)
		if not host: 
			var client_id = multiplayer.get_unique_id()
			if attacker_id == -1 or client_id != attacker_id and client_id != host_id:
				copy.set_bar_color(copy.ENEMY_ATTACKER_COLOR)
	else: copy.toggleUI(false)

func appendUnit(unit):
	units.append(unit)

func eraseUnit(unit):
	units.erase(unit)

func removeUnit(index):
	units.remove(index)
	
func getUnits():
	return units

func get_items():
	return get_node("Items").get_children()

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
	
func get_current_enemy():
	return current_enemy
	
func set_current_enemy(enemy):
	current_enemy = enemy
	
func get_gold():
	return gold
	
func set_gold(val):
	if is_defeated(): return
	
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
	
func get_health():
	return p_curr_health
	
# is called for every player
@rpc("any_peer", "call_local", "reliable")
func lose_health(amt):
	if is_defeated(): return
	
	p_curr_health -= amt
	
	my_bar.set_bar_value(float(max(p_curr_health,0.0))/float(p_max_health) * 100.0)
	my_bar.set_health_text(str(p_curr_health))
	
	sort_player_bars()
	
	if p_curr_health <= 0: 
		defeat()
	
# is called for every player as invoked by lose_health(amt)	
func defeat():
	defeated = true
	for unit in getUnits():
		unit.queue_free()
		
	if multiplayer.is_server():
		var players_left = main.players
		for player in players_left:
			if player.is_defeated(): players_left.erase(player)
			# TODO: trigger new scheduling
			
		if len(players_left) == 1:
			trigger_win(1)
		elif len(players_left) <= 1:
			printerr("ERROR: no players left")
			trigger_win(-1)
		
func trigger_win(id):
	print(str(id), " won the game!")
	# just change scene here. Is way easier
	
func sort_player_bars():
	var container = main.getUI().get_node("PlayerBars/ColorRect/VBoxContainer")
	
	var sorted_bars = container.get_children()
	
	sorted_bars.sort_custom(
		func(a: Control, b: Control):
			var player_a = main.find_child("World").get_node(str(a.name))
			var player_b = main.find_child("World").get_node(str(b.name))
		
			return player_a.get_health() > player_b.get_health()
	)
	
	for bar in container.get_children():
		container.remove_child(bar)
	
	for bar in sorted_bars:
		container.add_child(bar)
		
func is_defeated():
	return defeated
	
func get_level():
	return level
	
func increase_level():
	level += 1
	
	level_label.text = str(level)
	
	var rates = main.drop_rates[level - 1]
	var labels = main.getUI().get_node("UnitShop/RarityChances/HBoxContainer").get_children()
	for i in range(len(rates)):
		labels[i].text = str(rates[i]*100) + "%"
		
@rpc("any_peer", "call_local", "unreliable")
func increment_winstreak():
	cons_loss = 0
	cons_wins += 1
	var streak = main.getUI().get_node("UnitShop/Streak")
	streak.get_node("Label").text = str(cons_wins)
	streak.modulate = Color(1, 0, 0)
	increase_gold(1) # win bonus

@rpc("any_peer", "call_local", "unreliable")
func increment_lossstreak():
	cons_wins = 0
	cons_loss += 1
	var streak = main.getUI().get_node("UnitShop/Streak")
	streak.get_node("Label").text = str(cons_loss)
	streak.modulate = Color(0, 0.529, 1)
	
func increase_xp(amt: int):
	current_xp += amt
	
	if current_xp >= xp_table[level-1]:
		current_xp = min(xp_table[level-1], current_xp - xp_table[level-1])
		increase_level()
		
	xp_label.text = str(current_xp) + "/" + str(xp_table[level-1])
	xp_bar.value = float(current_xp) / float(max(1,xp_table[level-1])) * 100

func buy_xp():
	if gold < XP_COST: return
	increase_xp(4)
	decrease_gold(XP_COST)
	
func reroll_shop():
	if gold < RR_COST: return
	
	decrease_gold(RR_COST)
	
	var buttons = main.getUI().get_node("UnitShop/HBoxContainer").get_children()
	for button in buttons:
		button.generateButton()
		
@rpc("any_peer", "call_local", "reliable")
func spawn_item(path):
	var instance = load(path).instantiate()

	get_node("Items").call("add_child", instance, true)
	
	if is_multiplayer_authority():
		instance.position += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
