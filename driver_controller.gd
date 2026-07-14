extends CharacterBody3D

@export var steer_speed: float = 8.0
@export var x_limit: float = 4.0
@export var max_steer_angle: float = 25.0 
@export var wheel_spin_speed: float = 18.0 
# Drag your FuelGauge node into this slot in the Inspector!
@export var fuel_gauge: ProgressBar

# ==========================================
# --- CRASH & FUEL PENALTY VARIABLES ---
# ==========================================
@export var crash_fuel_penalty: float = 20.0 # How much gas is instantly lost on impact
@export var invincibility_duration: float = 1.5 # Seconds of safety after a crash
var is_invincible: bool = false

@export var camera: Camera3D 
@export var shake_decay: float = 6.0 
var current_shake_strength: float = 0.0
var is_recovering: bool = false

@export var fork: Node3D 
@export var wheel_f: Node3D
@export var wheel_r: Node3D


# --- ADD THIS VARIABLE TO YOUR QTE SECTION ---
var current_required_action: String = ""
var all_qte_actions: Array[String] = ["ui_up", "ui_down", "ui_left", "ui_right"]
# ==========================================
# --- QTE & FUEL ECONOMY VARIABLES ---
# ==========================================
@export var max_fuel: float = 100.0
@export var base_fuel_drain: float = 6.0 # Fuel lost per second
@export var nitro_multiplier: float = 2.0 # 2x drain when Nitro is active

var current_fuel: float = 100.0
var is_nitro_active: bool = false
var is_busted: bool = false

@export var snatch_fuel_reward: float = 35.0
@export var stumble_penalty_time: float = 2.0

var active_pedestrian: Area3D = null
var is_in_qte_window: bool = false
var is_stumbling: bool = false
var qte_timer: float = 0.0
var qte_duration: float = 0.6 # Player has 0.6 seconds to hit Spacebar

# Make sure your Area3D is exactly named "SnatchZone" in the scene tree!
@onready var snatch_zone: Area3D = $SnatchZone 

func _ready() -> void:
	current_fuel = max_fuel
	# Connect the SnatchZone signals automatically via code
	if snatch_zone:
		snatch_zone.area_entered.connect(_on_snatch_zone_entered)
		snatch_zone.area_exited.connect(_on_snatch_zone_exited)

func _physics_process(delta: float) -> void:
	# ------------------------------------------
	# FUEL DRAIN & QTE TRACKER
	# ------------------------------------------
	if not is_busted:
		var current_drain = base_fuel_drain * (nitro_multiplier if is_nitro_active else 1.0)
		current_fuel -= current_drain * delta
		
		# --- ADD THIS LINE TO UPDATE THE UI ---
		if fuel_gauge:
			fuel_gauge.value = current_fuel
			
		if current_fuel <= 0.0:
			trigger_busted_sequence()
			


	# ------------------------------------------
	# MOTORCYCLE MOVEMENT (Disabled if busted!)
	# ------------------------------------------
	var input_dir := 0.0
	
	if not is_busted:
		if Input.is_action_pressed("steer_left"):
			input_dir -= 1.0
		if Input.is_action_pressed("steer_right"):
			input_dir += 1.0
		
	# 1. LATERAL MOVEMENT
	velocity.x = input_dir * steer_speed
	velocity.z = 0.0
	move_and_slide()
	
	if position.x < -x_limit:
		position.x = -x_limit
		velocity.x = 0.0
	elif position.x > x_limit:
		position.x = x_limit
		velocity.x = 0.0
		
	if not is_busted and is_in_qte_window and not is_stumbling:
		qte_timer += delta
		
		# Check if the user pressed ANY of the 4 directional keys
		for action in all_qte_actions:
			if Input.is_action_just_pressed(action):
				if action == current_required_action:
					# CORRECT KEY PRESSED! Evaluate timing accuracy!
					evaluate_snatch_attempt()
				else:
					# WRONG KEY PRESSED! Instant punishment!
					miss_snatch("WRONG ARROW KEY!")
				break # Stop checking other keys this frame
				
		if qte_timer >= qte_duration:
			miss_snatch("TOO LATE!")

	# 2. HANDLEBAR STEERING
	var target_steer = -input_dir * max_steer_angle
	if fork:
		fork.rotation_degrees.z = lerp(fork.rotation_degrees.z, target_steer, 5.0 * delta)

	# 3. CHASSIS TILT
	rotation_degrees.z = lerp(rotation_degrees.z, -input_dir * 15.0, 10.0 * delta)

	# 4. SPIN THE WHEELS (Slows down to a stop if busted)
	var current_spin = wheel_spin_speed if not is_busted else 0.0
	if wheel_f:
		wheel_f.rotation_degrees.y -= current_spin * 360.0 * delta
	if wheel_r:
		wheel_r.rotation_degrees.y -= current_spin * 360.0 * delta

	# --- ARCADE SCREEN SHAKE JUICE ---
	if current_shake_strength > 0.0:
		current_shake_strength = lerpf(current_shake_strength, 0.0, shake_decay * delta)
		if camera:
			camera.h_offset = randf_range(-current_shake_strength, current_shake_strength)
			camera.v_offset = randf_range(-current_shake_strength, current_shake_strength)
	elif camera and (camera.h_offset != 0.0 or camera.v_offset != 0.0):
		camera.h_offset = 0.0
		camera.v_offset = 0.0

