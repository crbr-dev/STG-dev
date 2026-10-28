extends Node2D

var stage: Node2D
var glow: Texture2D

func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in range(96):
		for x in range(96):
			var r := Vector2(x - 47.5, y - 47.5).length() / 47.5
			var alpha := (0.68 * exp(-r * r * 10.0) + 0.2 * exp(-r * r * 3.7)) * smoothstep(1.0, 0.75, r)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	glow = ImageTexture.create_from_image(image)

func _process(_dt: float) -> void:
	visible = stage != null and stage.game_state == "playing" and not stage.paused
	if visible: queue_redraw()

func _draw() -> void:
	if stage == null or glow == null: return
	var offset: Vector2 = Vector2(sin(stage.visual_time * 97), cos(stage.visual_time * 113)) * stage.shake
	for bullet in stage.bullets:
		if bullet.p.y < 92 or bullet.p.y > 875: continue
		var phase: float = bullet.age * 19.0 + bullet.get("phase", 0.0)
		var strength := 0.48 + 0.22 * sin(phase)
		var hue := Color(0.14, 0.46, 1, strength) if bullet.kind == 0 else Color(1, 0.08, 0.52, strength)
		if bullet.kind == 2: hue = Color(0.06, 1, 0.4, strength)
		var shape: String = bullet.get("shape", "drop")
		var dimensions := Vector2(42, 59) if shape == "drop" else (Vector2(32, 75) if shape == "needle" else Vector2(45, 45))
		dimensions *= float(bullet.get("visual_scale", 1.0))
		draw_set_transform(bullet.p + offset, bullet.v.angle() + PI * 0.5)
		draw_texture_rect(glow, Rect2(-dimensions * 0.5, dimensions), false, hue)
	for shot in stage.player_shots:
		if shot.p.y < 92 or shot.p.y > 875: continue
		draw_set_transform(shot.p + offset)
		if shot.get("kind", "bolt") == "magic":
			var hue := Color(1, 0.66, 0.08, 0.54) if shot.focused else Color(0.66, 0.07, 1, 0.58)
			draw_texture_rect(glow, Rect2(-42, -42, 84, 84), false, hue)
		elif shot.get("kind", "bolt") == "spirit_orb":
			var diameter := 108.0 if shot.get("charged", false) else 82.0
			draw_texture_rect(glow, Rect2(Vector2.ONE * -diameter * 0.5, Vector2.ONE * diameter), false, Color(0.05, 0.7, 0.9, 0.48))
		elif shot.get("kind", "bolt") == "spirit_lance":
			draw_set_transform(shot.p + offset, shot.v.angle() + PI * 0.5)
			draw_texture_rect(glow, Rect2(-17, -46, 34, 92), false, Color(0.1, 1, 0.32, 0.34))
		else:
			if stage.texture_cache.has("yusuke_shot"):
				var size_scale := 1.12 if shot.get("upgraded", false) else 1.0
				draw_set_transform(shot.p + offset, shot.v.angle() + PI * 0.5)
				draw_texture_rect(glow, Rect2(Vector2(-11, 1) * size_scale, Vector2(22, 40) * size_scale), false, Color(1, 0.58, 0.08, 0.17))
			else:
				draw_texture_rect(glow, Rect2(-15, -24, 30, 48), false, Color(1, 0.66, 0.12, 0.3))
	draw_set_transform(Vector2.ZERO)
	if stage.upgraded_attacks: stage.upgraded_attacks.draw_glow(self, glow)
	if stage.stage_index == 5 and stage.enemy_patterns: stage.enemy_patterns.draw_glow(self, glow)
