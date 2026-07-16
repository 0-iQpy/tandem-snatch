extends Control

# --- Node References ---
@onready var main_buttons_container = $MarginContainer/MenuLayout/CenterContainer/MainButtons
@onready var play_button = $MarginContainer/MenuLayout/CenterContainer/MainButtons/PlayButton
@onready var controls_button = $MarginContainer/MenuLayout/CenterContainer/MainButtons/ControlsButton
@onready var settings_button = $MarginContainer/MenuLayout/CenterContainer/MainButtons/SettingsButton
@onready var credits_button = $MarginContainer/MenuLayout/CenterContainer/MainButtons/CreditsButton
@onready var quit_button = $MarginContainer/MenuLayout/CenterContainer/MainButtons/QuitButton

@onready var settings_overlay = $MarginContainer/MenuLayout/SettingsOverlay
@onready var master_slider = $MarginContainer/MenuLayout/SettingsOverlay/VBox/SliderGrid/MasterSlider
@onready var music_slider = $MarginContainer/MenuLayout/SettingsOverlay/VBox/SliderGrid/MusicSlider
@onready var sfx_slider = $MarginContainer/MenuLayout/SettingsOverlay/VBox/SliderGrid/SFXSlider
@onready var settings_back_button = $MarginContainer/MenuLayout/SettingsOverlay/VBox/BackButton

@onready var credits_overlay = $MarginContainer/MenuLayout/CreditsOverlay
@onready var credits_back_button = $MarginContainer/MenuLayout/CreditsOverlay/VBox/BackButton

@onready var tutorial_overlay = $MarginContainer/MenuLayout/TutorialOverlay
@onready var tutorial_back_button = $MarginContainer/MenuLayout/TutorialOverlay/VBox/BackButton

@onready var quit_confirm_overlay = $MarginContainer/MenuLayout/QuitConfirmOverlay
@onready var quit_yes_button = $MarginContainer/MenuLayout/QuitConfirmOverlay/VBox/HBox/YesButton
@onready var quit_no_button = $MarginContainer/MenuLayout/QuitConfirmOverlay/VBox/HBox/NoButton

@onready var transition_overlay = $TransitionOverlay

func _ready() -> void:
	Audio.stop_all_sfx(0.0)
	Audio.play_bgm(preload("res://assets/bgm/main_menu.mp3"))
	# Hide sub-panels by default
	settings_overlay.visible = false
	credits_overlay.visible = false
	tutorial_overlay.visible = false
	quit_confirm_overlay.visible = false
	main_buttons_container.visible = true
	
	# Transition overlay setup: start fully transparent and visible
	transition_overlay.visible = true
	transition_overlay.color.a = 0.0
	
	# Connect signals
	play_button.pressed.connect(_on_play_pressed)
	controls_button.pressed.connect(_on_controls_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	credits_back_button.pressed.connect(_on_credits_back_pressed)
	tutorial_back_button.pressed.connect(_on_tutorial_back_pressed)
	
	quit_yes_button.pressed.connect(_on_quit_confirmed)
	quit_no_button.pressed.connect(_on_quit_cancelled)
	
	# Set up volume slider defaults
	_init_volume_sliders()
	
	# Grab initial focus for keyboard control
	play_button.grab_focus()

func _init_volume_sliders() -> void:
	master_slider.value = Audio.get_bus_volume("Master")
	music_slider.value = Audio.get_bus_volume("Music")
	sfx_slider.value = Audio.get_bus_volume("SFX")
	
	master_slider.value_changed.connect(func(val): Audio.set_bus_volume("Master", val))
	music_slider.value_changed.connect(func(val): Audio.set_bus_volume("Music", val))
	sfx_slider.value_changed.connect(func(val): Audio.set_bus_volume("SFX", val))

# --- Button Handlers ---

func _on_play_pressed() -> void:
	# Block button focus inputs during transition
	play_button.release_focus()
	
	Audio.stop_bgm()
	Audio.play_bgm(preload("res://assets/bgm/main.mp3"), -20)
	# Fade-out screen transition
	var tween = create_tween()
	tween.tween_property(transition_overlay, "color:a", 1.0, 0.5)
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://main.tscn"))

func _on_controls_pressed() -> void:
	main_buttons_container.visible = false
	tutorial_overlay.visible = true
	tutorial_back_button.grab_focus()

func _on_tutorial_back_pressed() -> void:
	tutorial_overlay.visible = false
	main_buttons_container.visible = true
	controls_button.grab_focus()

func _on_settings_pressed() -> void:
	main_buttons_container.visible = false
	settings_overlay.visible = true
	settings_back_button.grab_focus()

func _on_settings_back_pressed() -> void:
	settings_overlay.visible = false
	main_buttons_container.visible = true
	settings_button.grab_focus()

func _on_credits_pressed() -> void:
	main_buttons_container.visible = false
	credits_overlay.visible = true
	credits_back_button.grab_focus()

func _on_credits_back_pressed() -> void:
	credits_overlay.visible = false
	main_buttons_container.visible = true
	credits_button.grab_focus()

func _on_quit_pressed() -> void:
	main_buttons_container.visible = false
	quit_confirm_overlay.visible = true
	quit_no_button.grab_focus()

func _on_quit_confirmed() -> void:
	get_tree().quit()

func _on_quit_cancelled() -> void:
	quit_confirm_overlay.visible = false
	main_buttons_container.visible = true
	quit_button.grab_focus()
