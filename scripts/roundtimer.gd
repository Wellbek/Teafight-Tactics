extends Timer

var preparing: bool = true

var current_round = 0 # this is what is visible: [CURRENT_STAGE]-[CURRENT_ROUND]
var total_round = 0 # this is the overall round counting to infinity
var current_stage = 1
const START_GAME_DURATION = 5
const FIRST_ROUND_DURATION = 15
const PREPARATION_DURATION = 30 #30
const COMBAT_DURATION = 45 #45
const TRANSITION_TIME = 5

var unitShop: Control
var game_start_label: Label
var timer_label: Label
var TIMER_DEFAULT_COLOR: Color
var stage_label: Label
var progressbar: ProgressBar

var main

var transitioning = false

var urf_overtime = false

func _enter_tree():
	set_multiplayer_authority(1) #only host controls time

func _process(delta):
	if current_stage == 1 and current_round == 1:
		game_start_label.text = "Game is starting in " + str(time_left).get_slice(".", 0) + "..."
		return
	
	if preparing == false and urf_overtime == false and not is_transitioning():
		timer_label.text = str(time_left-15).get_slice(".", 0)
	else: timer_label.text = str(time_left).get_slice(".", 0)
	
	if progressbar: 
		progressbar.value = time_left/wait_time * 100
		if not urf_overtime and progressbar.self_modulate != Color(0.051, 0.671, 0.937): 
			progressbar.self_modulate = Color(0.051, 0.671, 0.937)
	
	if time_left <= 16 and not urf_overtime and not is_preparing() and not is_transitioning() and multiplayer.is_server():
		trigger_overtime.rpc()
	
@rpc("authority", "call_local", "reliable")	
func trigger_overtime():
	urf_overtime = true
	
	change_timer_color(Color.ORANGE_RED)
	progressbar.self_modulate = Color.ORANGE_RED
	
	for unit in main.get_player().get_node("Units").get_children():
		unit.affected_by_urf = true
		unit.change_attack_speed(unit.attack_speed*3)
		unit.move_speed *= 1.5
		
		# https://leagueoflegends.fandom.com/wiki/Teamfight_Tactics_(game)#Rounds
		# ×3 attack speed.
		# 100% increased ability power.
		# 66% reduced crowd control duration.
		# 66% healing and shielding reduction.
		# 30% increased affection towards maritime mammals.
		
	for pve_round in main.get_player().get_node("PVERounds").get_children():
		if pve_round.visible == true:
			for minion in pve_round.get_children():
				minion.change_attack_speed(minion.attack_speed*3)
				minion.move_speed *= 1.5
		
func _ready():
	main = get_tree().root.get_child(0)
	unitShop = main.get_ui().get_node("UnitShop")
	game_start_label = main.get_ui().get_node("GameStartLabel")
	var stage_info = main.get_ui().get_node("StageInfo")
	timer_label = stage_info.get_node("TimerLabel")
	TIMER_DEFAULT_COLOR = timer_label.get_theme_color("font_color")
	stage_label = stage_info.get_node("StageLabel")
	progressbar = stage_info.get_node("ProgressBar")
	set_multiplayer_authority(1)
	
func initialize():	
	start_game.rpc()
	
@rpc("authority", "call_local", "reliable")
func start_game():
	increment_round()
	
	wait_time = START_GAME_DURATION
	start()


@rpc("authority", "call_local", "reliable")
func start_preparation_phase():		
	timer_label.add_theme_color_override("font_color", TIMER_DEFAULT_COLOR)

	increment_round()
	
	if multiplayer.is_server():
		for player in main.players:
			player.reset_combatphase.rpc()
	
		if current_round > 2 or current_stage >= 2: phase_gold_econ.rpc()
		
		if (current_stage == 1 and (current_round == 2 or current_round == 3 or current_round == 4)) or current_round == 6: 
			for player in main.players:
				for pve_round in player.get_node("PVERounds").get_children():
					set_pve_round.rpc(pve_round.get_path(), false)
				if not player.is_defeated():
					set_pve_round.rpc(player.get_node("PVERounds/" + str(current_stage) + "-" + str(current_round)).get_path(), true)
	
	preparing = true
	
	if main.get_player() and not main.get_player().is_defeated():
		var buttons = main.get_ui().get_node("UnitShop/HBoxContainer").get_children()
		for button in buttons:
			button.generate_button()
	#print("Preparation Phase Started for Round: ", current_round)
	
		for unit in main.get_player().get_units():
			var button = main.get_node("GUI/UnitShop/HBoxContainer/Button1")
			var upgradedUnit = button.upgrade(unit)

			if upgradedUnit:
				while(upgradedUnit):
					upgradedUnit = button.upgrade(upgradedUnit)
					
		if main.get_player().get_board_grid().can_place_unit():
			main.get_player().get_board_grid().toggle_label(true)
			
	if current_round > 2 or current_stage >= 2:
		if main.get_player() and not main.get_player().is_defeated(): unitShop.visible = true
		wait_time = PREPARATION_DURATION
	else: wait_time = FIRST_ROUND_DURATION
	start()

