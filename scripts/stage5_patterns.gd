extends "res://scripts/stage4_patterns.gd"

const GATE_ACTORS := ["gate_esper_a", "gate_esper_b"]
const GATE_HOMES := [Vector2(310, 260), Vector2(650, 245)]
const GATE_LANES := [Rect2(138, 150, 285, 285), Rect2(537, 145, 285, 285)]
const GATE_HIT_ELLIPSE := Vector2(42, 70)
const GATE_MOVE_TIME_SCALE := 2.0
const GATE_ATTACK_TIME_SCALE := 2.0

func clear() -> void:
	super.clear()

	for enemy in stage.enemies:
		if enemy.kind == "gate_keeper":
			for member in enemy.get("duo_members", []): member.cast_at = -10.0
		elif enemy.kind == "maid":
			enemy["maid_cast_until"] = -1.0
		elif enemy.kind == "boss":
			enemy["cast_time"] = 0.0
			if enemy.get("mode", "") == "combat" and int(enemy.get("form", 0)) == 1:
				_set_actor(enemy, "queen_idle")

func clock_step(dt: float) -> float:
	var hold: float = stage.stage_spec.get("gate_hold", 205.0)
	for enemy in stage.enemies:
		if enemy.kind == "gate_keeper" and enemy.hp > 0:
			return minf(dt, maxf(0, hold - stage.elapsed))
	return dt

func prepare_enemy(enemy: Dictionary) -> void:
	enemy["actor"] = enemy.kind
	enemy["anim_age"] = 0.0
	enemy["draw_scale"] = 1.0
	if enemy.kind == "gate_keeper":
		enemy["hud_boss"] = true
		enemy["energy_defeat"] = true
		enemy.erase("hit_ellipse")
		enemy.radius = 46.0
		enemy["duo_radius"] = 46.0
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		enemy["duo_rng"] = rng
		enemy["duo_entered"] = false
		var entry_y := minf(-105.0, float(enemy.p.y))
		var positions: Array[Vector2] = [Vector2(310, entry_y), Vector2(650, entry_y - 60)]
		enemy["duo_positions"] = positions
		enemy["duo_entry_from"] = positions.duplicate()
		var ages: Array[float] = [0.0, 0.0]
		enemy["duo_anim_ages"] = ages
		var members: Array[Dictionary] = []
		for index in range(2):
			members.append({"p": positions[index], "mode": "rest", "rest": (0.40 + index * 0.24) * GATE_MOVE_TIME_SCALE, "dash_time": 0.0, "duration": 0.4 * GATE_MOVE_TIME_SCALE, "from": GATE_HOMES[index], "to": GATE_HOMES[index], "control": GATE_HOMES[index], "dash_count": 0, "cast_at": -10.0})
		enemy["duo_members"] = members
		enemy.p = (positions[0] + positions[1]) * 0.5
	elif enemy.kind == "boss":
		enemy["actor"] = "queen_seated"
		enemy["mode"] = "waiting"
		enemy["form"] = 0
		enemy["transition"] = 0.0
		enemy["cast_time"] = 0.0
		enemy["dying"] = false
		enemy["death_time"] = 0.0
		enemy["shadow_strength"] = 0.7
		enemy["grounded_visual"] = true
		enemy.radius = 48.0
		enemy.p = _throne_position()
		enemy["invite_voiced"] = false
		_voice_invitation(enemy)

func _voice_invitation(enemy: Dictionary) -> void:
	if enemy.get("invite_voiced", false) or enemy.mode != "waiting": return
	if enemy.p.x < -85 or enemy.p.x > 1045 or enemy.p.y < -85 or enemy.p.y > 1045: return
	enemy["invite_voiced"] = true
	stage.voice.play_narrative("queen_invite")

func _throne_position() -> Vector2:
	var anchor: Array = stage.stage_spec.get("throne_anchor", [360, 2080])
	return stage._world_to_screen(Vector2(anchor[0], anchor[1]))

func _set_actor(enemy: Dictionary, actor: String) -> void:
	if enemy.get("actor", "") != actor:
		enemy.actor = actor
		enemy.anim_age = 0.0

func _actor(enemy: Dictionary) -> String:
	return str(enemy.get("actor", enemy.kind))

