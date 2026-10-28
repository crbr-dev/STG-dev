extends Node2D

const DURATION := 0.72
const START_RADIUS := 4.0
const END_RADIUS := 86.0

var stage: Node2D
var active := false
var active_age := 0.0
var glow: Texture2D

func _ready() -> void:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; render_mode unshaded, blend_add; void fragment(){ if(SCREEN_UV.y < 0.09375 || SCREEN_UV.y > 0.9458 || (SCREEN_UV.x < 0.21875 && SCREEN_UV.y < 0.1875)) { COLOR.a = 0.0; } }"
	var effect_material := ShaderMaterial.new()
	effect_material.shader = shader
	material = effect_material
	var pixels := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var radius := Vector2(x - 31.5, y - 31.5).length() / 31.5
			var alpha := exp(-radius * radius * 6.5) * (1.0 - smoothstep(0.80, 1.0, radius))
			pixels.set_pixel(x, y, Color(1, 1, 1, alpha))
	glow = ImageTexture.create_from_image(pixels)
	visible = false

func _eligible() -> bool:
	return stage != null and stage.stage_index <= 3 and stage.game_state == "playing"

func trigger() -> void:
	if not _eligible():
		clear()
		return
	active = true
	active_age = 0.0
	visible = not stage.paused
	queue_redraw()

func advance(dt: float) -> void:
	if not active: return
	if not _eligible():
		clear()
		return
	if stage.paused: return
	active_age += maxf(0.0, dt)
	if active_age >= DURATION:
		clear()
	else:
		queue_redraw()

func clear() -> void:
	active = false
	active_age = 0.0
	visible = false
	queue_redraw()

func _process(_dt: float) -> void:
	if active and not _eligible():
		clear()
		return
	visible = active and _eligible() and not stage.paused
	if visible: queue_redraw()

func _draw() -> void:
	if not active or not _eligible() or glow == null: return
	var t := clampf(active_age / DURATION, 0, 1)
	var growth := 1.0 - pow(1.0 - t, 2.0)
	var radius := lerpf(START_RADIUS, END_RADIUS, growth)
	var opacity := smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.28, 1.0, t))
	var shake_offset: Vector2 = Vector2(sin(stage.visual_time * 97), cos(stage.visual_time * 113)) * stage.shake
	var center: Vector2 = stage._player_visual_position() + shake_offset
	draw_set_transform(center)

	for index in range(6):
		var angle := index * TAU / 6.0 + t * 0.65
		var point := Vector2.from_angle(angle) * radius * 0.40
		var size := maxf(12.0, radius * 1.22)
		var hue := Color.from_hsv(fposmod(index / 6.0 + t * 0.13, 1.0), 0.78, 1.0, opacity * 0.16)
		draw_texture_rect(glow, Rect2(point - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, hue)

	for segment in range(12):
		var angle := segment * TAU / 12.0 + t * 0.65
		var color := Color.from_hsv(fposmod(segment / 12.0 + t * 0.13, 1.0), 0.72, 1.0, opacity * 0.83)
		draw_arc(Vector2.ZERO, radius, angle, angle + TAU / 12.0 + 0.015, 7, color, lerpf(3.2, 1.2, t), true)
		color.a *= 0.28
		draw_arc(Vector2.ZERO, radius * 0.82, angle, angle + TAU / 12.0 + 0.015, 7, color, 5.0, true)
	for index in range(8):
		var angle := index * TAU / 8.0 - t * 0.30
		var point := Vector2.from_angle(angle) * (radius * 1.06)
		var reach := lerpf(4.2, 1.0, t)
		var color := Color.from_hsv(fposmod(index / 8.0 + 0.08, 1.0), 0.55, 1.0, opacity * 0.9)
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -reach * 1.6), point + Vector2(reach, 0), point + Vector2(0, reach * 1.6), point + Vector2(-reach, 0)]), color)
	draw_set_transform(Vector2.ZERO)
