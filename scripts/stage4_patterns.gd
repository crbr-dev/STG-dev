extends "res://scripts/enemy_patterns.gd"

var beams: Array = []

func clear() -> void:
	super.clear()
	beams.clear()

func _actor(enemy: Dictionary) -> String:
	return "boss_open" if enemy.kind == "boss" and enemy.get("arms_open", false) and stage.art.has("boss_open") else str(enemy.kind)

func animation_time(enemy: Dictionary, actor_id: String) -> float:
	if actor_id == "armored_esper":
		for beam in beams:
			if beam.owner == enemy and beam.age >= 0 and beam.age <= beam.warmup + beam.duration:

				return 1.001 / maxf(1, float(stage.art.get(actor_id, {}).get("fps", 8)))
	return super.animation_time(enemy, actor_id)

func _port(enemy: Dictionary, name: String, fallback: Vector2) -> Vector2:
	var actor: Dictionary = stage.art.get(_actor(enemy), {})
	var ports: Dictionary = actor.get("muzzles", {})
	var value: Array = ports.get(name, [fallback.x, fallback.y])
	if value[0] is Array:
		value = value[int(animation_time(enemy, _actor(enemy)) * float(actor.get("fps", 8))) % value.size()]
	return Vector2(float(value[0]), float(value[1]))

func _shot(enemy: Dictionary, name: String, fallback: Vector2, delay: float, angle: float, speed: float, kind: int = 0, shape: String = "drop", size: float = 0.85, nudge: Vector2 = Vector2.ZERO) -> void:
	_queue(enemy, delay, _port(enemy, name, fallback) + nudge, angle, speed, kind, shape, size)
	pending.back()["muzzle"] = name
	pending.back()["fallback"] = fallback
	pending.back()["nudge"] = nudge

func _flash(enemy: Dictionary, name: String, fallback: Vector2, color: Color, delay: float = 0.0, duration: float = 0.20) -> void:
	_cue(enemy, _port(enemy, name, fallback), color, duration, false, delay)
	cues.back()["muzzle"] = name
	cues.back()["fallback"] = fallback

func _emitter_position(emission: Dictionary) -> Vector2:
	if emission.has("muzzle"):
		return emission.owner.p + _port(emission.owner, emission.muzzle, emission.fallback) + emission.get("nudge", Vector2.ZERO)
	return super._emitter_position(emission)

func _rail_center(y: float, preferred_x: float) -> Vector2:
	var nearest := Vector2.INF
	var distance := INF
	for rail in stage.rail_paths:
		var points: Array = rail.points
		for index in range(points.size() - 1):
			var a := Vector2(points[index][0], points[index][1])
			var b := Vector2(points[index + 1][0], points[index + 1][1])
			if y < minf(a.y, b.y) or y > maxf(a.y, b.y) or absf(a.y - b.y) < 1: continue
			var x := lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
			if absf(x - preferred_x) < distance:
				nearest = Vector2(x, y)
				distance = absf(x - preferred_x)
	return nearest

func rail_spawn(preferred_screen_x: float) -> Vector2:
	var desired: Vector2 = stage._screen_to_world(Vector2(preferred_screen_x, -220))
	var point := _rail_center(desired.y, desired.x)
	if point == Vector2.INF or not stage._terrain_allows(point, "rail_fortress"): return Vector2.INF
	for enemy in stage.enemies:
		if enemy.kind == "rail_fortress" and enemy.wp.distance_to(point) < 340: return Vector2.INF
	return point

func move_rail(enemy: Dictionary, dt: float) -> void:
	var point := _rail_center(enemy.wp.y + enemy.speed * dt, enemy.wp.x)
	if point != Vector2.INF and stage._terrain_allows(point, "rail_fortress"): enemy.wp = point
	enemy.p = stage._world_to_screen(enemy.wp) - Vector2(0, 20)