func animation_time(enemy: Dictionary, actor_id: String) -> float:
	if actor_id == "maid_jump":
		var age := float(enemy.get("anim_age", 0.0))

		if float(enemy.age) <= float(enemy.get("maid_cast_until", -1.0)): return age
		var frame := 0 if age < 0.40 else (4 if age < 0.625 else 5)
		return (frame + 0.01) / float(stage.art.get(actor_id, {}).get("fps", 8))
	if enemy.kind == "boss" and actor_id != "statue":
		return float(enemy.get("anim_age", 0.0))
	return super.animation_time(enemy, actor_id)

func _port(enemy: Dictionary, name: String, fallback: Vector2) -> Vector2:
	if enemy.kind == "gate_keeper" and enemy.has("duo_positions"):
		var index := 1 if name == "guardian_right" else 0
		var actor: Dictionary = stage.art.get(GATE_ACTORS[index], {})
		var value: Array = actor.get("muzzles", {}).get("main", [0.0, 22.0])
		if value[0] is Array:
			var frame := int(_gate_pose_time(enemy, index) * float(actor.get("fps", 8)))
			value = value[frame % value.size()]
		return enemy.duo_positions[index] - enemy.p + Vector2(float(value[0]), float(value[1]))
	var actor: Dictionary = stage.art.get(_actor(enemy), {})
	var value: Array = actor.get("muzzles", {}).get(name, [fallback.x, fallback.y])
	if value[0] is Array:
		var frame := int(animation_time(enemy, _actor(enemy)) * float(actor.get("fps", 8)))
		frame = frame % value.size() if actor.get("loop", true) else mini(frame, value.size() - 1)
		value = value[frame]
	return Vector2(value[0], value[1]) * float(enemy.get("draw_scale", 1.0))

func can_damage(enemy: Dictionary) -> bool:
	if enemy.kind == "gate_keeper": return enemy.age >= 2.5
	if enemy.kind != "boss": return true
	return enemy.mode == "combat" and enemy.transition <= 0 and not enemy.dying

func handle_defeat(enemy: Dictionary) -> bool:
	if enemy.kind == "gate_keeper":
		enemy["energy_defeat"] = true
		for index in range(enemy.get("duo_positions", []).size()):
			var hue := Color("ff85d9") if index == 0 else Color("8eefff")
			stage._spark(enemy.duo_positions[index], hue, 34, 230)
		return false
	if enemy.kind != "boss": return false
	if int(enemy.form) == 0:
		enemy.form = 1
		enemy.mode = "breaking"
		enemy.transition = 3.0
		enemy.hp = 1.0
		enemy.age = 0.0
		clear()
		stage.bullets.clear()
		stage.gamepad.pulse("large_enemy")
		for index in range(12):
			stage._explode(enemy.p + Vector2(sin(index * 2.4) * 160, cos(index * 1.8) * 200), 1.1 + (index % 3) * 0.25, index * 0.16)
		stage.shake = 16
		return true
	if not enemy.dying:
		enemy.dying = true
		enemy.mode = "defeat"
		enemy.death_time = 1.05
		enemy.hp = 1.0
		enemy.age = 0.0
		enemy["energy_defeat"] = true
		stage.voice.play_narrative("queen_death")
		_set_actor(enemy, "queen_defeat")
		clear()
		stage.bullets.clear()
		stage._spark(enemy.p, Color("fc3467"), 54, 220)
		return true
	return enemy.death_time > 0 or stage.voice.is_narrative_busy("queen_death")

func _mount_offset() -> Vector2:
	var offset: Array = stage.stage_spec.get("statue_mount_offset", [-10, -190])
	return Vector2(offset[0], offset[1])

func _queen_phase(enemy: Dictionary) -> int:
	var ratio := float(enemy.hp) / float(enemy.max_hp)
	if enemy.age < 35 and ratio > 0.78: return 0
	if enemy.age < 98 and ratio > 0.40: return 1
	return 2

