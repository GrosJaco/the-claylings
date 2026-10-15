extends State

# ========== VARIABLES ==========

var target_position: Vector2 = Vector2.ZERO

# ========== FUNCTIONS ==========

func enter(msg := {}) -> void:
	target_position = msg.get("target_position", clayling.global_position)
	clayling.move_to(target_position)

func update(_delta: float) -> void:
	var dist = clayling.global_position.distance_to(target_position)
	if dist <= 12.0 or clayling.agent.is_navigation_finished():
		clayling.stop_moving()
		clayling.change_state("Idle")

func exit() -> void:
	clayling.stop_moving()
