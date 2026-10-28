extends "res://scripts/enemy_patterns.gd"

func fire(enemy: Dictionary) -> void:
	if not _alive(enemy): return
	enemy.pattern = int(enemy.pattern) + 1
	match String(enemy.kind):
		"soldier": _soldier(enemy)
		"esper": _casino_esper(enemy)
		"drone": _casino_drone(enemy)
		"tank": _casino_turret(enemy)
		"midboss": _hover_barge(enemy)
		"boss": _fortress(enemy)

func _casino_esper(enemy: Dictionary) -> void:
	var angle := _aim(enemy, Vector2(0, 18))
	var direction := -1.0 if int(enemy.variant) % 2 == 0 else 1.0
	_cue(enemy, Vector2(0, 18), Color("f2b3ff"), 0.24)
	for pulse in range(2):
		for lane in range(-1, 2):
			_queue(enemy, 0.20 + pulse * 0.095, Vector2(direction * 11, 18), angle + lane * 0.13 + direction * pulse * 0.035, 285 + pulse * 32, 1, "bead", 0.78)
	enemy.shot = 1.72 + 0.16 * (int(enemy.variant) % 4)

func _casino_drone(enemy: Dictionary) -> void:
	var angle := _aim(enemy, Vector2(0, 16))
	for wing in [-1, 1]:
		var origin := Vector2(wing * 14, 16)
		_cue(enemy, origin, Color("b8f9ff"), 0.12, false, 0.035 * (wing + 1))
		for shot in range(2):
			_queue(enemy, 0.10 + shot * 0.065 + 0.035 * (wing + 1), origin, angle + wing * 0.11, 380 + shot * 30, 0, "drop", 0.82)
	enemy.shot = 1.43 + 0.13 * (int(enemy.variant) % 4)

func _casino_turret(enemy: Dictionary) -> void:
	var angle := _aim(enemy, Vector2(0, 26))
	var pink := int(enemy.variant) % 3 == 2
	_cue(enemy, Vector2(0, 20), Color("f2b5ff") if pink else Color("b3f7ff"), 0.18)
	for shot in range(3):
		for barrel in range(2):
			var side := -1.0 if barrel == 0 else 1.0
			_queue(enemy, 0.15 + shot * 0.075 + barrel * 0.035, Vector2(side * 15, 26), angle + side * 0.055 + shot * side * 0.018, 345 + shot * 25, 1 if pink else 0, "bead" if pink else "drop", 0.95)
	enemy.shot = 1.68 + 0.11 * ((int(enemy.pattern) + int(enemy.variant)) % 4)

func _hover_barge(enemy: Dictionary) -> void:

	var target_angle := _aim(enemy, Vector2(0, 140))
	var centered := lerpf(PI * 0.5, target_angle, 0.32)
	var speeds := [527.0, 447.0, 380.0, 295.0]
	for pod in range(2):
		var side := -1.0 if pod == 0 else 1.0
		var origin := Vector2(side * 90, 140)
		var delay := 0.18 + pod * 0.10
		_cue(enemy, origin, Color("ffb9d8"), 0.22, false, pod * 0.1)
		for lane in range(3):
			for bead in range(4):
				var angle := centered + side * (0.53 + sin(enemy.pattern * 0.4) * 0.08) + (lane - 1) * 0.12
				_queue(enemy, delay + bead * 0.022, origin, angle, speeds[bead], 1, "bead", 0.96)
	if int(enemy.pattern) % 3 == 0:
		_cue(enemy, Vector2(0, 120), Color("a8f4ff"), 0.16, false, 0.40)
		for lane in range(-2, 3):
			_queue(enemy, 0.54, Vector2(0, 120), target_angle + lane * 0.11, 315, 0, "drop", 0.9)
	enemy.shot = 1.22 + 0.12 * (int(enemy.variant) % 2)

func _fortress(enemy: Dictionary) -> void:

	var pods_destroyed: bool = not enemy.get("left_alive", true) and not enemy.get("right_alive", true)
	var late_phase := pods_destroyed or float(enemy.age) >= 23.0 or float(enemy.hp) / float(enemy.max_hp) < 0.43
	if late_phase: _fortress_unfolded(enemy)
	else: _fortress_armored(enemy)