func move_enemy(enemy: Dictionary, dt: float) -> void:
	if enemy.ground: return
	match String(enemy.kind):
		"armored_esper":
			var speed: float = enemy.speed if enemy.age < 2 or enemy.age > 7 else 18.0
			enemy.p.y += dt * speed
			enemy.p.x = clampf(enemy.origin_x + sin(enemy.age * 1.1 + enemy.variant) * 38, 45, 915)
		"silver_scout":
			enemy.p.y += dt * enemy.speed
			enemy.p.x = clampf(enemy.origin_x + sin(enemy.age * 1.5 + enemy.variant) * 62, 55, 905)
		"orange_pod_drone", "hoverboat":
			enemy.p.y += dt * (24 if enemy.age > 2 and enemy.age < 6.5 else enemy.speed)
			enemy.p.x = enemy.origin_x + sin(enemy.age * 0.7 + enemy.variant) * 52
		"silver_interceptor":
			enemy.p.x = 480 + sin(enemy.age * 0.47) * 110
			if enemy.age < 21: enemy.p.y = move_toward(enemy.p.y, 235, dt * enemy.speed)
			else: enemy.p.y += dt * 180
		"boss":
			enemy.p.y = move_toward(enemy.p.y, 275 + sin(enemy.age * 0.3) * 24, dt * 235)
			enemy.p.x = 480 + sin(enemy.age * 0.37) * 115
			enemy["arms_open"] = enemy.age >= 55 or float(enemy.hp) / float(enemy.max_hp) < 0.44

func fire(enemy: Dictionary) -> void:
	if not _alive(enemy): return
	enemy.pattern = int(enemy.pattern) + 1
	match String(enemy.kind):
		"soldier": _soldier(enemy)
		"armored_esper": _armored_esper(enemy)
		"silver_scout": _silver_scout(enemy)
		"orange_pod_drone": _orange_drone(enemy)
		"hoverboat": _hoverboat(enemy)
		"silver_interceptor": _interceptor(enemy)
		"rail_fortress": _rail_fortress(enemy)
		"boss": _boss_mech(enemy)

func _armored_esper(enemy: Dictionary) -> void:
	var aimed := _aim(enemy)
	for side in [-1, 1]:
		var name := "palm_left" if side == -1 else "palm_right"
		var port := Vector2(side * 23, 17)
		_flash(enemy, name, port, Color("ff9fdf"))
		for beat in range(3):
			_shot(enemy, name, port, 0.17 + beat * 0.10, aimed + side * (0.05 + beat * 0.035), 290 + beat * 20, 1, "bead", 0.78)
		beams.append({"owner": enemy, "muzzle": "beam_left" if side == -1 else "beam_right", "fallback": Vector2(side * 10, 37), "age": -0.48, "warmup": 0.25, "duration": 0.48, "length": 420.0})
	enemy.shot = 2.0 + int(enemy.variant) % 3 * 0.17

func _silver_scout(enemy: Dictionary) -> void:
	var aimed := _aim(enemy)
	for side in [-1, 1]:
		var name := "left" if side == -1 else "right"
		var port := Vector2(side * 27, 30)
		_flash(enemy, name, port, Color("affaff"), (side + 1) * 0.05)
		for beat in range(5):
			_shot(enemy, name, port, 0.18 + beat * 0.065 + (side + 1) * 0.05, aimed + side * (0.08 + beat * 0.04), 320 + beat * 15, 0, "bead", 0.8)
	enemy.shot = 1.62

func _orange_drone(enemy: Dictionary) -> void:
	var aimed := _aim(enemy)
	for index in range(3):
		var name: String = ["left", "center", "right"][index]
		var port := Vector2((index - 1) * 28, 30)
		_flash(enemy, name, port, Color("ffb7e9"), index * 0.07)
		for beat in range(3):
			_shot(enemy, name, port, 0.18 + index * 0.07 + beat * 0.11, aimed + (index - 1) * 0.16 + sin(beat * 0.65) * 0.06, 230 + beat * 25, 1, "bead", 1.1)
	enemy.shot = 1.9

