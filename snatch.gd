extends Node3D

# --- FUEL ECONOMY VARIABLES ---
@export var max_fuel: float = 100.0
@export var base_fuel_drain: float = 6.0 # Fuel lost per second
@export var nitro_multiplier: float = 2.0 # 2x drain when Nitro is active

var current_fuel: float = 100.0
var is_nitro_active: bool = false
var is_busted: bool = false

# --- QTE & SNATCH VARIABLES ---
@export var snatch_fuel_reward: float = 35.0
@export var stumble_penalty_time: float = 2.0

var active_pedestrian: Area3D = null
var is_in_qte_window: bool = false
var is_stumbling: bool = false
var qte_timer: float = 0.0
var qte_duration: float = 0.6 # Player has 0.6 seconds to hit Spacebar

@onready var snatch_zone: Area3D = $SnatchZone # Link your SnatchZone node here!

func _ready() -> void:
	current_fuel = max_fuel
	# Connect the entry/exit signals from our SnatchZone
	snatch_zone.area_entered.connect(_on_snatch_zone_entered)
	snatch_zone.area_exited.connect(_on_snatch_zone_exited)

func _process(delta: float) -> void:
	if is_busted:
		return
		
	# 1. FUEL DRAIN SYSTEM
	var current_drain = base_fuel_drain * (nitro_multiplier if is_nitro_active else 1.0)
	current_fuel -= current_drain * delta
	
	if current_fuel <= 0.0:
		trigger_busted_sequence()
		return
		
	# 2. QTE TIMING WINDOW TRACKER
	if is_in_qte_window and not is_stumbling:
		qte_timer += delta
		
		# Listen for the Snatch button (Map "snatch_action" to Spacebar in Input Map!)
		if Input.is_action_just_pressed("snatch_action"):
			evaluate_snatch_attempt()
			
		# If timer expires before they press the button, it's a missed opportunity
		if qte_timer >= qte_duration:
			miss_snatch("TOO LATE!")

# --- SIGNAL HANDLERS ---
func _on_snatch_zone_entered(area: Area3D) -> void:
	if is_stumbling or is_busted:
		return
	# Pedestrian entered range! Start the QTE timer!
	active_pedestrian = area
	is_in_qte_window = true
	qte_timer = 0.0
	print("QTE STARTED - PRESS SPACE!")

func _on_snatch_zone_exited(area: Area3D) -> void:
	if area == active_pedestrian:
		# If they exit the box and we didn't press anything, reset
		is_in_qte_window = false
		active_pedestrian = null

# --- QTE EVALUATION LOGIC ---
func evaluate_snatch_attempt() -> void:
	is_in_qte_window = false # Consume the press
	
	# Calculate how close to the dead-center (0.5 of duration) the press was
	var accuracy = abs((qte_duration / 2.0) - qte_timer)
	
	if accuracy <= 0.12:
		# PERFECT SNATCH! Hit right in the center!
		print("PERFECT SNATCH! +Max Fuel & Score!")
		refuel(snatch_fuel_reward * 1.2)
		successful_snatch_cleanup()
	elif accuracy <= 0.3:
		# GOOD SNATCH! Slightly early/late but grabbed it!
		print("GOOD SNATCH! +Fuel!")
		refuel(snatch_fuel_reward)
		successful_snatch_cleanup()
	else:
		# BAD TIMING! Misfire!
		miss_snatch("MISSED TIMING!")

func successful_snatch_cleanup() -> void:
	if active_pedestrian:
		# Play coin/bag grab sound, trigger pedestrian reaction, then delete them
		active_pedestrian.queue_free()
		active_pedestrian = null

func miss_snatch(reason: String) -> void:
	print("SNATCH FAILED: ", reason, " - STUMBLE PENALTY ACTIVE!")
	is_in_qte_window = false
	is_stumbling = true
	
	# Trigger your Character Artist's stumble animation here!
	
	# Lock out the snatch mechanic for 2 seconds
	await get_tree().create_timer(stumble_penalty_time).timeout
	is_stumbling = false
	print("RECOVERED FROM STUMBLE - SNATCH READY!")

func refuel(amount: float) -> void:
	current_fuel = min(current_fuel + amount, max_fuel)

func trigger_busted_sequence() -> void:
	is_busted = true
	current_fuel = 0.0
	print("OUT OF GAS - BUSTED! GAME OVER!")
	Global.road_speed = 0.0 # Sputter and halt!