func move_enemy(enemy: Dictionary, dt: float) -> void:
	enemy.anim_age += dt
	if enemy.kind == "maid":
		var phase := fposmod(float(enemy.age) + int(enemy.variant) * 0.23, 2.35)
		var jumping := phase < 0.80
		var altitude := sin(phase / 0.80 * PI) if jumping else 0.0
		_set_actor(enemy, "maid_jump" if jumping and stage.art.has("maid_jump") else "maid")
		if jumping: enemy.anim_age = phase
		var foot: Vector2 = stage._world_to_screen(enemy.wp)
		var maid_scale: float = stage.stage_spec.get("maid_scale", 1.0)
		enemy.draw_scale = maid_scale * lerpf(0.85, 1.15, clampf(foot.y / 906.0, 0, 1)) * (1.0 + altitude * 0.24)
		enemy.p = foot - Vector2(0, 45.3 * enemy.draw_scale + altitude * 68 * maid_scale)
		enemy.radius = 23.0 * enemy.draw_scale
		enemy["shadow_strength"] = 1.0 - altitude * 0.62
		enemy["jump_height"] = altitude
		return
	if enemy.ground: return
	match String(enemy.kind):
		"gate_keeper": _move_gate_duo(enemy, dt)
		"boss": _move_final_boss(enemy, dt)
		"drone":
			enemy.p.y += enemy.speed * dt
			enemy.p.x = enemy.origin_x + sin(enemy.age * 1.5 + enemy.variant) * 58
		"gunship", "round_barge":
			enemy.p.y += dt * (20 if enemy.age > 2 and enemy.age < 7 else enemy.speed)
			enemy.p.x = enemy.origin_x + sin(enemy.age * 0.8 + enemy.variant) * 65
		_: super.move_enemy(enemy, dt)

func gate_bodies(enemy: Dictionary) -> Array[Dictionary]:
	var bodies: Array[Dictionary] = []
	for index in range(enemy.get("duo_positions", []).size()):
		var actor: String = GATE_ACTORS[index]
		var height: float = stage.art.get(actor, {}).get("display_height", 180.0)
		bodies.append({"actor": actor, "p": enemy.duo_positions[index], "height": height, "age": _gate_pose_time(enemy, index), "hit_ellipse": GATE_HIT_ELLIPSE * height / 180.0})
	return bodies

func _gate_pose_time(enemy: Dictionary, index: int) -> float:
	var since := float(enemy.age) - float(enemy.duo_members[index].get("cast_at", -10.0))
	var frame := 0
	if since >= 0 and since < 0.22: frame = 1
	elif since >= 0.22 and since <= 0.90 - index * 0.20: frame = 2
	elif since > 0.90 - index * 0.20 and since < 1.08 - index * 0.20: frame = 3
	return (frame + 0.01) / float(stage.art.get(GATE_ACTORS[index], {}).get("fps", 8))

func gate_hit_test(enemy: Dictionary, previous: Vector2, current: Vector2, radius: float) -> bool:
	for body in gate_bodies(enemy):
		var bounds: Vector2 = body.hit_ellipse + Vector2.ONE * radius
		var closest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, (previous - body.p) / bounds, (current - body.p) / bounds)
		if closest.length_squared() <= 1.0: return true
	return false

func gate_hit_point(enemy: Dictionary, from: Vector2) -> Vector2:
	var nearest: Vector2 = enemy.p
	var distance := INF
	for body in gate_bodies(enemy):
		var relative: Vector2 = (from - body.p) / body.hit_ellipse
		var point: Vector2 = body.p + relative.limit_length(0.94) * body.hit_ellipse
		var candidate := point.distance_squared_to(from)
		if candidate < distance:
			distance = candidate
			nearest = point
	return nearest

func gate_target_position(enemy: Dictionary, from: Vector2) -> Vector2:
	var nearest: Vector2 = enemy.p
	var distance := INF
	for point: Vector2 in enemy.get("duo_positions", []):
		var candidate := point.distance_squared_to(from)
		if candidate < distance:
			distance = candidate
			nearest = point
	return nearest

func _gate_clamp(point: Vector2, lane: Rect2) -> Vector2:
	return Vector2(clampf(point.x, lane.position.x, lane.end.x), clampf(point.y, lane.position.y, lane.end.y))

func _begin_gate_dash(member: Dictionary, index: int, rng: RandomNumberGenerator) -> void:
	var lane: Rect2 = GATE_LANES[index]
	var start: Vector2 = member.p
	var finish := start
	for attempt in range(18):
		finish = _gate_clamp(start + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(125, 235), lane)
		if finish.distance_to(start) >= 100: break
	if finish.distance_to(start) < 100:
		finish = Vector2(lane.position.x if start.x > lane.get_center().x else lane.end.x, lane.position.y if start.y > lane.get_center().y else lane.end.y)
	var direction := (finish - start).normalized()
	var control := _gate_clamp(start.lerp(finish, 0.5) + Vector2(-direction.y, direction.x) * rng.randf_range(-36, 36), lane)
	member["from"] = start
	member["to"] = finish
	member["control"] = control
	member["duration"] = rng.randf_range(0.25, 0.55) * GATE_MOVE_TIME_SCALE
	member["dash_time"] = 0.0
	member["mode"] = "dash"
	member["dash_count"] = int(member.dash_count) + 1