func _hoverboat(enemy: Dictionary) -> void:
	var aimed := _aim(enemy)
	for side in [-1, 1]:
		var name := "left" if side == -1 else "right"
		var port := Vector2(-43, 102) if side == -1 else Vector2(41, 102)
		_flash(enemy, name, port, Color("ffb5e7"))
		for beat in range(3):
			for lane in range(-2, 3):
				_shot(enemy, name, port, 0.20 + beat * 0.1, aimed + lane * 0.15 + side * 0.12, 250 + beat * 30, 1, "bead", 0.9)
	enemy.shot = 2.0

func _interceptor(enemy: Dictionary) -> void:
	var aimed := _aim(enemy)
	var pink := int(enemy.pattern) % 2 == 1
	for side in [-1, 1]:
		var name := "wing_left" if side == -1 else "wing_right"
		var port := Vector2(side * 145, 62)
		_flash(enemy, name, port, Color("ffb4ef") if pink else Color("b4f9ff"), (side + 1) * 0.08, 0.24)
		for beat in range(4):
			for lane in range(-3, 4):
				_shot(enemy, name, port, 0.22 + beat * 0.095 + (side + 1) * 0.08, aimed + lane * 0.12 + side * 0.18 + sin(beat * 0.7) * 0.04, 245 + beat * 27, 1 if pink else 0, "bead" if pink else "drop", 0.9)
	enemy.shot = 1.8

func _rail_fortress(enemy: Dictionary) -> void:
	var aimed := _aim(enemy)
	_flash(enemy, "turret", Vector2(0, -25), Color("ffb8e8"), 0, 0.28)
	for lane in range(11):
		_shot(enemy, "turret", Vector2(0, -25), 0.24 + lane * 0.018, aimed + (lane - 5) * 0.19 + sin(enemy.pattern * 0.6) * 0.07, 240, 1, "bead", 0.9)
	for side in [-1, 1]:
		var name := "front_left" if side == -1 else "front_right"
		var port := Vector2(side * 58, 140)
		_flash(enemy, name, port, Color("ffb4ed"), 0.3 + (side + 1) * 0.05)
		for beat in range(7):
			_shot(enemy, name, port, 0.48 + beat * 0.075 + (side + 1) * 0.05, PI * 0.5 + side * 0.07 + sin(enemy.pattern * 0.5) * 0.05, 370 + beat * 10, 1, "needle", 0.84)
	enemy.shot = 2.0

func _boss_mech(enemy: Dictionary) -> void:
	var ratio := float(enemy.hp) / float(enemy.max_hp)
	var phase := 0 if enemy.age < 20 and ratio > 0.80 else (1 if enemy.age < 40 and ratio > 0.58 else (2 if enemy.age < 67 and ratio > 0.25 else 3))
	var aimed := _aim(enemy, Vector2(0, 95))
	match phase:
		0:
			_flash(enemy, "chest", Vector2(0, 5), Color("b4ffd6"), 0, 0.3)
			for beat in range(4):
				for lane in range(-1, 2): _shot(enemy, "chest", Vector2(0, 5), 0.28 + beat * 0.13, aimed + lane * 0.30 + beat * 0.025, 220 + beat * 10, 2, "ring", 0.9)
			for side in [-1, 1]:
				var name := "shoulder_left" if side == -1 else "shoulder_right"
				for lane in range(9): _shot(enemy, name, Vector2(side * 105, -80), 0.35 + lane * 0.035, aimed + (lane - 4) * 0.21 + side * 0.13, 265, 1, "star", 0.84)
		1:
			_flash(enemy, "hand_right", Vector2(165, 75), Color("a3f5ff"), 0, 0.24)
			for beat in range(4):
				for lane in range(-3, 4): _shot(enemy, "hand_right", Vector2(165, 75), 0.22 + beat * 0.085, aimed + lane * 0.14 + beat * 0.03, 275 + beat * 20, 0, "drop", 0.88)
			_flash(enemy, "foot_left", Vector2(-90, 190), Color("ffb0ec"), 0.3)
			for beat in range(4):
				for lane in range(-2, 3): _shot(enemy, "foot_left", Vector2(-90, 190), 0.48 + beat * 0.105, aimed + lane * 0.12 - beat * 0.025, 350, 1, "needle", 0.87)
		2:
			if not enemy.get("arms_open", false):
				for side in [-1, 1]:
					var name := "hand_left" if side == -1 else "hand_right"
					_flash(enemy, name, Vector2(side * 155, 80), Color("ff9cdc"), (side + 1) * 0.1)
					for beat in range(7):
						for lane in range(-2, 3): _shot(enemy, name, Vector2(side * 155, 80), 0.22 + beat * 0.10 + (side + 1) * 0.1, aimed + lane * 0.19 + side * sin(beat * 0.48) * 0.30, 235 + beat * 10, 1, "bead", 1.0)
			else: _arm_chains(enemy, aimed)
		3:
			_arm_chains(enemy, aimed)
			for lane in range(17):
				for beat in range(2): _shot(enemy, "chest", Vector2(0, 5), 0.9 + beat * 0.11, PI * 0.13 + lane * PI * 0.74 / 16, 235 + beat * 65, 0, "bead", 0.8)
			for lane in range(-3, 4): _shot(enemy, "foot_left", Vector2(-90, 190), 0.55, aimed + lane * 0.22, 300, 1, "star", 0.8)
	enemy.shot = 2.25 if phase < 2 else 2.05

