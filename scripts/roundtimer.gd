extends Timer

var preparing: bool

var currentRound = 1
var preparationDuration = 20 #30
var combatDuration = 1 #??

var unitShop: Control
var label: Label

var main

func _process(delta):
	label.text = str(time_left).get_slice(".", 0)

func _ready():
	main = get_tree().root.get_child(0)
	unitShop = main.getUI().get_node("UnitShop")
	label = main.getUI().get_node("TimerLabel")
	startPreparationPhase()

func startPreparationPhase():
	unitShop.visible = true
	preparing = true
	print("Preparation Phase Started for Round:", currentRound)

	wait_time = preparationDuration
	start()

func startCombatPhase():
	for unit in main.playerUnits:
		unit.placeUnit()
	unitShop.visible = false
	preparing = false
	print("Combat Phase Started for Round:", currentRound)

	wait_time = combatDuration
	start()

func _on_Timer_timeout():
	if preparing:
		startCombatPhase()
	else:
		currentRound += 1
		startPreparationPhase()
		
func isPreparing():
	return preparing