func _advance_gate_member(member: Dictionary, index: int, dt: float, rng: RandomNumberGenerator) -> void:
	var remaining := maxf(0.0, dt)
	var steps := 0
	while remaining > 0.000001 and steps < 32:
		steps += 1
		if member.mode == "rest":
			var used := minf(remaining, maxf(0, float(member.rest)))
			member.rest -= used
			remaining -= used
			if member.rest <= 0.000001: _begin_gate_dash(member, index, rng)
		else:
			var used := minf(remaining, maxf(0, float(member.duration) - float(member.dash_time)))
			member.dash_time += used
			remaining -= used
			var t := clampf(float(member.dash_time) / float(member.duration), 0, 1)
			var eased := t * t * (3.0 - 2.0 * t)
			var start: Vector2 = member["from"]
			var control: Vector2 = member.control
			var finish: Vector2 = member.to
			member.p = start.lerp(control, eased).lerp(control.lerp(finish, eased), eased)
			if t >= 1.0:
				member.p = finish
				member.mode = "rest"
				member.rest = rng.randf_range(0.35, 0.80) * GATE_MOVE_TIME_SCALE

func _move_gate_duo(enemy: Dictionary, dt: float) -> void:
	if float(enemy.age) < 2.4:
		var entry := smoothstep(0.0, 2.2, float(enemy.age))
		for index in range(2):
			enemy.duo_positions[index] = enemy.duo_entry_from[index].lerp(GATE_HOMES[index], entry)
	else:
		if not enemy.duo_entered:
			enemy.duo_entered = true
			for index in range(2):
				enemy.duo_members[index].p = GATE_HOMES[index]
		var rng: RandomNumberGenerator = enemy.duo_rng
		for index in range(2):
			_advance_gate_member(enemy.duo_members[index], index, dt, rng)
			enemy.duo_positions[index] = enemy.duo_members[index].p
	for index in range(2): enemy.duo_anim_ages[index] = _gate_pose_time(enemy, index)
	enemy.p = (enemy.duo_positions[0] + enemy.duo_positions[1]) * 0.5

func _move_final_boss(enemy: Dictionary, dt: float) -> void:
	if enemy.mode in ["waiting", "leaping"]:
		if enemy.age < 5:
			enemy.p = _throne_position()
			_set_actor(enemy, "queen_seated")
			_voice_invitation(enemy)
		else:
			if enemy.mode == "waiting":
				enemy.mode = "leaping"
				enemy["leap_from"] = _throne_position()
				stage._spark(enemy.leap_from, Color("f29be7"), 22, 160)
			enemy.grounded_visual = false
			enemy.shadow_strength = 0.0
			enemy.radius = 220.0
			_set_actor(enemy, "statue")
			var progress := smoothstep(0.0, 1.0, (enemy.age - 5) / 3.0)
			var body_y: float = stage.stage_spec.get("statue_center_y", 335.0)
			enemy.p = Vector2(480, lerpf(-330, body_y, progress))
			if enemy.age >= 8:
				enemy.mode = "combat"
				enemy.shot = 1.0
		return
	if enemy.mode == "breaking":
		enemy.transition = maxf(0, enemy.transition - dt)
		if enemy.transition <= 0:
			enemy.mode = "combat"
			enemy.hp = float(stage.stage_spec.get("queen_hp", 95000.0))
			enemy.max_hp = enemy.hp
			enemy.radius = float(stage.stage_spec.get("queen_radius", 60.0))
			enemy.p += _mount_offset()
			enemy.p.y = maxf(160, enemy.p.y)
			enemy.age = 0.0
			enemy.shot = 1.0
			_set_actor(enemy, "queen_idle")
			stage.sfx.play_cue("boss_transform", enemy.p)
		return
	if enemy.dying:
		enemy.death_time = maxf(0, enemy.death_time - dt)
		if enemy.death_time <= 0 and not stage.voice.is_narrative_busy("queen_death"): enemy.hp = 0.0
		return
	if int(enemy.form) == 0:
		var target := Vector2(480 + sin(enemy.age * 0.29) * 68, float(stage.stage_spec.get("statue_center_y", 335)) + sin(enemy.age * 0.22) * 20)

		enemy.p = enemy.p.move_toward(target, dt * 80.0)
		return
	enemy.cast_time = maxf(0, enemy.cast_time - dt)
	var phase := _queen_phase(enemy)
	if int(enemy.get("queen_phase", -1)) != phase:
		enemy["queen_phase"] = phase
		enemy.cast_time = 0.0
		pending = pending.filter(func(shot): return not is_same(shot.owner, enemy))
		cues = cues.filter(func(cue): return not is_same(cue.owner, enemy))
	var target := Vector2(480 + sin(enemy.age * (0.72 if phase == 2 else 0.43)) * (240 if phase == 2 else (55 if phase == 1 else 150)), 235 + sin(enemy.age * 0.51) * (65 if phase == 2 else 28))
	enemy.p = enemy.p.move_toward(target, dt * (290 if phase == 2 else 165))
	_update_queen_pose(enemy, phase)

