extends Control

var unit = null

@export var stars: Control
@export var unit_icon: TextureRect
@export var	name_label: Label
@export var cost_label: Label
@export var rarity_rect: ColorRect
@export var hp_bar: ProgressBar
@export var mana_bar: ProgressBar
@export var ad_label: Label
@export var ap_label: Label
@export var armor_label: Label
@export var mr_label: Label
@export var as_label: Label
@export var ar_label: Label
@export var critc_label: Label
@export var critd_label: Label
@export var omnivamp_label: Label
@export var dodge_label: Label
@export var movespeed_label: Label
@export var trait_label: Label
@export var trait_icons: Control
@export var ability_control: Control

func set_unit(_unit):
	if unit == _unit and unit != null: 
		set_unit(null)
		return
	
	unit = _unit
	
	if unit == null: 
		visible = false
		return
	
	unit_icon.texture = load(unit.image)
	name_label.text = unit.unit_name
	var color = Color.WHITE
	match unit.rarity:
		1: color = Color(0.561, 0.561, 0.561)
		2: color = Color(0.027, 0.722, 0.161)
		3: color = Color(0.051, 0.671, 0.937)
		4: color = Color(0.623, 0.141, 1)
		5: color = Color(0.957, 0.773, 0.215)
	rarity_rect.self_modulate = color
	hp_bar.self_modulate = Color.LIME_GREEN if unit.is_multiplayer_authority() else Color.RED
	trait_label.text = unit.CLASS_NAMES[unit.type]
	for t_icon in trait_icons.get_children():
		if t_icon.name == "Background": continue
		t_icon.visible = (t_icon.name == trait_label.text)
	ability_control.get_node("Scaling").text = "Ability: " + unit.ABILITY_TYPES[unit.ability_id] + "\n" + str(int(unit.scaling1*100)) + "% / " + str(int(unit.scaling2*100)) + "% / " + str(int(unit.scaling3*100)) + "% " + unit.ABILITY_DMG_TYPES[unit.ability_dmg_type]
	ability_control.tooltip_text = unit.ABILITY_TT[unit.ability_id]
	
	visible = true

func _process(delta):
	if unit and is_instance_valid(unit) and visible:
		for i in range(3):
			stars.get_child(i).visible = (unit.star == i+1)
		cost_label.text = str(unit.cost)
		hp_bar.value = (unit.curr_health/unit.max_health)*100
		hp_bar.get_node("Label").text = str(int(unit.curr_health)) + "/" + str(int(unit.max_health))
		mana_bar.value = (unit.curr_mana/unit.max_mana)*100
		mana_bar.get_node("Label").text = str(int(unit.curr_mana)) + "/" + str(int(unit.max_mana))
		ad_label.text = str(int(unit.attack_dmg))
		ap_label.text = str(int(unit.ability_power))
		armor_label.text = str(int(unit.armor))
		mr_label.text = str(int(unit.mr))
		as_label.text = str(unit.attack_speed)
		ar_label.text = str(int(unit.attackrange/2)) + " Cells"
		critc_label.text = str(int(unit.crit_chance*100)) + " %"
		critd_label.text = str(int(100+unit.crit_damage*100)) + " %"
		omnivamp_label.text = str(int(unit.omnivamp*100)) + " %"
		dodge_label.text = str(int(unit.dodge_chance*100)) + " %"
		movespeed_label.text = str(int(unit.move_speed*100))
		
	elif visible or unit:
		set_unit(null)


func _on_button_button_down():
	set_unit(null)
