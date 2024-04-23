extends Control

@export var class_bars: VBoxContainer

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
	"Green Guardians": "All Green Guardians receive 30% omnivamp during combat and deal bonus damage. \n The bonus damage is doubled against units with less than 66% HP \n 5% bonus damage \n 10% bonus damage \n 20% bonus damage",
	"Black Brigade": "For Black Brigade units: Each attack stacks up the units attack speed up to 12 \n 5% per stack \n 10% per stack \n 15% per stack",
	"Floral Fighters": "All units on the board gain chance to dodge attacks \n 15% chance \n 25% chance \n 35% chance",
	"Exotic Enchanters": "Exotic Enchanters with atleast one item gain health and attack damage: \n 200 health, 35 attack damage \n 400 health, 50 attack damage \n 700 health, 70 attack damage",
	"Fruitful Forces": "Fruitful Forces units heal % max health every 4 seconds: \n 5% \n 10% \n 20%",
	"Aromatic Avatars": "Aromatic Avatars gain increased armor during combat. \n The bonus armor is increased by 50% for the first 10 seconds of each combat. \n 25 bonus armor \n 50 bonus armor \n 95 bonus armor"
}

func get_unitclass(_name):
	return class_bars.get_node_or_null(_name)
	
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
		class_bars.add_child(cb)
		cb.init(_name, CLASS_DICT[_name][0], CLASS_DICT[_name][1], CLASS_DICT[_name][2], TOOLTIPS[_name])
	sort_bars()
	
func decrease_count(_name):
	var cb = get_unitclass(_name)
	if cb: 
		cb.decrease_count()
		if cb.get_count() <= 0:
			cb.free()
		sort_bars()

func sort_bars():
	var sorted_bars = class_bars.get_children()
	
	sorted_bars.sort_custom(
		func(a: Control, b: Control):
			if a.get_level() == b.get_level():
				return a.get_count() > b.get_count()
			else: return a.get_level() > b.get_level()
	)
	
	for bar in class_bars.get_children():
		class_bars.remove_child(bar)
	
	for bar in sorted_bars:
		class_bars.add_child(bar)
