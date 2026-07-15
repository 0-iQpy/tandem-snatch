extends Area3D

@export var swerve_speed: float = 8.0 # How fast the cop slides across 1 lane
@export var lane_width: float = 1.0 # Approximate width of 1 road lane in meters (Adjust in Inspector!)
@export var swerve_trigger_z: float = -10.0 # Closer to 0.0 = waits longer before swerving!
@export var max_tilt_angle: float = 20.0

var is_incoming: bool = false
var player_ref: Node3D = null

# --- NEW: State Machine Variables ---
var has_triggered_swerve: bool = false
var target_x: float = 0.0

func _ready() -> void:
	add_to_group("obstacles")
	add_to_group("police")
	
	player_ref = get_tree().get_first_node_in_group("player")
	# Lock initial target_x to wherever the police car spawned
	target_x = global_position.x

func set_incoming(incoming_flag: bool) -> void:
	is_incoming = incoming_flag

func _process(delta: float) -> void:
	# 1. FORWARD MOVEMENT
	global_position.z += (Global.road_speed * 2.0) * delta
	
	# ==========================================
	# 2. THE ONE-TIME TACTICAL SWERVE DECISION
	# ==========================================
	if not has_triggered_swerve and player_ref and is_instance_valid(player_ref):
		# Wait until the car is close enough to the player (e.g., crosses Z = -35)
		if global_position.z > swerve_trigger_z:
			has_triggered_swerve = true
			
			# Check horizontal distance between cop and motorcycle
			var x_diff = player_ref.global_position.x - global_position.x
			
			# Only swerve if the player is in a different lane (more than 0.5m away)
			if abs(x_diff) > 0.5:
				# If x_diff is positive, player is to our RIGHT. If negative, to our LEFT.
				var direction = 1.0 if x_diff > 0 else -1.0
				
				# Lock the target to EXACTLY one lane width over!
				target_x = global_position.x + (direction * lane_width)
				
				print("🚨 TACTICAL SWERVE TRIGGERED! Moving 1 lane to the ", "RIGHT" if direction > 0 else "LEFT")

	# ==========================================
	# 3. EXECUTE THE SWERVE (Fixed Target)
	# ==========================================
	if has_triggered_swerve:
		var old_x = global_position.x
		
		# Move towards the locked target_x at a constant speed
		global_position.x = move_toward(global_position.x, target_x, swerve_speed * delta)
		
		# Visual body tilt based on actual movement
		var actual_x_vel = (global_position.x - old_x) / delta
		var target_tilt = clampf(-actual_x_vel * 2.0, -max_tilt_angle, max_tilt_angle)
		
		var base_rot = 0.0 if is_incoming else 180.0
		rotation_degrees.y = lerpf(rotation_degrees.y, base_rot + target_tilt, 10.0 * delta)
	else:
		# Before swerving, keep the police car driving perfectly straight
		var base_rot = 0.0 if is_incoming else 180.0
		rotation_degrees.y = base_rot
		
	# 4. CLEANUP
	if global_position.z > 12.0 or global_position.z < -100.0:
		queue_free()
