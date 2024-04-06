extends Timer

var preparing: bool

var current_round = 1
var preparationDuration = 10 #30
var combatDuration = 20 #??

var unitShop: Control
var label: Label

var main

var host = false

var game_schedule = []

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
	var peer_ids = multiplayer.get_peers()
	var player_ids = [multiplayer.get_unique_id()]
	player_ids.append_array(peer_ids)
	
	game_schedule = round_robin_pairs(player_ids)
	
	startPreparationPhase.rpc()

@rpc("authority", "call_local", "reliable")
func startPreparationPhase():
	if multiplayer.is_server():
		for player in main.players:
			player.reset_combatphase.rpc_id(player.getID())
	
	unitShop.visible = true
	preparing = true
	#print("Preparation Phase Started for Round: ", current_round)
	
	wait_time = preparationDuration
	start()

@rpc("authority", "call_local", "reliable")
func startCombatPhase():
	for unit in main.getPlayer().getUnits():
		unit.placeUnit()
	unitShop.visible = false
	preparing = false
	#print("Combat Phase Started for Round: ", current_round)
	
	# determine matchups 
	if multiplayer.is_server():
		matchmake()
	
	wait_time = combatDuration	
	start()

# server func
func matchmake():
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
	change_phase()
		
func change_phase():
	if not multiplayer.is_server(): return
	
	if preparing:
		startCombatPhase.rpc()
	else:
		current_round += 1
		startPreparationPhase.rpc()
		
func isPreparing():
	return preparing