func _update_queen_pose(enemy: Dictionary, phase: int) -> void:
	if enemy.cast_time <= 0:
		_set_actor(enemy, "queen_idle")
		return
	_set_actor(enemy, ["queen_cast", "queen_sigil", "queen_fan"][phase])
	var age := float(enemy.get("cast_duration", 1.21)) - float(enemy.cast_time)
	var release := float(enemy.get("cast_release", 1.05))
	var frame := 0 if age < 0.08 else (1 if age < 0.20 else (2 if age <= release else 3))
	enemy.anim_age = (frame + 0.01) / float(stage.art.get(enemy.actor, {}).get("fps", 8))

func fire(enemy: Dictionary) -> void:
	if not _alive(enemy) or not can_damage(enemy): return
	if enemy.kind in ["silver_scout", "orange_pod_drone", "hoverboat", "soldier"]:
		super.fire(enemy)
		return
	enemy.pattern = int(enemy.pattern) + 1
	match String(enemy.kind):
		"yellow_jeep": _jeep(enemy)
		"disk_turret": _disk(enemy)
		"yellow_heavy_tank": _yellow_heavy(enemy)
		"green_heavy_tank", "tank": _double_tank(enemy)
		"maid": _maid(enemy)
		"drone", "gunship", "round_barge": _old_aircraft(enemy)
		"gate_keeper": _gate_keeper(enemy)
		"boss":
			if int(enemy.form) == 0: _statue(enemy)
			else: _queen(enemy)

func _jeep(enemy: Dictionary) -> void:
	var angle := _aim(enemy)
	_flash(enemy, "main", Vector2(0, 12), Color("ffb6e7"))
	for beat in range(2):
		for lane in [-1, 1]: _shot(enemy, "main", Vector2(0, 12), 0.16 + beat * 0.11, angle + lane * 0.06, 330 + beat * 25, 1, "bead", 0.82)
	enemy.shot = 1.6

func _disk(enemy: Dictionary) -> void:
	var aimed := _aim(enemy)
	for index in range(3):
		var name: String = ["left", "center", "right"][index]
		var port := Vector2((index - 1) * 55, 40)
		_flash(enemy, name, port, Color("f8b0ef"), index * 0.06)
		for lane in range(7):
			_shot(enemy, name, port, 0.2 + index * 0.06 + lane * 0.022, aimed + (lane - 3) * 0.24 + sin(enemy.pattern * 0.5) * 0.18, 245, 1, "bead", 0.90)
	enemy.shot = 1.85

func _yellow_heavy(enemy: Dictionary) -> void:
	var aimed := _aim(enemy)
	_flash(enemy, "main", Vector2(0, 80), Color("ffa6df"), 0, 0.26)
	for beat in range(3):
		for lane in range(-3, 4): _shot(enemy, "main", Vector2(0, 80), 0.24 + beat * 0.10, aimed + lane * 0.14 + beat * 0.025, 280 + beat * 25, 1, "star", 0.88)
	for beat in range(4): _shot(enemy, "main", Vector2(0, 80), 0.76 + beat * 0.075, aimed - 0.04 + beat * 0.025, 390 + beat * 15, 0, "drop", 0.9)
	enemy.shot = 2.1

func _double_tank(enemy: Dictionary) -> void:
	var aimed := _aim(enemy)
	var heavy: bool = enemy.kind == "green_heavy_tank"
	for side in [-1, 1]:
		var name := "left" if side == -1 else "right"
		var port := Vector2(side * 26, 65 if heavy else 30)
		_flash(enemy, name, port, Color("abf6ff"), (side + 1) * 0.06)
		for beat in range(5 if heavy else 3):
			for lane in range(-1, 2): _shot(enemy, name, port, 0.18 + beat * 0.08 + (side + 1) * 0.06, aimed + lane * 0.09 + side * beat * 0.018, 330 + beat * 18, 0, "drop", 0.9)
	if heavy:
		for lane in range(-3, 4): _shot(enemy, "left", Vector2(-26, 65), 0.83, aimed + lane * 0.18, 255, 1, "bead", 0.9)
	enemy.shot = 1.9

