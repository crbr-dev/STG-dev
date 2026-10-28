extends RefCounted

const NeonUI = preload("res://scripts/neon_ui.gd")
const COLORS := [Color("ffd575"), Color("c581ff"), Color("79ffca")]
const WEAPONS := ["PIERCING LIGHT ORB", "FOUR-TARGET LIGHTNING", "HOMING LIGHTBIRD"]
const TRAITS := ["0.75s  /  PIERCE + DOUBLE HIT", "1.0s  /  FOUR PURPLE STRIKES", "1.0s  /  CURVED INDIGO FLIGHT"]

static func card_rect(index: int) -> Rect2:
	return Rect2(48 + index * 296, 258, 272, 502)

static func confirm_rect() -> Rect2:
	return Rect2(292, 802, 376, 62)

static func draw(stage) -> void:
	var t: float = stage.visual_time
	stage.draw_rect(Rect2(0, 0, 960, 960), Color("040a14"))
	for index in range(15):
		var y := fposmod(index * 76.0 + t * 12, 1100) - 70
		stage.draw_line(Vector2(0, y + 110), Vector2(960, y - 110), Color(0.08, 0.22, 0.3, 0.18), 1, true)
	NeonUI.label(stage, stage.fonts, "SELECT ESPER", Vector2(480, 113), 58, Color("b8faff"))
	stage._text("STAGE %02d  /  %s" % [stage.stage_index, stage.stage_spec.name], Vector2(480, 164), 18, Color("82aaa9"), true)
	stage._text("CHOOSE WHO TAKES THE NEXT FIGHT", Vector2(480, 208), 17, Color("c6d2d5"), true)
	for index in range(3):
		var selected: bool = stage.character_index == index + 1
		var rect := card_rect(index)
		var hue: Color = COLORS[index]
		NeonUI.frame(stage, rect, hue, t + index, 1.0 if selected else 0.35)
		var portrait_rect := Rect2(rect.position + Vector2(12, 12), Vector2(248, 341))
		if index < stage.hero_portraits.size() and stage.hero_portraits[index] != null:
			stage.draw_texture_rect(stage.hero_portraits[index], portrait_rect, false, Color.WHITE if selected else Color(0.55, 0.58, 0.64, 1))
		for line in range(48):
			var alpha := line / 48.0 * 0.78
			stage.draw_rect(Rect2(portrait_rect.position + Vector2(0, 246 + line * 2), Vector2(248, 2)), Color(0.02, 0.04, 0.08, alpha))
		NeonUI.sign(stage, stage.fonts, Rect2(rect.position + Vector2(22, 22), Vector2(33, 30)), str(index + 1), hue, t, 19)
		var center := rect.get_center().x
		stage._text(stage.HERO_NAMES[index], Vector2(center, rect.position.y + 382), 21, Color.WHITE if selected else Color("8497a9"), true)
		NeonUI.label(stage, stage.fonts, WEAPONS[index], Vector2(center, rect.position.y + 414), 17, hue, 1 if selected else 0.4)
		stage._text(TRAITS[index], Vector2(center, rect.position.y + 444), 11, Color("b7c8d4"), true)
		if selected:
			stage._text("READY", Vector2(center, rect.position.y + 478), 17, hue, true)
			stage.draw_line(rect.position + Vector2(42, 489), rect.position + Vector2(230, 489), hue, 2, true)
	var hue: Color = COLORS[stage.character_index - 1]
	NeonUI.frame(stage, confirm_rect(), hue, t)
	NeonUI.label(stage, stage.fonts, "A   DEPLOY" if stage.gamepad.using_gamepad else "ENTER / Z   DEPLOY", Vector2(480, 842), 26, hue)
	stage._text("LEFT STICK / D-PAD   SELECT       B   BACK" if stage.gamepad.using_gamepad else "ARROWS / 1-3 / CLICK   SELECT       ESC   BACK", Vector2(480, 902), 15, Color("9cbbc9"), true)
