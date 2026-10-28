extends Node2D

signal finished

var video: VideoStreamPlayer
var running := false

func _ready() -> void:
	video = VideoStreamPlayer.new()
	video.position = Vector2(0, 160)
	video.size = Vector2(960, 640)
	video.expand = true
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video.volume_db = -80
	video.finished.connect(_complete)
	add_child(video)
	visible = false

func configure(specification: Dictionary) -> void:
	var path: String = specification.get("path", "")
	video.stream = load(path) if ResourceLoader.exists(path) else null

func begin() -> bool:
	if video.stream == null: return false
	running = true
	visible = true
	video.play()
	queue_redraw()
	return true

func _complete() -> void:
	video.stop()
	running = false
	visible = false
	finished.emit()

func _draw() -> void:
	if not running: return
	draw_rect(Rect2(0, 0, 960, 960), Color("02050c"))