func _maid(enemy: Dictionary) -> void:
	if float(enemy.get("jump_height", 0)) < 0.55:
		enemy.shot = 0.08
		return
	enemy["maid_cast_until"] = float(enemy.age) + 0.30
	var angle := _aim(enemy)
	for side in [-1, 1]:
		var name := "left" if side == -1 else "right"
		var port := Vector2(side * 18, 4)
		_flash(enemy, name, port, Color("b7ffff"), 0, 0.12)
		for lane in range(-1, 2): _shot(enemy, name, port, 0.09 + (side + 1) * 0.025, angle + lane * 0.12 + side * 0.05, 360, 0, "drop", 0.78)
	enemy.shot = 1.6

func _old_aircraft(enemy: Dictionary) -> void:
	var aimed := _aim(enemy)
	if enemy.kind == "drone":
		_flash(enemy, "center", Vector2(0, 22), Color("aaffff"), 0, 0.15)
		for beat in range(3): _shot(enemy, "center", Vector2(0, 22), 0.13 + beat * 0.075, aimed + beat * 0.025, 330 + beat * 20, 0, "drop", 0.8)
	else:
		var large: bool = enemy.kind == "round_barge"
		for side in [-1, 1]:
			var name := "left" if side == -1 else "right"
			var port := Vector2(side * 90, 140) if large else (Vector2(-30, 68) if side == -1 else Vector2(-25, 72))
			_flash(enemy, name, port, Color("ffb5e5") if large else Color("aaffff"), (side + 1) * 0.07)
			for beat in range(3):
				for lane in range(-2, 3): _shot(enemy, name, port, 0.18 + beat * 0.10 + (side + 1) * 0.07, aimed + lane * (0.17 if large else 0.08), 280 + beat * 28, 1 if large else 0, "bead", 0.9)
	enemy.shot = 1.8

func _gate_keeper(enemy: Dictionary) -> void:
	var damaged := float(enemy.hp) / float(enemy.max_hp) < 0.5
	for index in range(2): enemy.duo_members[index].cast_at = float(enemy.age) + index * 0.20
	for side in [-1, 1]:
		var name := "guardian_left" if side == -1 else "guardian_right"
		var port := Vector2.ZERO
		var aimed := _aim(enemy, _port(enemy, name, port))
		_flash(enemy, name, port, Color("ffb3ee"), (side + 1) * 0.10, 0.24)
		for beat in range(4):
			for lane in range(-3, 4): _shot(enemy, name, port, 0.22 + beat * 0.1 + (side + 1) * 0.1, aimed + lane * 0.15 + side * sin(enemy.pattern * 0.6 + beat * 0.45) * 0.17, 255 + beat * 27, 1, "needle" if damaged else "bead", 0.85)
		for lane in range(-2, 3): _shot(enemy, name, port, 0.85, aimed + lane * 0.25 + side * 0.08, 330, 0, "drop", 0.86)
	enemy.shot = (1.65 if damaged else 1.95) * GATE_ATTACK_TIME_SCALE

func _statue(enemy: Dictionary) -> void:
	var aimed := _aim(enemy)
	_flash(enemy, "forehead", Vector2(0, -120), Color("ffa9e5"), 0, 0.30)
	for arm in range(3):
		for bead in range(11):
			_shot(enemy, "forehead", Vector2(0, -120), 0.28 + bead * 0.07, aimed + (arm - 1) * 1.6 + bead * 0.16 + sin(enemy.pattern * 0.4) * 0.2, 210 + bead * 9, 1, "bead", 1.05)
	for side in [-1, 1]:
		var name := "crown_left" if side == -1 else "crown_right"
		var port := Vector2(side * 155, -60)
		_flash(enemy, name, port, Color("9cfaff"), 0.24 + (side + 1) * 0.07)
		for beat in range(5):
			for lane in range(-2, 3): _shot(enemy, name, port, 0.44 + beat * 0.08 + (side + 1) * 0.07, aimed + lane * 0.16 + side * beat * 0.075, 290 + beat * 12, 0, "star", 0.8)
	enemy.shot = 1.85

