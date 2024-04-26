extends Control

@export var my_class_bars: VBoxContainer
@export var enemy_class_bars: VBoxContainer

var main = null

const CLASS_DICT = {
	"Herbal Heroes": [2,3,5],
	"Green Guardians": [2,3,4],
	"Black Brigade": [2,3,5],
	"Floral Fighters": [2,3,4],
	"Exotic Enchanters": [1,2,3],
	"Fruitful Forces": [2,3,4],
	"Aromatic Avatars": [2,3,5]
}

const TOOLTIPS = {
	"Herbal Heroes": "All units on board receive 100 additional max health during combat \n Herbal Heroes additionally get % bonus max health: \n 20% health \n 40% health \n 65% health",
	"Green Guardians": "All Green Guardians receive 15% omnivamp during combat and deal bonus damage. \n The bonus damage is doubled against units with less than 66% HP \n 5% bonus damage \n 10% bonus damage \n 20% bonus damage",
	"Black Brigade": "For Black Brigade units: Each attack stacks up the units attack speed up to 12 \n 5% per stack \n 10% per stack \n 15% per stack",
	"Floral Fighters": "All units on the board gain chance to dodge attacks \n 15% chance \n 25% chance \n 35% chance",
	"Exotic Enchanters": "Exotic Enchanters with atleast one item gain health and attack damage: \n 200 health, 35 attack damage \n 400 health, 50 attack damage \n 700 health, 70 attack damage",
	"Fruitful Forces": "Fruitful Forces units heal % max health every 4 seconds: \n 5% \n 10% \n 20%",
	"Aromatic Avatars": "Aromatic Avatars gain increased armor during combat. \n The bonus armor is increased by 100% for the first 10 seconds of each combat. \n 25 bonus armor \n 50 bonus armor \n 95 bonus armor"
}

func _ready():
	main = get_tree().root.get_child(0)

func get_unitclass(_name):
	return my_class_bars.get_node_or_null(_name)
	
func get_class_count(_name):
	var cb = get_unitclass(_name)
	return cb.get_count() if cb else 0
	
func get_class_level(_name):
	var cb = get_unitclass(_name)
	return cb.get_level() if cb else -1

func increase_count(_name):
	var cb = get_unitclass(_name)
	if cb: cb.increase_count()
	else: 
		cb = preload("res://src/ui/class_bar.tscn").instantiate()
		my_class_bars.add_child(cb)
		cb.init(_name, CLASS_DICT[_name][0], CLASS_DICT[_name][1], CLASS_DICT[_name][2], TOOLTIPS[_name])
	sort_bars()
	main.get_player().active_classes[_name] = get_class_count(_name)
	
func decrease_count(_name):
	var cb = get_unitclass(_name)
	if cb: 
		cb.decrease_count()
		if cb.get_count() <= 0:
			cb.free()
			main.get_player().active_classes.erase(_name)
		else: main.get_player().active_classes[_name] -= 1
		sort_bars()

func sort_bars(_parent = my_class_bars):
	var sorted_bars = _parent.get_children()
	
	sorted_bars.sort_custom(
		func(a: Control, b: Control):
			if a.get_level() == b.get_level():
				return a.get_count() > b.get_count()
			else: return a.get_level() > b.get_level()
	)
	
	for bar in _parent.get_children():
		_parent.remove_child(bar)
	
	for bar in sorted_bars:
		_parent.add_child(bar)
		
func see_bars_of_id(id):
	if id == multiplayer.get_unique_id():
		enemy_class_bars.visible = false
		my_class_bars.visible = true
	else:
		my_class_bars.visible = false
		enemy_class_bars.visible = true
		for child in enemy_class_bars.get_children():
			enemy_class_bars.remove_child(child)
		var e_classes = main.get_node("World/"+str(id)).active_classes
		for e_class in e_classes:
			var cb = preload("res://src/ui/class_bar.tscn").instantiate()
			enemy_class_bars.add_child(cb)
			cb.init(e_class, CLASS_DICT[e_class][0], CLASS_DICT[e_class][1], CLASS_DICT[e_class][2], TOOLTIPS[e_class])
			cb.increase_count(e_classes[e_class]-1) # 1 is default, hence we subtract 1
		sort_bars(enemy_class_bars)
