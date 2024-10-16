extends Node3D

var main

@export var benchGrid: Node3D
@export var boardGrid: Node3D
@export var camera: Camera3D
@export var enemyCam: Camera3D

@export var multiplayerSpawner: MultiplayerSpawner

enum {SQUARE, HEX}

var units = []
var combat_unit_set = {} # for tratis: only increase trait count if not already unit in there

var myid

var current_enemy = null # client sided but server sees it also

var my_bar

var defender = true

@export_category("Player Stats")
var steam_name = ""
@export var start_gold: int = 0
var gold = 0
@onready var gold_label = main.get_ui().get_node("UnitShop/Gold/HBoxContainer/GoldLabel")
@export var p_max_health = 100
var p_curr_health = p_max_health
var cons_wins = 0
var cons_loss = 0
var level = 0
var current_xp = 0
var XP_TABLE = [
	0, # 1
	2, # 2
	6, # 3
	10, # 4
	20, # 5
	36, # 6
	48, # 7
	72, # 8
	84, # 9
	9999 # 10
]

var defeated = false

var xp_button: Button
var rr_button: Button
const XP_COST = 4
const RR_COST = 2

var xp_bar: ProgressBar
var xp_label: Label
var level_label: Label

var unit_button_ids = [-1,-1,-1,-1,-1]

var active_classes = {} # class_name : amount

func get_unit_button_ids():
	return unit_button_ids
	
func set_unit_button_ids(idx, val):
	unit_button_ids[idx] = val

func _enter_tree():
	main = get_tree().root.get_child(0)
	myid = name.to_int()
	set_multiplayer_authority(myid)
	#print(str(multiplayer.get_unique_id()) + ": " + str(get_multiplayer_authority()))
	multiplayerSpawner.set_multiplayer_authority(1)

func _ready():
	while not is_instance_valid(my_bar) or my_bar == null:
		my_bar = main.get_ui().get_node("PlayerBars/VBoxContainer").get_node(str(myid))
	
	if (is_multiplayer_authority()):
		main.set_player(self)
	
		var ids = multiplayer.get_peers()
		ids.append(myid)
		ids.sort()
		var i = ids.find(myid)

		global_transform.origin.x += 500 * i
		camera.change_current(true)	
		
		var sidebar = main.get_ui().get_node("UnitShop/Sidebar")
		
		xp_button = sidebar.get_node("XPButton")
		xp_button.pressed.connect(buy_xp)
		rr_button = sidebar.get_node("RerollButton")
		rr_button.pressed.connect(reroll_shop)
		
		level_label = sidebar.get_node("LevelLabel")
		xp_bar = sidebar.get_node("XPBar")
		xp_label = sidebar.get_node("XPLabel")
		
		steam_name = main.get_node("MultiplayerManager").steam_username
		
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

	current_enemy = get_tree().root.get_node_or_null(enemy_path)
	
	if current_enemy: 
		var enemy_steam_name = current_enemy.get_steam_name()
		main.get_ui().get_node("StageInfo/EnemyLabel").text = "Enemy: " + (enemy_steam_name if (enemy_steam_name != "" and not main.get_node("MultiplayerManager").test) else "Player" + current_enemy.name)

	if not host and current_enemy:
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
		main.change_camera_by_id(current_enemy.name.to_int())
				
	for unit in unit_parent.get_children():
		var host_id = myid if host else current_enemy.get_id()
		var attacker_id = current_enemy.get_id() if host else myid
		
		unit.combatphase_setup.rpc(host, host_id, attacker_id)


@rpc("any_peer", "call_local", "reliable")
func reset_combatphase():	
	if not is_defeated() and p_curr_health <= 0: # ensure player defeat if packet was lost during dmg
		defeat()
		
	if is_defeated(): return
	
	var unit_parent = find_child("Units")
	var item_parent = find_child("Items")
	var econ_parent = find_child("Econ")
	
	main.get_ui().get_node("StageInfo/EnemyLabel").text = ""
	
	if is_multiplayer_authority():
		if not defender and current_enemy:
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

		main.change_camera(0)
		
	current_enemy = null
	
	for unit in unit_parent.get_children():
		unit.target = null
		unit.change_mode(unit.PREP)
		unit.dead = false
		
		if unit.is_multiplayer_authority():
			unit.rotation = Vector3(0,0,0)
			unit.curr_health = unit.max_health
			unit.target = null
			unit.visible = true
			unit.refresh_hpbar()
			unit.toggle_ui(true)
			var tile_pos = unit.get_tile().global_transform.origin
			unit.global_transform.origin = Vector3(tile_pos.x, unit.global_transform.origin.y, tile_pos.z)