func _arm_chains(enemy: Dictionary, aimed: float) -> void:
	for side in [-1, 1]:
		var name := "hand_left" if side == -1 else "hand_right"
		var port := Vector2(side * 180, 140)
		_flash(enemy, name, port, Color("a5f6ff"), (side + 1) * 0.09, 0.25)
		for beat in range(9):
			var angle: float = aimed + side * (0.08 + beat * 0.065)
			for bead in range(-1, 2):
				var nudge := Vector2.from_angle(angle + PI * 0.5) * bead * 13
				_shot(enemy, name, port, 0.24 + beat * 0.10 + (side + 1) * 0.09, angle, 290 + beat * 12, 0, "drop", 0.83, nudge)

func update(dt: float) -> void:
	super.update(dt)
	for index in range(beams.size() - 1, -1, -1):
		var beam: Dictionary = beams[index]
		beam.age += dt
		if not _alive(beam.owner) or beam.age > beam.warmup + beam.duration:
			beams.remove_at(index)
			continue
		if beam.age < beam.warmup: continue
		var start: Vector2 = beam.owner.p + _port(beam.owner, beam.muzzle, beam.fallback)
		if not beam.get("sound_started", false):
			beam["sound_started"] = true
			stage.sfx.play_cue("enemy_shot", start, 0.72)
		var end := start + Vector2(0, beam.length)
		var point: Vector2 = stage.player + Vector2(0, -4)
		if Geometry2D.get_closest_point_to_segment(point, start, end).distance_to(point) < 7 and stage.invulnerable <= 0:
			stage._hit_player()

func draw_cues(canvas: CanvasItem) -> void:
	super.draw_cues(canvas)
	for beam in beams:
		if beam.age < 0 or not _alive(beam.owner): continue
		var start: Vector2 = beam.owner.p + _port(beam.owner, beam.muzzle, beam.fallback)
		var end := start + Vector2(0, beam.length)
		if beam.age < beam.warmup:
			canvas.draw_line(start, end, Color(0.15, 0.6, 1, 0.18 + beam.age / beam.warmup * 0.18), 1, true)
			canvas.draw_circle(start, 5 + beam.age * 12, Color("d0ffff"))
		else:
			var life: float = (beam.age - beam.warmup) / beam.duration
			var strength := sin(life * PI) * (0.85 + sin(clock * 55) * 0.15)
			canvas.draw_line(start, end, Color(0.08, 0.35, 1, strength * 0.2), 17, true)
			canvas.draw_line(start, end, Color(0.12, 0.72, 1, strength), 5, true)
			canvas.draw_line(start, end - Vector2(0, 10), Color(0.8, 1, 1, strength), 1.7, true)
			canvas.draw_line(start - Vector2(9, 0), start + Vector2(9, 0), Color(0.7, 1, 1, strength), 2, true)
