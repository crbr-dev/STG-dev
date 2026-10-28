extends "res://scripts/enemy_patterns.gd"

func move_enemy(enemy: Dictionary, dt: float) -> void:
	if enemy.ground: return
	match String(enemy.kind):
		"drone":
			enemy.p.y += enemy.speed * dt
			enemy.p.x = clampf(enemy.origin_x + sin(enemy.age * 1.7 + enemy.variant) * 62, 45, 915)
		"gunship", "rocket", "hoverboat":
			var holding: bool = enemy.age > 1.8 and enemy.age < (6.4 if enemy.kind == "gunship" else 7.6)
			enemy.p.y += dt * (20 if holding else enemy.speed)
			enemy.p.x = clampf(enemy.origin_x + sin(enemy.age * 0.7 + enemy.variant) * 75, 90, 870)
		"midboss":
			enemy.p.x = 480 + sin(enemy.age * 0.58) * 150
			enemy.p.y = move_toward(enemy.p.y, 255 + sin(enemy.age * 0.4) * 55, dt * enemy.speed)
			if enemy.age > 23: enemy.p.y += dt * 120
		"boss":
			enemy.p.y = move_toward(enemy.p.y, 278 + sin(enemy.age * 0.33) * 20, dt * 145)
			enemy.p.x = 480 + sin(enemy.age * 0.38) * (60 if enemy.get("nose_broken", false) else 30)

func fire(enemy: Dictionary) -> void:
	if not _alive(enemy): return
	enemy.pattern = int(enemy.pattern) + 1
	match String(enemy.kind):
		"soldier": _soldier(enemy)
		"tank": _quay_tank(enemy)
		"drone": _scout(enemy)
		"gunship": _twin_gunship(enemy)
		"rocket": _rocket_skiff(enemy)
		"hoverboat": _pink_barge(enemy)
		"midboss": _heavy_tank(enemy)
		"boss": _dreadnought(enemy)

func _quay_tank(enemy: Dictionary) -> void:
	var port := Vector2(0, 35)
	var aimed := _aim(enemy, port)
	_cue(enemy, port, Color("c9ffff"), 0.2)
	for beat in range(3):
		for lane in [-1, 1]:
			_queue(enemy, 0.17 + beat * 0.12, port + Vector2(lane * 9, 0), aimed + lane * 0.035, 330 + beat * 28, 0, "drop", 0.86)
	enemy.shot = 1.85

func _scout(enemy: Dictionary) -> void:
	var aimed := _aim(enemy, Vector2(0, 30))
	_cue(enemy, Vector2(0, 30), Color("b2f9ff"), 0.14)
	for beat in range(3):
		_queue(enemy, 0.12 + beat * 0.075, Vector2(0, 30), aimed + sin(enemy.pattern + beat * 0.4) * 0.025, 365 + beat * 23, 0, "drop", 0.8)
	enemy.shot = 1.65 + int(enemy.variant) % 3 * 0.13

func _twin_gunship(enemy: Dictionary) -> void:
	for side in [-1, 1]:
		var port := _gunship_port(enemy, side)
		var aimed := _aim(enemy, port)
		var delay := 0.18 if side == -1 else 0.32
		_cue(enemy, port, Color("a7efff"), 0.18, false, delay - 0.16)
		cues.back()["muzzle"] = "gun_left" if side == -1 else "gun_right"
		for beat in range(4):
			for lane in range(-1, 2):
				_queue(enemy, delay + beat * 0.07, port, aimed + lane * 0.10 + side * beat * 0.012, 310 + beat * 18, 0, "bead", 0.84)
				pending.back()["muzzle"] = "gun_left" if side == -1 else "gun_right"
	enemy.shot = 1.92

func _gunship_port(enemy: Dictionary, side: int) -> Vector2:
	var fps: float = stage.art.get("gunship", {}).get("fps", 8.0)
	var frame := int(animation_time(enemy, "gunship") * fps) % 4

	if side == 1:
		return [Vector2(-25.0, 72.1), Vector2(-25.0, 72.1), Vector2(-20.4, 65.7), Vector2(-23.6, 72.1)][frame]
	return [Vector2(-30.2, 67.5), Vector2(-30.2, 67.5), Vector2(-25.0, 61.2), Vector2(-28.5, 67.9)][frame]

func _emitter_position(emission: Dictionary) -> Vector2:
	if emission.has("muzzle"):
		match String(emission.muzzle):
			"gun_left", "gun_right": return emission.owner.p + _gunship_port(emission.owner, -1 if emission.muzzle == "gun_left" else 1)
			"heavy_main": return emission.owner.p + _heavy_port(emission.owner)
	return super._emitter_position(emission)

func _rocket_skiff(enemy: Dictionary) -> void:
	for barrel in range(2):
		var side := -1 if barrel == 0 else 1
		var port := Vector2(36, 73) if barrel == 0 else Vector2(58, 57)
		var aimed := _aim(enemy, port)
		_cue(enemy, port, Color("ffb9f4"), 0.2, false, barrel * 0.12)
		for beat in range(5):
			_queue(enemy, 0.18 + beat * 0.06 + barrel * 0.12, port, aimed + side * (0.10 + beat * 0.012), 375 + beat * 12, 1, "needle", 0.87)
	enemy.shot = 1.74

