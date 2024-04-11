extends Timer

var preparing: bool = true

var current_round = 0 # this is what is visible: [CURRENT_STAGE]-[CURRENT_ROUND]
var total_round = 0 # this is the overall round counting to infinity
var current_stage = 1
const preparationDuration = 30 #30
const combatDuration = 45 #45
const transition_time = 5

var unitShop: Control
var timer_label: Label
var TIMER_DEFAULT_COLOR: Color
var stage_label: Label
var progressbar: ProgressBar

var main

var host = false

var transitioning = false

var urf_overtime = false

func _enter_tree():
	set_multiplayer_authority(1) #only host controls time

func _process(delta):		
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
	
	for combat_unit in main.getPlayer().get_node("CombatUnits").get_children():
		combat_unit.change_attack_speed(combat_unit.attack_speed*3)
		combat_unit.move_speed *= 1.5
		
		# https://leagueoflegends.fandom.com/wiki/Teamfight_Tactics_(game)#Rounds
		# ×3 attack speed.
		# 100% increased ability power.
		# 66% reduced crowd control duration.
		# 66% healing and shielding reduction.
		# 30% increased affection towards maritime mammals.
		
	for pve_round in main.getPlayer().get_node("PVERounds").get_children():
		if pve_round.visible == true:
			for minion in pve_round.get_children():
				minion.change_attack_speed(minion.attack_speed*3)
				minion.move_speed *= 1.5
		
func _ready():
	main = get_tree().root.get_child(0)
	unitShop = main.getUI().get_node("UnitShop")
	var stage_info = main.getUI().get_node("StageInfo")
	timer_label = stage_info.get_node("TimerLabel")
	TIMER_DEFAULT_COLOR = timer_label.get_label_settings().get_font_color()
	stage_label = stage_info.get_node("StageLabel")
	progressbar = stage_info.get_node("ProgressBar")
	set_multiplayer_authority(1)
	
func initialize():	
	startPreparationPhase.rpc()

@rpc("authority", "call_local", "reliable")
func startPreparationPhase():		
	timer_label.get_label_settings().set_font_color(TIMER_DEFAULT_COLOR)

	increment_round()
	
	if current_round >= 2: # skip first round
		if multiplayer.is_server():
			for player in main.players:
				player.reset_combatphase.rpc_id(player.getID())
		
			phase_gold_econ.rpc()
			
			if (current_stage == 1 and (current_round == 2 or current_round == 3 or current_round == 4)) or current_round == 7: 
				for player in main.players:
					for pve_round in player.get_node("PVERounds").get_children():
						set_pve_round.rpc(pve_round.get_path(), false)
					set_pve_round.rpc(player.get_node("PVERounds/" + str(current_stage) + "-" + str(current_round)).get_path(), true)
	
	if not main.getPlayer() == null and not main.getPlayer().is_defeated():
		unitShop.visible = true
	preparing = true
	#print("Preparation Phase Started for Round: ", current_round)
	
	if main.getPlayer() and main.getPlayer().getBoardGrid().can_place_unit():
		main.getPlayer().getBoardGrid().toggle_label(true)
	
	wait_time = preparationDuration
	start()

@rpc("authority", "call_local", "reliable")
func set_pve_round(path, val: bool):
	var round = get_node(path)
	if round != null: round.visible = val

# https://leagueoflegends.fandom.com/wiki/Gold_(Teamfight_Tactics)
@rpc("authority", "call_local", "reliable")
func phase_gold_econ():
	var player = main.getPlayer()
	
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
func startCombatPhase():
	timer_label.get_label_settings().set_font_color(TIMER_DEFAULT_COLOR)
	
	if not main.getPlayer().is_defeated():	
		# place all units that are currently still being moved AND fill board as much as possible
		for unit in main.getPlayer().getUnits():
			if unit.getTileType() == 0 and main.getPlayer().getBoardGrid().can_place_unit():
				unit.placeUnit(main.getPlayer().getBoardGrid().getFirstFreeTile())
			else:
				unit.placeUnit()
			
		main.getPlayer().getBoardGrid().toggle_label(false)
		unitShop.visible = false
	#print("Combat Phase Started for Round: ", current_round)
	
	transition()
	
	# determine matchups 
	if multiplayer.is_server():
		matchmake()

# server func
func matchmake():
	# pve rounds
	if (current_stage == 1 and (current_round == 2 or current_round == 3 or current_round == 4)) or current_round == 7: 
		for player in main.players:
			main.register_battle()
			player.combatphase_setup.rpc_id(player.getID())
		return
	
	var player_ids = []
	for player in main.players:
		if not player.is_defeated():
			player_ids.append(player.getID())
	
	var game_schedule = round_robin_pairs(player_ids)
	var round_schedule = game_schedule[total_round % len(game_schedule)]

	for matchup in round_schedule:
		var player1 = null
		var player2 = null
		for player in main.players:
			if player.getID() == matchup[0]: player1 = player
			elif player.getID() == matchup[1]: player2 = player
		
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
	
	change_phase()
	
# server func	
func change_phase():
	if is_preparing():
		if is_transitioning():
			end_transition.rpc()
			change_timer.rpc(combatDuration,true)
			change_timer_color.rpc(TIMER_DEFAULT_COLOR)
		else: startCombatPhase.rpc()
	else:
		if is_transitioning():
			end_transition.rpc()
			startPreparationPhase.rpc()
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
	urf_overtime = false
	transitioning = true
	change_timer_color(Color.CRIMSON)
	wait_time = transition_time
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
		if current_round >= 7:
			current_stage += 1
			current_round = 1
		else: current_round += 1
		
	if not (current_stage == 1 and (current_round == 2 or current_round == 3 or current_round == 4)) and not current_round == 7: 
		total_round += 1 # exclude pve rounds else matchmaking is messed up
	
	if main.getPlayer() != null: main.getPlayer().increase_xp(2)
	stage_label.text = str(current_stage) + "-" + str(current_round)
		
@rpc("authority","call_local", "unreliable")
func change_timer_color(color: Color):
	timer_label.get_label_settings().set_font_color(color)