@rpc("authority", "call_local", "reliable")
func set_pve_round(path, val: bool):
	var round = get_node(path)
	if round != null: round.visible = val

# https://leagueoflegends.fandom.com/wiki/Gold_(Teamfight_Tactics)
@rpc("authority", "call_local", "reliable")
func phase_gold_econ():
	var player = main.get_player()
	
	if player.is_defeated(): return
	
	# passive income
	var passive_income = 5
	if total_round <= 3: passive_income = 2
	elif total_round == 4: passive_income = 3
	elif total_round == 5: passive_income = 4
	
	# interest
	var interest = floor(min(50, player.get_gold()) / 10)
	
	# streakgold
	var streakgold = 0
	var streak = max(player.get_winstreak(), player.get_lossstreak())
	if 3 <= streak and streak <= 4: streakgold = 1
	elif streak == 5: streakgold = 2
	elif streak >= 6: streakgold = 3
	
	player.increase_gold(passive_income + interest + streakgold)

@rpc("authority", "call_local", "reliable")
func start_combat_phase():
	timer_label.add_theme_color_override("font_color", TIMER_DEFAULT_COLOR)
	
	if main.get_player() and not main.get_player().is_defeated():	
		# place all units that are currently still being moved AND fill board as much as possible
		for unit in main.get_player().get_units():
			if unit.get_tile_type() == 0 and main.get_player().get_board_grid().can_place_unit():
				unit.place_unit(main.get_player().get_board_grid().get_first_free_tile())
			else:
				unit.place_unit()
				
		for item in main.get_player().get_items():
			if item.is_equipped(): item.place_item()
			
		main.get_player().get_board_grid().toggle_label(false)
	#print("Combat Phase Started for Round: ", current_round)
	
	transition()
	
	# determine matchups 
	if multiplayer.is_server():
		matchmake()

# server func
func matchmake():
	# pve rounds
	if (current_stage == 1 and (current_round == 2 or current_round == 3 or current_round == 4)) or current_round == 6: 
		for player in main.players:
			if player.is_defeated(): continue
			main.register_battle()
			player.combatphase_setup.rpc_id(player.get_id())
		return
	
	var player_ids = []
	for player in main.players:
		if not player.is_defeated():
			player_ids.append(player.get_id())
	
	var game_schedule = round_robin_pairs(player_ids)
	var round_schedule = game_schedule[total_round % len(game_schedule)]

	for matchup in round_schedule:
		var player1 = null
		var player2 = null
		for player in main.players:
			if player.get_id() == matchup[0]: player1 = player
			elif player.get_id() == matchup[1]: player2 = player
		
		if not (player1 and player2): 
			printerr("ERROR: couldn't matchmake as one of the players is NULL")
			return

		main.register_battle()

		# for server to do dmg calculations and clean up later
		player1.set_current_enemy(player2)
		player2.set_current_enemy(player1)

		# ^ each client will know its enemy in the following:
		player1.combatphase_setup.rpc_id(matchup[0], player2.get_path(), true)
		player2.combatphase_setup.rpc_id(matchup[1], player1.get_path(), false)
		
# round-robin tournament algorithm
func round_robin_pairs(list):
	if len(list) % 2 != 0: 
		list.append(-1)  # Add a dummy player if the number of elements is odd
	var num_players = len(list)
	var num_rounds = num_players - 1
	var schedule = []

	for round in range(num_rounds):
		var round_schedule = []
		for i in range(num_players / 2):
			if list[i] != -1 and list[num_players - 1 - i] != -1:
				round_schedule.append([list[i], list[num_players - 1 - i]])
		schedule.append(round_schedule)

		# Rotate the list clockwise, except for the first element
		list = [list[0]] + [list[-1]] + list.slice(1,num_players-1)

	return schedule
	
