extends RefCounted

static func _edge(rect: Rect2, cut: float = 3.0) -> PackedVector2Array:
	var a := rect.position
	var b := rect.end
	return PackedVector2Array([Vector2(a.x + cut, a.y), Vector2(b.x - cut, a.y), Vector2(b.x, a.y + cut), Vector2(b.x, b.y - cut), Vector2(b.x - cut, b.y), Vector2(a.x + cut, b.y), Vector2(a.x, b.y - cut), Vector2(a.x, a.y + cut), Vector2(a.x + cut, a.y)])

static func _alpha(color: Color, value: float) -> Color:
	return Color(color.r, color.g, color.b, value)

static func frame(canvas: CanvasItem, rect: Rect2, hue: Color, time: float, intensity: float = 1.0) -> void:
	var pulse := (0.86 + sin(time * 5.5) * 0.14) * intensity
	var edge := _edge(rect)
	canvas.draw_polyline(edge, _alpha(hue, 0.05 * pulse), 12.0, true)
	canvas.draw_polyline(edge, _alpha(hue, 0.13 * pulse), 6.0, true)
	canvas.draw_colored_polygon(edge.slice(0, 8), Color("081020"))
	canvas.draw_polyline(edge, _alpha(hue, 0.85 * pulse), 2.4, true)
	canvas.draw_polyline(_edge(rect.grow(-2.5), 2), _alpha(hue.lightened(0.6), 0.33 * pulse), 0.8, true)

	var perimeter := 2.0 * (rect.size.x + rect.size.y)
	for index in range(5):
		var distance := fposmod(time * 61.0 - index * 3.1, perimeter)
		var point := rect.position
		if distance < rect.size.x:
			point.x += distance
		elif distance < rect.size.x + rect.size.y:
			point += Vector2(rect.size.x, distance - rect.size.x)
		elif distance < 2 * rect.size.x + rect.size.y:
			point += Vector2(2 * rect.size.x + rect.size.y - distance, rect.size.y)
		else:
			point.y += perimeter - distance
		canvas.draw_circle(point, 1.7, _alpha(hue.lightened(0.75), (1.0 - index * 0.16) * pulse))

static func label(canvas: CanvasItem, font: Font, text: String, baseline: Vector2, size: int, hue: Color, strength: float = 1.0, centered: bool = true) -> void:
	var point := baseline
	if centered: point.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	canvas.draw_string_outline(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 9, _alpha(hue, 0.08 * strength))
	canvas.draw_string_outline(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, _alpha(hue, 0.35 * strength))
	canvas.draw_string_outline(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 1, _alpha(hue, strength))
	canvas.draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _alpha(hue.lightened(0.8), strength))

static func sign(canvas: CanvasItem, font: Font, rect: Rect2, glyph: String, hue: Color, time: float, font_size: int = 27) -> void:
	frame(canvas, rect, hue, time)
	var inner := rect.grow(-5)
	canvas.draw_rect(inner, _alpha(hue, 0.11 + sin(time * 4.1) * 0.035))
	for y in range(int(inner.position.y) + 1, int(inner.end.y), 3):
		canvas.draw_line(Vector2(inner.position.x, y), Vector2(inner.end.x, y), Color(0, 0.02, 0.05, 0.24), 1)
	var sweep_y := inner.position.y + fposmod(time * 25, inner.size.y)
	canvas.draw_line(Vector2(inner.position.x, sweep_y), Vector2(inner.end.x, sweep_y), _alpha(hue.lightened(0.7), 0.38), 1.6, true)
	var illumination := 0.86 + 0.14 * sin(time * 7.0)
	label(canvas, font, glyph, rect.get_center() + Vector2(0, font_size * 0.33), font_size, hue, illumination)

static func meter(canvas: CanvasItem, rect: Rect2, fraction: float, hue: Color, time: float) -> void:
	frame(canvas, rect, hue, time)
	var inner := rect.grow(-4)
	canvas.draw_rect(inner, Color("171026"))
	var filled := inner.size.x * clampf(fraction, 0, 1)
	for x in range(0, int(ceil(filled)), 5):
		var width := minf(4, filled - x)
		if width <= 0: continue
		var brightness := 0.73 + 0.27 * sin(time * 3.4 - x * 0.05)
		canvas.draw_rect(Rect2(inner.position + Vector2(x, 0), Vector2(width, inner.size.y)), hue * Color(brightness, brightness, brightness, 1))
	if filled > 1:
		canvas.draw_line(inner.position + Vector2(0, 1), inner.position + Vector2(filled, 1), _alpha(hue.lightened(0.9), 0.75), 1.3, true)
		var cursor := fposmod(time * 83, filled + 25) - 25
		for index in range(13):
			var x := cursor + index * 2
			if x >= 0 and x < filled:
				canvas.draw_line(inner.position + Vector2(x, 1), inner.position + Vector2(x, inner.size.y - 1), Color(0.8, 1, 0.96, (1.0 - abs(index - 6) / 7.0) * 0.38), 2)
		canvas.draw_line(inner.position + Vector2(filled - 1, 0), inner.position + Vector2(filled - 1, inner.size.y), _alpha(hue.lightened(0.85), 0.9), 1.5, true)
	for y in range(int(inner.position.y) + 2, int(inner.end.y), 4):
		canvas.draw_line(Vector2(inner.position.x, y), Vector2(inner.position.x + filled, y), Color(0.01, 0.02, 0.06, 0.12), 1)