@rpc("any_peer", "call_local", "reliable")
func copy_unit(unit_path, parent_path, host: bool, host_id: int, attacker_id: int = -1):
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
	else: copy.toggle_ui(false)

func append_unit(unit):
	units.append(unit)

func erase_unit(unit):
	units.erase(unit)

func remove_unit(index):
	units.remove(index)
	
func get_units():
	return units

func get_items():
	return get_node("Items").get_children()

func get_bench_grid():
	return benchGrid

func get_board_grid():
	return boardGrid
	
func get_camera():
	return camera
	
func get_enemy_cam():
	return enemyCam
	
func get_id():
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
	
	var buttons = main.get_ui().get_node("UnitShop/HBoxContainer").get_children()
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
	if defeated: return
	
	defeated = true
	
	if is_multiplayer_authority():
		for unit in find_child("Units").get_children():
			unit.sell_unit() # free all and return units back to pool
	
	main.get_ui().get_node("UnitShop").visible = false
		
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
	var container = main.get_ui().get_node("PlayerBars/VBoxContainer")
	
	var sorted_bars = container.get_children()
	
	sorted_bars.sort_custom(
		func(a: Control, b: Control):
			var player_a = main.find_child("World").get_node(str(a.name))
			var player_b = main.find_child("World").get_node(str(b.name))
			
			if player_a.is_defeated() and not player_b.is_defeated(): return false # if player a is defeated but b not, b is always on top
			elif player_b.is_defeated(): return true # if player_b is already defeated then regardless if a is or not, keep order
		
			return player_a.get_health() > player_b.get_health() # when both alive order based on hp
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
	if defeated: return
	
	level += 1
	
	level_label.text = str(level)
	
	var rates = main.DROP_RATES[level - 1]
	var labels = main.get_ui().get_node("UnitShop/RarityChances/HBoxContainer").get_children()
	for i in range(len(rates)):
		labels[i].text = str(rates[i]*100) + "%"
		
	get_board_grid().toggle_label(true)
		
@rpc("any_peer", "call_local", "unreliable")
func increment_winstreak():
	if defeated: return
	
	cons_loss = 0
	cons_wins += 1
	var streak = main.get_ui().get_node("UnitShop/Streak")
	streak.get_node("Label").text = str(cons_wins)
	streak.modulate = Color(1, 0, 0)
	increase_gold(1) # win bonus

@rpc("any_peer", "call_local", "unreliable")
func increment_lossstreak():
	if defeated: return
	
	cons_wins = 0
	cons_loss += 1
	var streak = main.get_ui().get_node("UnitShop/Streak")
	streak.get_node("Label").text = str(cons_loss)
	streak.modulate = Color(0, 0.529, 1)
	
func increase_xp(amt: int):
	if defeated: return
	
	current_xp += amt
	
	if current_xp >= XP_TABLE[level-1]:
		current_xp = min(XP_TABLE[level-1], current_xp - XP_TABLE[level-1])
		increase_level()
		
	xp_label.text = str(current_xp) + "/" + str(XP_TABLE[level-1])
	xp_bar.value = float(current_xp) / float(max(1,XP_TABLE[level-1])) * 100

func buy_xp():
	if gold < XP_COST or is_defeated(): return
	increase_xp(4)
	decrease_gold(XP_COST)
	
func reroll_shop():
	if gold < RR_COST or is_defeated(): return
	
	decrease_gold(RR_COST)

	main.generate_buttons.rpc_id(1,get_id())
		
@rpc("any_peer", "call_local", "reliable")
func spawn_item(path):
	if defeated: return
	
	var instance = load(path).instantiate()

	get_node("Items").call("add_child", instance, true)
	
	if is_multiplayer_authority():
		instance.position += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		
func get_steam_name():
	return steam_name
