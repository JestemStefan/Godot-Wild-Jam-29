extends Control



enum ButtonTypes { DEFAULT, RETURN, QUIT }

export var panel_color : Color
export var grayed_out_color : Color
export var panel_size : float

var panel_x_offset : float = 0
var panels : Array = []

onready var options_panel : Control = new_panel([new_button("Back", null, ButtonTypes.RETURN)])
onready var sub_debug_panel : Control = new_panel([new_button("Back", null, ButtonTypes.RETURN)])
onready var debug_panel : Control = new_panel([new_label("Test Label"), new_button("Test Button"), new_button("Subdebug", sub_debug_panel), new_button("Back", null, true)])
onready var main_panel : Control = new_panel([new_button("Debug", debug_panel), new_button("Options", options_panel), new_button("Quit", null, ButtonTypes.QUIT)])



# Methods to be used inside/outside of script

func pause() -> void:
	visible = true
	add_panel(main_panel)



func unpause() -> void:
	visible = false



# Methods to be used inside of script only

func _ready() -> void:
	pause()



func update_panel_selection() -> void:
	for panel in get_tree().get_nodes_in_group("pause_panel"):
		for child in panel.get_children():
			if child.is_in_group("gray_out"):
				child.queue_free()
		
		if panel.rect_position.x != panel_x_offset - panel_size:
			var gray_out : ColorRect = ColorRect.new()
			
			gray_out.anchor_bottom = 1
			gray_out.rect_size.x = panel_size
			gray_out.color = grayed_out_color
			gray_out.add_to_group("gray_out")
			
			panel.add_child(gray_out)



func add_panel(panel : Control) -> void:
	panel.add_to_group("pause_panel")
	
	panel.rect_position.x = panel_x_offset
	panel_x_offset += panel_size
	
	panels.append(panel)
	
	panel.visible = true
	add_child(panel)
	update_panel_selection()



func pop_panel(count : int = 1) -> void:
	for _i in count:
		panel_x_offset -= panel_size
		panels[-1].visible = false # HACK: Using visiblity change right now because `remove_child` bugs the UI
		panels.pop_back()
	
	update_panel_selection()



func new_panel(gadgets : Array) -> Control:
	var control : Control = Control.new()
	var background : ColorRect = ColorRect.new()
	var vbox : VBoxContainer = VBoxContainer.new()
	
	for gadget in gadgets:
		vbox.add_child(gadget)
	
	background.anchor_right = 1
	background.anchor_bottom = 1
	background.color = panel_color
	
	vbox.anchor_left = 0.05
	vbox.anchor_right = 0.95
	vbox.anchor_top = 0.05
	vbox.anchor_bottom = 0.95
	
	control.anchor_bottom = 1
	control.rect_size.x = panel_size
	
	control.add_child(background)
	control.add_child(vbox)
	
	return control



func new_label(text : String) -> Label:
	var label_packed : PackedScene = load("res://scenes/ui/PauseLabel.tscn")
	var label : Label = label_packed.instance()
	
	label.text = text
	
	return label



func new_button(text : String, opens_panel : Control = null, button_type : int = PauseMenuButton.ButtonTypes.DEFAULT) -> PauseMenuButton:
	var button_packed : PackedScene = load("res://scenes/ui/PauseButton.tscn")
	var button : PauseMenuButton = button_packed.instance()
	
	button.text = text
	button.opens_panel = opens_panel
	button.button_type = button_type
	
	var _e = button.connect("button_pressed", self, "button_pressed")
	
	return button



func button_pressed(button : PauseMenuButton) -> void:
	match button.button_type:
		ButtonTypes.DEFAULT:
			pass
		
		ButtonTypes.RETURN:
			pop_panel()
		
		ButtonTypes.QUIT:
			get_tree().quit()
	
	if button.opens_panel:
		add_panel(button.opens_panel)