func _on_Timer_timeout():
	if not multiplayer.is_server(): return
	
	if current_round == 1 and current_stage == 1:
		give_start_unit.rpc()
		start_preparation_phase.rpc()
		return
	
	change_phase()
	
@rpc("authority", "call_local", "reliable")
func give_start_unit():
	# give random unit (since we only spawn one and shop is not visible during start round just use first shop button)
	var button1 = main.get_node("GUI/UnitShop/HBoxContainer/Button1")
	button1.spawn_unit.rpc_id(1, multiplayer.get_unique_id(), main.get_player().get_path(), button1.unit_path)
	
	# give random item
	var folder = "res://src/items"
	var dir = DirAccess.open(folder)
	var itemArray = dir.get_files()
	var itemFileName = itemArray[randi() % itemArray.size()].get_slice(".",0)
	
	var instance_path = folder + "//" + itemFileName + ".tscn"
	
	main.get_player().spawn_item(instance_path)
	
	game_start_label.visible = false
	
	for bar in main.get_ui().get_node("PlayerBars/VBoxContainer").get_children():
		bar.init_bar()
	
	main.get_ui().get_node("StageInfo").visible = true
	main.get_ui().get_node("PlayerBars").visible = true
	main.get_ui().get_node("Classes").visible = true
		
# server func	
func change_phase():
	if is_preparing():
		if is_transitioning():
			end_transition.rpc()
			change_timer.rpc(COMBAT_DURATION,true)
			change_timer_color.rpc(TIMER_DEFAULT_COLOR)
		else: start_combat_phase.rpc()
	else:
		if is_transitioning():
			end_transition.rpc()
			start_preparation_phase.rpc()
		else: transition.rpc()
	
@rpc("authority", "call_local", "reliable")
func change_timer(time, start):
	wait_time = time
	if start: 
		if preparing: preparing = false
		start()
	
# server func sent to all clients
@rpc("authority", "call_local", "reliable")
func transition():
	if urf_overtime:
		urf_overtime = false
		for unit in main.get_player().get_node("Units").get_children():
			if unit.affected_by_urf: 
				unit.affected_by_urf = false
				unit.change_attack_speed(unit.attack_speed/3)
				unit.move_speed /= 1.5

	transitioning = true
	change_timer_color(Color.CRIMSON)
	wait_time = TRANSITION_TIME
	start()

# server func sent to all clients
@rpc("authority", "call_local", "reliable")
func end_transition():
	transitioning = false

func is_transitioning():
	return transitioning

func is_preparing():
	return preparing
	
func get_round():
	return current_round
	
func get_stage():
	return current_stage
	
# https://tft.op.gg/game-guide/rounds?hl=en_US
func increment_round():
	if current_stage == 1:
		if current_round >= 4:
			current_stage += 1
			current_round = 1
		else: current_round += 1
	else:
		if current_round >= 6:
			current_stage += 1
			current_round = 1
		else: current_round += 1
	
	if not (current_stage == 1 and current_round == 1) and main.get_player() and not main.get_player().is_defeated():
		if not (current_stage == 1 and (current_round == 2 or current_round == 3 or current_round == 4)) and not current_round == 6: 
			total_round += 1 # exclude pve rounds else matchmaking is messed up
		
		if current_round > 2 or current_stage >= 2: 
			main.get_player().increase_xp(2)
		
		# drop random item every 3 rounds
		if current_round == 3 and current_stage > 1: 
			var folder = "res://src/items"
			var dir = DirAccess.open(folder)
			var itemArray = dir.get_files()
			var itemFileName = itemArray[randi() % itemArray.size()].get_slice(".",0)
	
			var instance_path = folder + "//" + itemFileName + ".tscn"
	
			main.get_player().spawn_item(instance_path)
	
	stage_label.text = str(current_stage) + "-" + str(current_round)
		
@rpc("authority","call_local", "unreliable")
func change_timer_color(color: Color):
	timer_label.add_theme_color_override("font_color", color)