func _queen(enemy: Dictionary) -> void:
	var phase := _queen_phase(enemy)
	enemy["cast_release"] = 1.12 if phase == 2 and int(enemy.pattern) % 2 == 0 else (1.05 if phase == 2 else (0.90 if phase == 1 else 1.00))

	enemy.cast_release += 0.05
	enemy["cast_duration"] = float(enemy.cast_release) + 0.16
	enemy.cast_time = enemy.cast_duration
	_update_queen_pose(enemy, phase)
	var aimed := _aim(enemy, Vector2.ZERO)
	if phase == 0:
		for side in [-1, 1]:
			var name := "hand_left" if side == -1 else "hand_right"
			var port := Vector2(side * 36, 0)
			_flash(enemy, name, port, Color("ffb3ec"), (side + 1) * 0.08)
			for beat in range(7):
				for lane in range(-2, 3): _shot(enemy, name, port, 0.18 + beat * 0.11 + (side + 1) * 0.08, aimed + lane * 0.19 + side * sin(beat * 0.45) * 0.25, 230 + beat * 15, 1, "bead", 0.95)
		for lane in range(-4, 5): _shot(enemy, "core", Vector2.ZERO, 0.70, aimed + lane * 0.22, 315, 0, "star", 0.84)
	elif phase == 1:
		for side in [-1, 1]:
			for node in range(3):
				var port := _sigil_node(enemy, side, node)
				var angle: float = (stage.player - (enemy.p + port)).angle()
				_cue(enemy, port, Color("a7ffff"), 0.22, false, node * 0.1)
				cues.back()["sigil_node"] = [side, node]
				for beat in range(4):
					for lane in range(-1, 2):
						_queue(enemy, 0.20 + node * 0.1 + beat * 0.095, port, angle + lane * 0.11 + side * beat * 0.028, 275 + beat * 18, 0, "drop", 0.88)
						pending.back()["sigil_node"] = [side, node]
		for lane in range(-3, 4): _shot(enemy, "core", Vector2.ZERO, 0.90, aimed + lane * 0.22 + sin(enemy.pattern * 0.4) * 0.15, 220, 1, "bead", 1.35)
	else:
		for side in [-1, 1]:
			var name := "hand_left" if side == -1 else "hand_right"
			var port := Vector2(side * 40, 0)
			_flash(enemy, name, port, Color("b4faff") if side == -1 else Color("ffbaef"), (side + 1) * 0.09, 0.24)
			for row in range(6):
				var swing: float = sin(enemy.pattern * 0.55 + row * 0.12) * 0.25
				for lane in range(7):
					_shot(enemy, name, port, 0.22 + row * 0.13 + (side + 1) * 0.09, PI * 0.5 + (lane - 3) * 0.145 + side * (0.14 + row * 0.016) + swing, 225 + row * 19, 0 if side == -1 else 1, "palm", 0.95)
		if int(enemy.pattern) % 2 == 0:
			for lane in range(-6, 7): _shot(enemy, "core", Vector2.ZERO, 1.12, aimed + lane * 0.15, 315, 1, "star", 0.8)
	enemy.shot = 1.85 if phase == 0 else (1.72 if phase == 1 else 2.05)

func _sigil_node(enemy: Dictionary, side: int, index: int) -> Vector2:
	var base: Vector2 = [Vector2(190, -70), Vector2(292, 18), Vector2(218, 125)][index]
	return Vector2(base.x * side, base.y) + Vector2(side * sin(enemy.age * 0.75 + index) * 9, cos(enemy.age * 0.6 + index) * 8)

func _emitter_position(emission: Dictionary) -> Vector2:
	if emission.has("sigil_node"):
		return emission.owner.p + _sigil_node(emission.owner, int(emission.sigil_node[0]), int(emission.sigil_node[1]))
	return super._emitter_position(emission)

func draw_cues(canvas: CanvasItem) -> void:
	super.draw_cues(canvas)
	for enemy in stage.enemies:
		if enemy.kind == "boss":
			_draw_queen_entrance(canvas, enemy)
			if enemy.mode == "combat" and int(enemy.form) == 1 and _queen_phase(enemy) == 1: _draw_sigils(canvas, enemy)

