extends Node

signal command(action: String)

const BUTTONS := {
	"pad_fire": JOY_BUTTON_A, "pad_bomb": JOY_BUTTON_B,
	"pad_power": JOY_BUTTON_X, "pad_restart": JOY_BUTTON_Y,
	"pad_focus": JOY_BUTTON_LEFT_SHOULDER, "pad_pause": JOY_BUTTON_START,
	"pad_left": JOY_BUTTON_DPAD_LEFT,
	"pad_right": JOY_BUTTON_DPAD_RIGHT, "pad_up": JOY_BUTTON_DPAD_UP,
	"pad_down": JOY_BUTTON_DPAD_DOWN,
}
const AXES := {
	"pad_left": [JOY_AXIS_LEFT_X, -1.0], "pad_right": [JOY_AXIS_LEFT_X, 1.0],
	"pad_up": [JOY_AXIS_LEFT_Y, -1.0], "pad_down": [JOY_AXIS_LEFT_Y, 1.0],
	"pad_focus": [JOY_AXIS_TRIGGER_LEFT, 1.0], "pad_power": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}

const PROFILES := {
	"enemy": [0.22, 0.08, 0.08], "heavy_enemy": [0.38, 0.32, 0.16],
	"large_enemy": [0.60, 0.82, 0.30], "hit": [0.92, 1.0, 0.42],
	"bomb": [0.68, 0.90, 0.50],
}

var using_gamepad := false
var active_device := -1
var focused := true
var feedback := Vector2.ZERO
var pulses: Array[Dictionary] = []
var _stick_direction := 0
var _refresh := 0.0
var _sent := Vector2.ZERO

func _ready() -> void:
	for action in BUTTONS:
		if InputMap.has_action(action): continue
		InputMap.add_action(action, 0.22)
		var button := InputEventJoypadButton.new()
		button.device = -1
		button.button_index = BUTTONS[action]
		InputMap.action_add_event(action, button)
		if AXES.has(action):
			var axis := InputEventJoypadMotion.new()
			axis.device = -1
			axis.axis = AXES[action][0]
			axis.axis_value = AXES[action][1]
			InputMap.action_add_event(action, axis)
	Input.joy_connection_changed.connect(_connection_changed)
	var devices := Input.get_connected_joypads()
	if not devices.is_empty():
		active_device = devices[0]
		using_gamepad = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		using_gamepad = false
	elif event is InputEventMouseButton and event.pressed:
		using_gamepad = false
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion): return
	if not focused: return
	var meaningful: bool = event.pressed if event is InputEventJoypadButton else absf(event.axis_value) > 0.25
	if meaningful:
		if active_device != event.device:
			clear_feedback()
			active_device = event.device
		using_gamepad = true

	get_viewport().set_input_as_handled()
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_X:
			var direction := int(signf(event.axis_value)) if absf(event.axis_value) >= 0.55 else 0
			if absf(event.axis_value) < 0.25: _stick_direction = 0
			if direction != 0 and direction != _stick_direction:
				_stick_direction = direction
				command.emit("right" if direction > 0 else "left")
		return
	if not event.pressed: return
	for action in ["fire", "bomb", "restart", "pause", "left", "right"]:
		if event.is_action_pressed("pad_" + action):
			command.emit(action)
			return

func movement() -> Vector2:
	return Input.get_vector("pad_left", "pad_right", "pad_up", "pad_down", 0.22) if focused else Vector2.ZERO

func held(action: String) -> bool:
	return focused and Input.is_action_pressed("pad_" + action)

func _connection_changed(device: int, connected: bool) -> void:
	if connected and active_device < 0:
		active_device = device
		using_gamepad = true
	elif not connected and device == active_device:
		clear_feedback()
		_release_actions()
		active_device = -1
		using_gamepad = false
		command.emit("disconnected")
		var devices := Input.get_connected_joypads()
		if not devices.is_empty(): active_device = devices[0]

func _release_actions() -> void:
	for action in BUTTONS: Input.action_release(action)
	_stick_direction = 0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused = false
		clear_feedback()
		_release_actions()
		command.emit("focus_lost")
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		focused = true

func pulse(kind: String) -> void:
	if not focused or not PROFILES.has(kind): return
	var profile: Array = PROFILES[kind]
	_add_pulse(kind, Vector2(profile[0], profile[1]), profile[2])

func explosion(scale_value: float) -> void:
	if not focused: return
	_add_pulse("explosion", Vector2(clampf(0.10 + scale_value * 0.12, 0, 0.55), clampf(0.10 + scale_value * 0.23, 0, 0.78)), 0.11 + minf(scale_value, 2.5) * 0.045)

func _add_pulse(kind: String, strength: Vector2, duration: float) -> void:

	for item in pulses:
		if item.kind == kind:
			item.strength = Vector2(maxf(item.strength.x, strength.x), maxf(item.strength.y, strength.y))
			item.age = 0.0
			item.duration = maxf(item.duration, duration)
			return
	pulses.append({"kind": kind, "strength": strength, "duration": duration, "age": 0.0})

func advance_feedback(dt: float, allowed: bool, screen_shake: float) -> void:
	if not focused or not allowed:
		clear_feedback()
		return
	var amount := clampf(screen_shake / 16.0, 0, 1)
	feedback = Vector2(0.10, 0.22) * amount
	for index in range(pulses.size() - 1, -1, -1):
		var item: Dictionary = pulses[index]
		item.age += dt
		if item.age >= item.duration:
			pulses.remove_at(index)
			continue
		var envelope := pow(1.0 - item.age / item.duration, 0.65)
		if item.kind == "hit":

			envelope = 1.0 if item.age < 0.10 else (0.08 if item.age < 0.17 else 0.75 * (1.0 - (item.age - 0.17) / 0.25))
		var strength: Vector2 = item.strength * envelope
		feedback.x = maxf(feedback.x, strength.x)
		feedback.y = maxf(feedback.y, strength.y)
	_refresh -= dt
	if active_device < 0: return
	if feedback.is_zero_approx():
		if not _sent.is_zero_approx(): Input.stop_joy_vibration(active_device)
		_sent = Vector2.ZERO
	elif _refresh <= 0 or feedback.distance_to(_sent) > 0.08:
		Input.start_joy_vibration(active_device, feedback.x, feedback.y, 0.12)
		_sent = feedback
		_refresh = 0.05

func clear_feedback() -> void:
	pulses.clear()
	feedback = Vector2.ZERO
	if active_device >= 0 and not _sent.is_zero_approx(): Input.stop_joy_vibration(active_device)
	_sent = Vector2.ZERO
	_refresh = 0.0

func _exit_tree() -> void:
	clear_feedback()