func _fortress_armored(enemy: Dictionary) -> void:
	var angle := _aim(enemy, Vector2(0, 101))
	_pod_quads(enemy)
	for lane in [-1, 1]:
		var muzzle := "core_left" if lane == -1 else "core_right"
		var port := _core_port(enemy, muzzle)
		_cue(enemy, port, Color("ffd3e3"), 0.23)
		cues.back()["muzzle"] = muzzle
		for bead in range(10):
			_queue(enemy, 0.22 + bead * 0.052, port, angle + lane * 0.024 + sin(enemy.pattern * 0.6) * 0.04, 398 + bead * 3, 1, "bead", 1.02)
			pending.back()["muzzle"] = muzzle
	enemy.shot = 1.30 + (int(enemy.pattern) % 2) * 0.11

func _pod_quads(enemy: Dictionary, wave_count: int = 3, extra_delay: float = 0.0) -> void:
	for pod in range(2):
		var part := "left" if pod == 0 else "right"
		if not enemy.get(part + "_alive", true): continue
		var side := -1.0 if pod == 0 else 1.0
		var port := Vector2(side * 254, 98)
		_cue(enemy, port, Color("ffb6f5"), 0.2, false, extra_delay + pod * 0.12)
		cues.back()["part"] = part
		for group in range(wave_count):

			for corner in [Vector2(-10, -10), Vector2(10, -10), Vector2(-10, 10), Vector2(10, 10)]:
				var previous_count := pending.size()
				_queue(enemy, extra_delay + 0.18 + pod * 0.12 + group * 0.20, port + corner, PI * 0.5 + side * 0.18 + sin(enemy.pattern * 0.65) * 0.12, 300, 1, "bead", 0.82)
				if pending.size() > previous_count: pending.back()["part"] = part

func _fortress_unfolded(enemy: Dictionary) -> void:
	var angle := _aim(enemy, Vector2(0, 80))
	var ports := [Vector2(-102, -32), _core_port(enemy, "core_left"), _core_port(enemy, "core_right"), Vector2(102, -32)]
	for arm in range(4):
		var port: Vector2 = ports[arm]
		var delay := 0.18 + arm * 0.045
		_cue(enemy, port, Color("b0faff"), 0.18, false, arm * 0.045)
		if arm in [1, 2]: cues.back()["muzzle"] = "core_left" if arm == 1 else "core_right"
		for lane in [-1, 1]:
			for bead in range(4):
				_queue(enemy, delay + bead * 0.065, port, angle + (arm - 1.5) * 0.17 + lane * 0.045, 285 + bead * 28, 0, "bead", 0.85)
				if arm in [1, 2]: pending.back()["muzzle"] = "core_left" if arm == 1 else "core_right"
	var crown := Vector2(0, -137)
	_cue(enemy, crown, Color("9ffaff"), 0.32, true)
	for wave in range(3):
		for spoke in range(15):
			var direction := -0.12 + spoke * (PI + 0.24) / 14.0 + sin(enemy.pattern * 0.55) * 0.20
			_queue(enemy, 0.30 + wave * 0.075 + (spoke % 2) * 0.018, crown, direction, 235 + wave * 54, 0, "bead", 0.93)
	if int(enemy.pattern) % 3 == 0:
		for side in [-1, 1]:
			for bead in range(4):
				_queue(enemy, 0.56 + bead * 0.09, Vector2(side * 135, 30), angle + side * 0.35, 350, 1, "bead", 0.95)
	_pod_quads(enemy, 1, 0.45)
	enemy.shot = 1.08 + (int(enemy.pattern) % 2) * 0.10

func _core_port(enemy: Dictionary, muzzle: String) -> Vector2:
	var frame := int(animation_time(enemy, "boss_core") * 8) % 4
	var left := muzzle == "core_left"
	if frame == 1: return Vector2(-47 if left else 40, 150)
	if frame == 2: return Vector2(-41 if left else 44, 88)
	return Vector2(-24 if left else 25, 101)

func _emitter_position(emission: Dictionary) -> Vector2:
	var muzzle: String = emission.get("muzzle", "")
	if muzzle.begins_with("core_"): return emission.owner.p + _core_port(emission.owner, muzzle)
	return super._emitter_position(emission)

func update(dt: float) -> void:

	for index in range(pending.size() - 1, -1, -1):
		var part: String = pending[index].get("part", "")
		if not part.is_empty() and not pending[index].owner.get(part + "_alive", true): pending.remove_at(index)
	for index in range(cues.size() - 1, -1, -1):
		var part: String = cues[index].get("part", "")
		if not part.is_empty() and not cues[index].owner.get(part + "_alive", true): cues.remove_at(index)
	super.update(dt)
