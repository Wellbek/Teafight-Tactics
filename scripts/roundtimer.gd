extends Timer

var preparing: bool

var current_round = 1
var preparationDuration = 15 #30
var combatDuration = 20 #??
var transition_time = 4

var unitShop: Control
var label: Label

var main

var host = false

var transitioning = false

func _enter_tree():
	set_multiplayer_authority(1) #only host controls time

func _process(delta):
	label.text = str(time_left).get_slice(".", 0)

func _ready():
	main = get_tree().root.get_child(0)
	unitShop = main.getUI().get_node("UnitShop")
	label = main.getUI().get_node("TimerLabel")
	set_multiplayer_authority(1)
	
func initialize():	
	startPreparationPhase.rpc(current_round)

@rpc("authority", "call_local", "reliable")
func startPreparationPhase(round):
	current_round = round
	
	if current_round >= 2: # skip first round
		if multiplayer.is_server():
			for player in main.players:
				player.reset_combatphase.rpc_id(player.getID())
		
			phase_gold_econ.rpc()
	
	if main.getPlayer() == null or not main.getPlayer().is_defeated():
		unitShop.visible = true
	preparing = true
	#print("Preparation Phase Started for Round: ", current_round)
	
	wait_time = preparationDuration
	start()

# https://leagueoflegends.fandom.com/wiki/Gold_(Teamfight_Tactics)
@rpc("authority", "call_local", "reliable")
func phase_gold_econ():
	var player = main.getPlayer()
	
	if player.is_defeated(): return
	
	# passive income
	var passive_income = 5
	if current_round <= 3: passive_income = 2
	elif current_round == 4: passive_income = 3
	elif current_round == 5: passive_income = 4
	
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
	if not main.getPlayer().is_defeated():	
		for unit in main.getPlayer().getUnits():
			unit.placeUnit()
		unitShop.visible = false
	#print("Combat Phase Started for Round: ", current_round)
	
	transition()
	
	# determine matchups 
	if multiplayer.is_server():
		matchmake()

# server func
func matchmake():
	var player_ids = []
	for player in main.players:
		if not player.is_defeated():
			player_ids.append(player.getID())
	
	var game_schedule = round_robin_pairs(player_ids)
	
	var round_schedule = game_schedule[current_round % len(game_schedule)]

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
	if isPreparing():
		if is_transitioning():
			end_transition.rpc()
			change_timer.rpc(combatDuration,true)
			preparing = false
		else: startCombatPhase.rpc()
	else:
		if is_transitioning():
			end_transition.rpc()
			current_round += 1
			startPreparationPhase.rpc(current_round)
		else: transition.rpc()
	
@rpc("authority", "call_local", "reliable")
func change_timer(time, start):
	wait_time = time
	if start: start()
	
# server func sent to all clients
@rpc("authority", "call_local", "reliable")
func transition():
	transitioning = true	
	wait_time = transition_time
	start()

# server func sent to all clients
@rpc("authority", "call_local", "reliable")
func end_transition():
	transitioning = false

func is_transitioning():
	return transitioning

func isPreparing():
	return preparing
