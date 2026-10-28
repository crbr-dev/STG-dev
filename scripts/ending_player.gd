extends Node2D

signal return_requested

const MOVIE_PATH := "res://assets/ending/ending.ogv"
const HOLD_PATH := "res://assets/ending/stars_hold.png"
const HOLD_SECONDS := 3.0
const IMAGE_RECT := Rect2(0, 160, 960, 640)

var running := false
var can_return := false
var hold_elapsed := 0.0
var video: VideoStreamPlayer
var return_button: Button
var hold_view: TextureRect
var _frozen := false
var _return_queued := false

func _ready() -> void:
	hold_view = TextureRect.new()
	hold_view.position = IMAGE_RECT.position
	hold_view.size = IMAGE_RECT.size
	hold_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hold_view.stretch_mode = TextureRect.STRETCH_SCALE
	hold_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hold_view.hide()
	add_child(hold_view)

	video = VideoStreamPlayer.new()
	video.position = IMAGE_RECT.position
	video.size = IMAGE_RECT.size
	video.expand = true
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video.volume_db = -80
	video.finished.connect(_on_video_finished)
	video.hide()
	add_child(video)

	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	return_button = Button.new()
	return_button.position = Vector2(290, 840)
	return_button.size = Vector2(380, 56)
	return_button.text = "返回主标题  /  ENTER"
	return_button.focus_mode = Control.FOCUS_NONE
	return_button.mouse_filter = Control.MOUSE_FILTER_STOP
	return_button.add_theme_font_override("font", font)
	return_button.add_theme_font_size_override("font_size", 22)
	return_button.add_theme_color_override("font_color", Color("c5edf2"))
	return_button.add_theme_color_override("font_hover_color", Color("efffff"))
	return_button.add_theme_color_override("font_pressed_color", Color("ffffff"))
	return_button.add_theme_stylebox_override("normal", _button_style(Color("07131e"), Color("4d8e9d"), 0.08))
	return_button.add_theme_stylebox_override("hover", _button_style(Color("102831"), Color("9de7e9"), 0.18))
	return_button.add_theme_stylebox_override("pressed", _button_style(Color("173c46"), Color("c6ffff"), 0.12))
	return_button.pressed.connect(_on_return_pressed)
	return_button.disabled = true
	return_button.hide()
	add_child(return_button)
	hide()

func _button_style(fill: Color, border: Color, glow_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.shadow_color = Color(0.25, 0.8, 0.9, glow_alpha)
	style.shadow_size = 7
	return style

func begin() -> bool:
	stop()
	if video == null or not ResourceLoader.exists(MOVIE_PATH) or not ResourceLoader.exists(HOLD_PATH):
		return false
	var movie = load(MOVIE_PATH)
	var still = load(HOLD_PATH)
	if not movie is VideoStream or not still is Texture2D:
		return false
	video.stream = movie
	hold_view.texture = still
	running = true
	show()
	video.show()
	video.play()
	queue_redraw()
	return true

func stop() -> void:
	running = false
	can_return = false
	hold_elapsed = 0.0
	_frozen = false
	_return_queued = false
	if video != null:
		video.stop()
		video.hide()
		video.stream = null
	if hold_view != null:
		hold_view.hide()
		hold_view.texture = null
	if return_button != null:
		return_button.disabled = true
		return_button.hide()
	hide()
	queue_redraw()

func _on_video_finished() -> void:
	if not running or _frozen: return
	_frozen = true
	hold_elapsed = 0.0

	hold_view.show()
	video.hide()
	video.stop()
	queue_redraw()

func _process(dt: float) -> void:
	advance_hold(dt)

func advance_hold(dt: float) -> void:
	if not running or not _frozen or can_return or _return_queued: return
	hold_elapsed = minf(HOLD_SECONDS, hold_elapsed + maxf(0, dt))
	if hold_elapsed >= HOLD_SECONDS:
		can_return = true
		return_button.disabled = false
		return_button.show()

func request_return() -> bool:
	if not running or not can_return or _return_queued: return false
	_return_queued = true
	can_return = false
	return_button.disabled = true
	return_requested.emit()
	return true

func _on_return_pressed() -> void:
	request_return()

func _draw() -> void:
	if running: draw_rect(Rect2(0, 0, 960, 960), Color("02050b"))
