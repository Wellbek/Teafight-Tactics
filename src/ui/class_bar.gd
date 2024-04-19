extends Control

@export var circle: TextureRect
@export var class_name_label: Label
@export var curr_count_label: Label
@export var class_step_label: Label

var c_name: String
var count: int = 0
var steps = []

func init(_c_name, _step1, _step2, _step3, _increment: bool = true):
	c_name = _c_name
	steps = [_step1, _step2, _step3]
	count = 1 if _increment else 0
	name = c_name
	class_name_label.text = c_name
	class_step_label.text = str(_step1) + " > " + str(_step2) + " > " + str(_step3)
	refresh()
	
func refresh():
	curr_count_label.text = str(count)
	
	var tex = -1
	for i in range(len(steps)):
		if count >= steps[i]: tex = i
		else: break
		
	var circle_color = Color(0.157, 0.157, 0.157)
	match tex:
		0: circle_color = Color.SADDLE_BROWN
		1: circle_color = Color.SILVER
		2: circle_color = Color.GOLD
		_: pass
	circle.self_modulate = circle_color
	
func increase_count():
	count += 1
	refresh()
	
func decrease_count():
	count -= 1
	refresh()
	
func get_count():
	return count
	
func get_level():
	var level = 0
	for i in range(len(steps)):
		if count >= steps[i]: level = i+1
		else: break
	
	return level