func _draw_queen_entrance(canvas: CanvasItem, enemy: Dictionary) -> void:
	if enemy.mode != "waiting" and int(enemy.form) == 0 and stage.elapsed < float(stage.stage_spec.get("night_start", 315)):
		var chair := _throne_position()
		if stage.art.has("throne") and chair.y < 1100: stage._draw_actor("throne", chair, float(stage.art.throne.display_height), 0)
	if enemy.mode == "waiting":
		canvas.draw_arc(enemy.p - Vector2(0, 15), 62, 0, TAU, 48, Color(1, 0.4, 0.8, 0.25), 1.5, true)
		return
	if enemy.mode == "leaping":
		var amount := clampf((enemy.age - 5) / 3.0, 0, 1)
		var start: Vector2 = enemy.leap_from
		var finish: Vector2 = Vector2(480, float(stage.stage_spec.get("statue_center_y", 335))) + _mount_offset()
		var control := Vector2(lerpf(start.x, finish.x, 0.5) - 100, maxf(120, minf(start.y, finish.y) - 140))
		var position: Vector2 = start.lerp(control, amount).lerp(control.lerp(finish, amount), amount)
		var size := lerpf(170, 85, amount)
		var frame := 0 if amount < 0.12 else (1 if amount < 0.42 else (2 if amount < 0.9 else 3))
		var clip_age := (frame + 0.01) / float(stage.art.get("queen_leap", {}).get("fps", 8))
		for trail in range(3, 0, -1): stage._draw_actor("queen_leap", position + Vector2(-trail * 5, trail * 12), size, clip_age, Color(1, 0.25, 0.65, 0.10 * (4 - trail)))
		stage._draw_actor("queen_leap", position, size, clip_age)
		return
	if int(enemy.form) == 0 or enemy.mode == "breaking":
		stage._draw_actor("queen_idle", enemy.p + _mount_offset(), 85, enemy.age)

func _draw_sigils(canvas: CanvasItem, enemy: Dictionary) -> void:
	for side in [-1, 1]:
		var hue := Color.from_hsv(fposmod(enemy.age * 0.035 + (0.65 if side == -1 else 0.82), 1), 0.68, 1)
		var nodes: Array[Vector2] = []
		for index in range(3): nodes.append(enemy.p + _sigil_node(enemy, side, index))
		var wing := PackedVector2Array([enemy.p + Vector2(side * 45, -10), nodes[0], nodes[1], nodes[2], enemy.p + Vector2(side * 75, 65)])
		canvas.draw_polyline(wing, Color(hue.r, hue.g, hue.b, 0.16), 12, true)
		canvas.draw_polyline(wing, Color(hue.r, hue.g, hue.b, 0.84), 2.4, true)
		for index in range(3):
			var center: Vector2 = nodes[index]
			var radius := 44.0 + index * 7
			canvas.draw_arc(center, radius, 0, TAU, 64, Color(hue.r, hue.g, hue.b, 0.65), 2, true)
			canvas.draw_arc(center, radius * 0.78, enemy.age * side, enemy.age * side + TAU * 0.88, 48, Color(0.6, 1, 1, 0.5), 1.5, true)
			for petal in range(8):
				var angle: float = petal * TAU / 8 + enemy.age * side * 0.2
				var axis := Vector2.from_angle(angle)
				var across := axis.orthogonal()
				var leaf := PackedVector2Array([center + axis * 18, center + axis * radius * 0.7 + across * 16, center + axis * (radius + 20), center + axis * radius * 0.7 - across * 16, center + axis * 18])
				canvas.draw_polyline(leaf, Color(hue.r, hue.g, hue.b, 0.63), 1.5, true)
			canvas.draw_circle(center, 13 + sin(enemy.age * 4 + index) * 2, Color(0.05, 0.8, 1, 0.25))
			canvas.draw_circle(center, 5.5, Color("d2ffff"))

func draw_glow(canvas: CanvasItem, texture: Texture2D) -> void:
	var offset: Vector2 = Vector2(sin(stage.visual_time * 97), cos(stage.visual_time * 113)) * stage.shake
	for enemy in stage.enemies:
		if enemy.kind != "boss" or enemy.mode != "combat" or int(enemy.form) != 1 or _queen_phase(enemy) != 1: continue
		for side in [-1, 1]:
			var hue := Color.from_hsv(fposmod(enemy.age * 0.035 + (0.65 if side == -1 else 0.82), 1), 0.7, 1)
			for index in range(3):
				var point: Vector2 = enemy.p + _sigil_node(enemy, side, index)
				canvas.draw_set_transform(point + offset)
				canvas.draw_texture_rect(texture, Rect2(-48, -48, 96, 96), false, Color(hue.r, hue.g, hue.b, 0.4))
	canvas.draw_set_transform(Vector2.ZERO)
