extends CanvasLayer

# --- Node References ---
@onready var pause_container = $PanelContainer
@onready var resume_button = $PanelContainer/VBox/ResumeButton
@onready var restart_button = $PanelContainer/VBox/RestartButton
@onready var settings_button = $PanelContainer/VBox/SettingsButton
@onready var menu_button = $PanelContainer/VBox/MenuButton
@onready var quit_button = $PanelContainer/VBox/QuitButton

@onready var confirm_overlay = $ConfirmOverlay
@onready var confirm_prompt = $ConfirmOverlay/VBox/ConfirmPrompt
@onready var yes_button = $ConfirmOverlay/VBox/HBox/YesButton
@onready var no_button = $ConfirmOverlay/VBox/HBox/NoButton

@onready var settings_overlay = $SettingsOverlay
@onready var master_slider = $SettingsOverlay/VBox/SliderGrid/MasterSlider
@onready var music_slider = $SettingsOverlay/VBox/SliderGrid/MusicSlider
@onready var sfx_slider = $SettingsOverlay/VBox/SliderGrid/SFXSlider
@onready var settings_back_button = $SettingsOverlay/VBox/BackButton

# Tracks what action we are confirming: "menu" or "quit"
var _pending_action: String = ""

func _ready() -> void:
	# Hide by default
	visible = false
	confirm_overlay.visible = false
	settings_overlay.visible = false
	pause_container.visible = true
	process_mode = Node.PROCESS_MODE_ALWAYS # Crucial: runs when game is paused
	
	# Connect signals
	resume_button.pressed.connect(resume_game)
	restart_button.pressed.connect(restart_game)
	settings_button.pressed.connect(_on_settings_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	
	yes_button.pressed.connect(_on_confirm_yes)
	no_button.pressed.connect(_on_confirm_no)
	
	# Set up volume slider defaults
	_init_volume_sliders()

func _init_volume_sliders() -> void:
	master_slider.value = Audio.get_bus_volume("Master")
	music_slider.value = Audio.get_bus_volume("Music")
	sfx_slider.value = Audio.get_bus_volume("SFX")
	
	master_slider.value_changed.connect(func(val): Audio.set_bus_volume("Master", val))
	music_slider.value_changed.connect(func(val): Audio.set_bus_volume("Music", val))
	sfx_slider.value_changed.connect(func(val): Audio.set_bus_volume("SFX", val))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		var hud = get_tree().current_scene.get_node_or_null("HUD")
		if hud and hud.has_node("GameOverPanel") and hud.get_node("GameOverPanel").visible:
			return
			
		if visible:
			if confirm_overlay.visible:
				_on_confirm_no()
			elif settings_overlay.visible:
				_on_settings_back_pressed()
			else:
				resume_game()
		else:
			pause_game()

func pause_game() -> void:
	var player = get_tree().current_scene.get_node_or_null("Car")
	if not player:
		player = get_tree().current_scene.get_node_or_null("Motorcycle")
	if player and player.get("is_busted"):
		return
		
	get_tree().paused = true
	visible = true
	confirm_overlay.visible = false
	settings_overlay.visible = false
	pause_container.visible = true
	resume_button.grab_focus()

func resume_game() -> void:
	get_tree().paused = false
	visible = false

func restart_game() -> void:
	get_tree().paused = false
	visible = false
	
	var player = get_tree().current_scene.get_node_or_null("Car")
	if not player:
		player = get_tree().current_scene.get_node_or_null("Motorcycle")
	if player and player.has_method("reset_game"):
		player.call("reset_game")
	else:
		get_tree().reload_current_scene()

func _on_settings_pressed() -> void:
	pause_container.visible = false
	settings_overlay.visible = true
	settings_back_button.grab_focus()

func _on_settings_back_pressed() -> void:
	settings_overlay.visible = false
	pause_container.visible = true
	settings_button.grab_focus()

func _on_menu_pressed() -> void:
	_pending_action = "menu"
	confirm_prompt.text = "BABALIK SA MENU?"
	pause_container.visible = false
	confirm_overlay.visible = true
	no_button.grab_focus()

func _on_quit_pressed() -> void:
	_pending_action = "quit"
	confirm_prompt.text = "SIGURADO KA BA?"
	pause_container.visible = false
	confirm_overlay.visible = true
	no_button.grab_focus()

func _on_confirm_yes() -> void:
	get_tree().paused = false
	if _pending_action == "menu":
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	elif _pending_action == "quit":
		get_tree().quit()

func _on_confirm_no() -> void:
	confirm_overlay.visible = false
	pause_container.visible = true
	if _pending_action == "menu":
		menu_button.grab_focus()
	elif _pending_action == "quit":
		quit_button.grab_focus()
	_pending_action = ""