func _pink_barge(enemy: Dictionary) -> void:
	var aimed := _aim(enemy, Vector2(0, 85))
	for side in [-1, 1]:
		var port := Vector2(-43, 102) if side == -1 else Vector2(41, 102)
		_cue(enemy, port, Color("ffb7ea"), 0.26, false, (side + 1) * 0.08)
		for beat in range(3):
			for lane in range(7):
				_queue(enemy, 0.22 + beat * 0.12 + (side + 1) * 0.08, port, aimed + (lane - 3) * 0.13 + side * 0.17, 240 + beat * 36, 1, "bead", 0.94)
	if int(enemy.pattern) % 2 == 0:
		for side in [-1, 1]:
			var port := Vector2(-52, 86) if side == -1 else Vector2(50, 86)
			for beat in range(3): _queue(enemy, 0.65 + beat * 0.06, port, aimed + side * 0.03, 430 + beat * 10, 0, "drop", 0.9)
	enemy.shot = 1.8

func _heavy_tank(enemy: Dictionary) -> void:
	var port := _heavy_port(enemy)
	var aimed := _aim(enemy, port)
	_cue(enemy, port, Color("ffb8e8"), 0.27)
	cues.back()["muzzle"] = "heavy_main"
	for beat in range(3):
		for lane in range(-2, 3):
			_queue(enemy, 0.24 + beat * 0.1, port, aimed + lane * 0.13, 285 + beat * 27, 1, "bead", 0.9)
			pending.back()["muzzle"] = "heavy_main"
	for side in [-1, 1]:
		var side_port := Vector2(-48, 60) if side == -1 else Vector2(47, 60)
		_cue(enemy, side_port, Color("c4fbff"), 0.2, false, 0.65)
		for lane in range(8):
			_queue(enemy, 0.82 + lane * 0.024, side_port, aimed + (lane - 3.5) * 0.17 + side * 0.16, 310, 0, "drop", 0.9)
	enemy.shot = 2.15

func _heavy_port(enemy: Dictionary) -> Vector2:
	var fps: float = stage.art.get("midboss", {}).get("fps", 8.0)
	var frame := int(animation_time(enemy, "midboss") * fps) % 4
	return Vector2(0, [79, 125, 48, 125][frame])

func _dreadnought(enemy: Dictionary) -> void:
	var late: bool = enemy.get("nose_broken", false)
	var cycle := 0 if enemy.age < 19 else (1 if enemy.age < 27 else 2)
	var aim := _aim(enemy, Vector2(0, 130))

	for side in [-1, 1]:
		var port := Vector2(side * 85, 18) if cycle == 0 else Vector2(side * 78, 117)
		var delay: float = 0.2 + (side + 1) * 0.095
		_cue(enemy, port, Color("b3f7ff") if cycle != 2 else Color("ffb4ea"), 0.24, false, delay - 0.18)
		if cycle == 0:
			for beat in range(6):
				for lane in range(-1, 2):
					_queue(enemy, delay + beat * 0.07, port, aim + side * (0.12 + beat * beat * 0.014) + lane * 0.29, 270 + beat * 14, 0, "drop", 0.86)
		elif cycle == 1:
			for spoke in range(7):
				for bead in range(4):
					_queue(enemy, delay + bead * 0.09 + spoke * 0.018, port, aim + (spoke - 3) * 0.20 + side * sin(bead * 0.45) * 0.22, 250 + bead * 24, 1, "bead", 0.92)
		else:
			for beat in range(5):
				for lane in [-1, 1]:
					_queue(enemy, delay + beat * 0.10, port, aim + side * 0.25 + lane * (0.12 + beat * 0.025) + sin(enemy.pattern * 0.7) * 0.14, 320 + beat * 16, 1, "needle", 0.9)
			for lane in range(-2, 3): _queue(enemy, delay + 0.65, port, aim + lane * 0.19, 270, 0, "bead", 0.7)
	var nose := Vector2(0, 140)
	_cue(enemy, nose, Color("ffb4e7"), 0.32, true, 0.3)
	for beat in range(6 if late else 4):
		for lane in [-1, 1]:
			_queue(enemy, 0.6 + beat * 0.11, nose + Vector2(lane * 10, 0), aim + lane * (0.12 + beat * 0.018 if cycle == 2 else 0.035) + sin(enemy.pattern * 0.5) * 0.09, 370 + beat * 17, 1, "needle" if cycle == 2 else "bead", 0.91)
	if late and int(enemy.pattern) % 2 == 0:
		for side in [-1, 1]:
			for spoke in range(13):
				for bead in range(2):
					_queue(enemy, 1.1 + bead * 0.1, Vector2(side * 158, 88), PI * 0.12 + spoke * PI * 0.76 / 12, 230 + bead * 60, 0, "bead", 0.85)
	enemy.shot = 1.95 if late else 2.35