# ==========================================
# --- COLLISION & DAMAGE ---
# ==========================================
func _on_hurtbox_area_entered(area: Area3D) -> void:
	if area.name.contains("ObstacleCar") or area.is_in_group("obstacles"):
		take_crash_penalty()
		area.queue_free() 

func apply_screen_shake(strength: float = 0.4) -> void:
	current_shake_strength = strength

func take_crash_penalty() -> void:
	# Ignore hits if we are already out of gas or currently invincible!
	if is_busted or is_invincible:
		return
		
	print("CRASH DEBRIS! Lost ", crash_fuel_penalty, " Fuel!")
	
	# 1. INSTANT FUEL DEDUCTION
	current_fuel -= crash_fuel_penalty

	
	# 2. HEAVY SCREEN SHAKE JUICE
	apply_screen_shake(0.5) 
	
	# 3. CHECK FOR INSTANT GAME OVER
	if current_fuel <= 0.0:
		trigger_busted_sequence()
		fuel_gauge.value = 0
		return
		
	# 4. TRIGGER MERCY INVINCIBILITY & SPEED PENALTY
	start_crash_recovery()

func start_crash_recovery() -> void:
	is_invincible = true
	
	# Temporary rubberbanding slowdown penalty
	Global.road_speed -= 4.0
	
	# Wait for the safety window to expire
	await get_tree().create_timer(invincibility_duration).timeout
	
	# Restore highway speed and vulnerability
	Global.road_speed += 4.0
	is_invincible = false
	print("RECOVERED - Vulnerable to impacts again!")
# ==========================================
# --- QTE SNATCH LOGIC ---
# ==========================================
func _on_snatch_zone_entered(area: Area3D) -> void:
	if is_stumbling or is_busted:
		return
	active_pedestrian = area
	is_in_qte_window = true
	qte_timer = 0.0
	
	# GRAB THE PEDESTRIAN'S RANDOM REQUIRED ARROW KEY!
	if area.get("required_action") != null:
		current_required_action = area.required_action
		print("QTE STARTED - PRESS: ", current_required_action)

func _on_snatch_zone_exited(area: Area3D) -> void:
	if area == active_pedestrian:
		is_in_qte_window = false
		active_pedestrian = null
		current_required_action = ""

func evaluate_snatch_attempt() -> void:
	is_in_qte_window = false 
	var accuracy = abs((qte_duration / 2.0) - qte_timer)
	
	if accuracy <= 0.12:
		print("PERFECT SNATCH! +Max Fuel & Score!")
		refuel(snatch_fuel_reward * 1.2)
		successful_snatch_cleanup()
	elif accuracy <= 0.3:
		print("GOOD SNATCH! +Fuel!")
		refuel(snatch_fuel_reward)
		successful_snatch_cleanup()
	else:
		miss_snatch("MISSED TIMING!")

func successful_snatch_cleanup() -> void:
	if active_pedestrian:
		active_pedestrian.queue_free()
		active_pedestrian = null

func miss_snatch(reason: String) -> void:
	print("SNATCH FAILED: ", reason, " - STUMBLE PENALTY ACTIVE!")
	is_in_qte_window = false
	is_stumbling = true
	
	# Lock out the snatch mechanic for 2 seconds
	await get_tree().create_timer(stumble_penalty_time).timeout
	is_stumbling = false
	print("RECOVERED FROM STUMBLE - SNATCH READY!")

func refuel(amount: float) -> void:
	current_fuel = min(current_fuel + amount, max_fuel)

func trigger_busted_sequence() -> void:
	is_busted = true
	current_fuel = 0.0
	print("GAME OVER - BUSTED!")
	apply_screen_shake(0.8) 
	
	# Stop the world from moving (uncomment if you have Global set up!)
	# Global.road_speed = 0.0
