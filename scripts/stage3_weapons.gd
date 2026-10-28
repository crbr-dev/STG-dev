extends RefCounted

static func emit(stage, focused: bool, charged: bool = false) -> void:
	var upgraded: bool = stage.stage_index >= 4
	var coverage := 1.10 if upgraded else 1.0
	if charged:
		for lane in range(-2, 3):
			stage.player_shots.append({"p": stage.player + Vector2(lane * 12, -28 + abs(lane) * 8), "v": Vector2(lane * 84 * coverage, -710 + abs(lane) * 36), "age": 0.0, "damage": 25.0, "kind": "spirit_orb", "focused": true, "radius": 20.0, "phase": lane * 1.3, "charged": true, "upgraded": upgraded})
		return
	var lanes: Array[float] = stage._primary_shot_lanes(focused)
	for index in range(lanes.size()):
		var lane: float = lanes[index]
		var angle := -PI * 0.5 + lane * (0.026 if focused else 0.095) * coverage
		stage.player_shots.append({"p": stage.player + Vector2(lane * (7 if focused else 11), -28 - abs(lane) * 7), "v": Vector2.from_angle(angle) * 1040, "age": 0.0, "damage": (8.0 + stage.power_level * 1.25) * 1.15, "kind": "spirit_lance", "focused": focused, "radius": 9.0, "phase": lane * 0.7, "charged": false, "seal": index == int(lanes.size() / 2) and int(stage.player_animation_time / 0.14) % 3 == 0, "upgraded": upgraded})

static func update_shot(shot: Dictionary, dt: float) -> void:
	if shot.get("kind", "") == "spirit_orb":
		shot.p.x += cos(shot.age * 13.0 + shot.phase) * (20.0 if shot.focused else 38.0) * dt

static func draw_shot(stage, shot: Dictionary) -> void:
	var is_orb: bool = shot.kind == "spirit_orb"
	var offset: Vector2 = Vector2(sin(stage.visual_time * 97), cos(stage.visual_time * 113)) * stage.shake
	var actor_id := "magic_fire" if is_orb else "magic_focus"
	var intensity := 0.85 + 0.15 * sin(shot.age * 35 + shot.phase)
	var dimensions := Vector2(68, 68) if is_orb else Vector2(34, 44)
	if shot.get("upgraded", false): dimensions *= 1.07
	if shot.charged: dimensions *= 1.36
	stage.draw_set_transform(shot.p + offset, shot.age * 5 + shot.phase if is_orb else shot.v.angle() + PI * 0.5)
	if is_orb:
		for side in [-1, 1]:
			stage.draw_arc(Vector2.ZERO, dimensions.x * 0.36, shot.age * side * 8, shot.age * side * 8 + PI * 0.8, 18, Color(0.28, 1, 0.87, 0.36 * intensity), 2.0, true)
	else:
		for strand in range(-1, 2):
			var x: float = strand * 4.0
			var tip: float = (-44 if shot.get("upgraded", false) else -38) + abs(strand) * 9
			stage.draw_colored_polygon(PackedVector2Array([Vector2(x, tip - 8), Vector2(x + 2.2, tip + 9), Vector2(x + 1.4, 21), Vector2(x, 32), Vector2(x - 1.4, 21), Vector2(x - 2.2, tip + 9)]), Color(0.05, 0.52, 0.21, 0.88))
			stage.draw_line(Vector2(x, 24), Vector2(x, tip), Color(0.3, 1, 0.45, intensity), 2.6, true)
			stage.draw_line(Vector2(x, 13), Vector2(x, tip + 3), Color(0.86, 1, 0.65, intensity), 1.1, true)
	if stage.art.has(actor_id) and (is_orb or shot.get("seal", false)):
		var a: Dictionary = stage.art[actor_id]
		var texture: Texture2D = a.texture
		var cell := Vector2(texture.get_width() / float(a.hframes), texture.get_height() / float(a.vframes))
		var frame := posmod(int(shot.age * a.fps + shot.phase * 2), a.frames)
		stage.draw_texture_rect_region(texture, Rect2(-dimensions * 0.5, dimensions), Rect2(Vector2(frame % a.hframes, int(frame / a.hframes)) * cell, cell), Color(1, 1, 1, intensity))
	stage.draw_set_transform(offset)

static func impact(stage, point: Vector2) -> void:
	stage.particles.append({"kind": "seal", "p": point, "v": Vector2.ZERO, "life": 0.34, "max_life": 0.34, "r": 56.0 if stage.stage_index >= 4 else 52.0, "c": Color("65ffed")})

static func draw_cast(stage) -> void:
	var t: float = stage.visual_time
	var center: Vector2 = stage._player_visual_position() + Vector2(0, -14)

	for side in [-1, 1]:
		var palm := center + Vector2(side * 28, -8 + sin(t * 9 + side) * 2)
		var radius := 10.0 + sin(t * 21 + side) * 1.5
		stage.draw_arc(palm, radius, t * side * 5, t * side * 5 + TAU * 0.8, 24, Color(0.35, 1, 0.68, 0.8), 1.8, true)
		stage.draw_arc(palm, radius * 1.4, -t * side * 6, -t * side * 6 + PI, 16, Color(0.1, 0.85, 1, 0.5), 1.2, true)
		stage.draw_circle(palm, 3.2, Color("ebffdf"))
	var wing := PackedVector2Array([center + Vector2(-31, -28), center + Vector2(-12, -21), center + Vector2(0, -35), center + Vector2(12, -21), center + Vector2(31, -28), center + Vector2(14, -14), center + Vector2(0, -20), center + Vector2(-14, -14)])
	stage.draw_colored_polygon(wing, Color(0.55, 1, 0.35, 0.38 + sin(t * 38) * 0.1))
