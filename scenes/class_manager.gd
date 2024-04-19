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
		cb.init(_name, CLASS_DICT[_name][0], CLASS_DICT[_name][1], CLASS_DICT[_name][2])
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
			return a.get_count() > b.get_count()
	)
	
	for bar in class_bars.get_children():
		class_bars.remove_child(bar)
	
	for bar in sorted_bars:
		class_bars.add_child(bar)
